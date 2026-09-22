# frozen_string_literal: true

module RedmineCustomDashboard
  # Computes per-project KPI and assignee throughput for the dashboard.
  class DashboardStats
    PERIODS = {
      '7' => 7,
      '30' => 30,
      '90' => 90
    }.freeze

    DEFAULT_PERIOD = '30'
    DUE_SOON_DAYS = 7

    # English and Vietnamese default seeds. Other locales come from
    # I18n `default_issue_status_in_progress` when Redmine has that locale loaded.
    CANONICAL_IN_PROGRESS_NAMES = [
      'In Progress',
      'Đang thực hiện'
    ].freeze

    Result = Struct.new(
      :period_key, :period_days, :from_date, :to_date,
      :open, :resolved_in_period, :overdue, :in_progress, :due_soon,
      :delta_open, :delta_resolved, :delta_overdue, :delta_in_progress, :delta_due_soon,
      :assignee_stats, :issue_filters,
      keyword_init: true
    )

    def self.normalize_period(period)
      key = period.to_s.strip
      PERIODS.key?(key) ? key : DEFAULT_PERIOD
    end

    # Case-fold status labels in Ruby so matching does not depend on DB collation.
    def self.normalize_status_label(name)
      name.to_s.strip.downcase
    end

    def self.in_progress_labels(extra_labels = [])
      (CANONICAL_IN_PROGRESS_NAMES + Array(extra_labels)).filter_map do |label|
        normalized = normalize_status_label(label)
        normalized unless normalized.empty?
      end.uniq
    end

    def self.in_progress_label?(name, labels)
      normalized = normalize_status_label(name)
      !normalized.empty? && labels.include?(normalized)
    end

    def initialize(project, period: DEFAULT_PERIOD, today: Date.current)
      @project = project
      @period_key = self.class.normalize_period(period)
      @period_days = PERIODS[@period_key]
      @today = today
      @from_date = @today - @period_days.days
      @to_date = @today
    end

    def call
      current = raw_kpis
      # Date-based stock (overdue, due soon) is recomputed with today = period start.
      # Open and in-progress ignore @today, so those deltas stay 0 (no journal replay).
      baseline = self.class.new(@project, period: @period_key, today: @from_date).raw_kpis

      Result.new(
        period_key: @period_key,
        period_days: @period_days,
        from_date: @from_date,
        to_date: @to_date,
        open: current[:open],
        resolved_in_period: current[:resolved],
        overdue: current[:overdue],
        in_progress: current[:in_progress],
        due_soon: current[:due_soon],
        delta_open: current[:open] - baseline[:open],
        delta_resolved: current[:resolved] - previous_period_resolved,
        delta_overdue: current[:overdue] - baseline[:overdue],
        delta_in_progress: current[:in_progress] - baseline[:in_progress],
        delta_due_soon: current[:due_soon] - baseline[:due_soon],
        assignee_stats: build_assignee_stats,
        issue_filters: build_issue_filters
      )
    end

    # Public for tests and baseline snapshots (no deltas / assignee table).
    def raw_kpis
      {
        open: open_scope.count,
        resolved: resolved_in_period_scope.count,
        overdue: overdue_scope.count,
        in_progress: in_progress_scope.count,
        due_soon: due_soon_scope.count
      }
    end

    private

    def base_scope
      Issue.where(project_id: @project.id)
    end

    def open_scope
      base_scope.open
    end

    def closed_statuses
      @closed_statuses ||= IssueStatus.where(is_closed: true)
    end

    def in_progress_status_ids
      @in_progress_status_ids ||= begin
        labels = self.class.in_progress_labels(i18n_in_progress_labels)
        IssueStatus.where(is_closed: false).select do |status|
          self.class.in_progress_label?(status.name, labels)
        end.map(&:id)
      end
    end

    def i18n_in_progress_labels
      return [] unless defined?(I18n)

      I18n.available_locales.filter_map do |locale|
        label = I18n.t(:default_issue_status_in_progress, locale: locale, default: '')
        next unless label.is_a?(String)
        next if label.empty? || label == 'default_issue_status_in_progress'
        next if label.include?('translation missing')

        label
      end
    end

    def resolved_timestamp
      Arel::Nodes::NamedFunction.new(
        'COALESCE',
        [Issue.arel_table[:closed_on], Issue.arel_table[:updated_on]]
      )
    end

    def resolved_between_scope(from_date, to_date_exclusive)
      from_time = from_date.beginning_of_day
      to_time = to_date_exclusive.beginning_of_day
      stamp = resolved_timestamp
      base_scope
        .where(status_id: closed_statuses.select(:id))
        .where(stamp.gteq(from_time))
        .where(stamp.lt(to_time))
    end

    def resolved_in_period_scope
      stamp = resolved_timestamp
      base_scope
        .where(status_id: closed_statuses.select(:id))
        .where(stamp.gteq(@from_date.beginning_of_day))
    end

    def overdue_scope
      open_scope.where.not(due_date: nil).where(Issue.arel_table[:due_date].lt(@today))
    end

    def in_progress_scope
      if in_progress_status_ids.any?
        open_scope.where(status_id: in_progress_status_ids)
      else
        open_scope.none
      end
    end

    def due_soon_scope
      open_scope.where(due_date: @today..(@today + DUE_SOON_DAYS.days))
    end

    def previous_period_resolved
      prev_from = @from_date - @period_days.days
      resolved_between_scope(prev_from, @from_date).count
    end

    def build_assignee_stats
      user_ids = (
        open_scope.where.not(assigned_to_id: nil).distinct.pluck(:assigned_to_id) +
        resolved_in_period_scope.where.not(assigned_to_id: nil).distinct.pluck(:assigned_to_id)
      ).uniq

      assignees = User.where(id: user_ids).index_by(&:id)

      resolved_by = resolved_in_period_scope.where(assigned_to_id: user_ids).group(:assigned_to_id).count
      in_progress_by = in_progress_scope.where(assigned_to_id: user_ids).group(:assigned_to_id).count
      overdue_by = overdue_scope.where(assigned_to_id: user_ids).group(:assigned_to_id).count

      rows = user_ids.map do |uid|
        {
          user: assignees[uid],
          unassigned: false,
          resolved: resolved_by[uid].to_i,
          in_progress: in_progress_by[uid].to_i,
          overdue: overdue_by[uid].to_i
        }
      end

      unassigned = {
        user: nil,
        unassigned: true,
        resolved: resolved_in_period_scope.where(assigned_to_id: nil).count,
        in_progress: in_progress_scope.where(assigned_to_id: nil).count,
        overdue: overdue_scope.where(assigned_to_id: nil).count
      }
      if unassigned[:resolved].positive? || unassigned[:in_progress].positive? || unassigned[:overdue].positive?
        rows << unassigned
      end

      rows.sort_by { |row| [-row[:resolved], -row[:in_progress], -row[:overdue], row[:unassigned] ? 1 : 0] }
    end

    def build_issue_filters
      {
        open: {
          set_filter: 1,
          f: ['status_id'],
          op: { status_id: 'o' }
        },
        resolved: {
          set_filter: 1,
          f: ['status_id', 'closed_on'],
          op: { status_id: 'c', closed_on: '><' },
          v: { closed_on: [@from_date.to_s, @to_date.to_s] }
        },
        # Redmine query ops do not accept bare '<' for dates — use '<=' yesterday.
        overdue: {
          set_filter: 1,
          f: ['status_id', 'due_date'],
          op: { status_id: 'o', due_date: '<=' },
          v: { due_date: [(@today - 1.day).to_s] }
        },
        in_progress: in_progress_filter,
        due_soon: {
          set_filter: 1,
          f: ['status_id', 'due_date'],
          op: { status_id: 'o', due_date: '><' },
          v: { due_date: [@today.to_s, (@today + DUE_SOON_DAYS.days).to_s] }
        }
      }
    end

    def in_progress_filter
      if in_progress_status_ids.any?
        {
          set_filter: 1,
          f: ['status_id'],
          op: { status_id: '=' },
          v: { status_id: in_progress_status_ids.map(&:to_s) }
        }
      else
        {
          set_filter: 1,
          f: ['status_id'],
          op: { status_id: 'o' }
        }
      end
    end
  end
end

# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class DashboardStatsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :issues,
           :trackers, :projects_trackers, :issue_statuses, :enumerations,
           :enabled_modules

  def setup
    @project = Project.find(1)
    EnabledModule.create!(project: @project, name: 'custom_dashboard') unless @project.module_enabled?(:custom_dashboard)

    Issue.where(project_id: @project.id).delete_all

    @alice = User.find(2)
    @bob = User.find(3)
    open_statuses = IssueStatus.where(is_closed: false).order(:position).to_a
    @new = open_statuses.first
    @in_progress = open_statuses.second || open_statuses.first
    @in_progress.update_column(:name, 'In Progress') if @in_progress.name != 'In Progress'
    @closed = IssueStatus.where(is_closed: true).first
    @tracker = @project.trackers.first || Tracker.first
    @priority = IssuePriority.first
    @author = User.find(1)
    @today = Date.new(2026, 7, 18)
  end

  def create_issue!(attrs)
    closed_on = attrs.delete(:closed_on)
    updated_on = attrs.delete(:updated_on)
    issue = Issue.create!(
      {
        project: @project,
        tracker: @tracker,
        author: @author,
        priority: @priority,
        subject: "Dash #{SecureRandom.hex(4)}",
        status: @new
      }.merge(attrs)
    )
    if closed_on || updated_on
      Issue.where(id: issue.id).update_all(
        {
          closed_on: closed_on,
          updated_on: updated_on || closed_on
        }.compact
      )
    end
    issue.reload
  end

  def test_normalize_period_defaults_invalid
    assert_equal '30', RedmineCustomDashboard::DashboardStats.normalize_period('bad')
    assert_equal '7', RedmineCustomDashboard::DashboardStats.normalize_period('7')
  end

  def test_kpis_are_project_scoped
    other = Project.find(2)
    EnabledModule.create!(project: other, name: 'custom_dashboard') unless other.module_enabled?(:custom_dashboard)

    create_issue!(status: @new, assigned_to: @alice)
    Issue.create!(
      project: other,
      tracker: other.trackers.first || Tracker.first,
      author: @author,
      priority: @priority,
      subject: 'Other project open',
      status: @new,
      assigned_to: @alice
    )

    stats = RedmineCustomDashboard::DashboardStats.new(@project, period: '30', today: @today).call
    assert_equal 1, stats.open
  end

  def test_resolved_overdue_in_progress_due_soon_and_unassigned
    create_issue!(
      status: @closed,
      assigned_to: @alice,
      closed_on: (@today - 3.days).to_time,
      updated_on: (@today - 3.days).to_time
    )
    create_issue!(
      status: @closed,
      assigned_to: @alice,
      closed_on: (@today - 60.days).to_time,
      updated_on: (@today - 60.days).to_time
    )
    create_issue!(
      status: @in_progress,
      assigned_to: @bob,
      due_date: @today - 2.days
    )
    create_issue!(
      status: @new,
      assigned_to: nil,
      due_date: @today + 3.days
    )

    stats = RedmineCustomDashboard::DashboardStats.new(@project, period: '30', today: @today).call
    assert_equal 2, stats.open
    assert_equal 1, stats.resolved_in_period
    assert_equal 1, stats.overdue
    assert_equal 1, stats.in_progress
    assert_equal 1, stats.due_soon

    bob_row = stats.assignee_stats.find { |r| r[:user]&.id == @bob.id }
    assert bob_row
    assert_equal 1, bob_row[:in_progress]
    assert_equal 1, bob_row[:overdue]
  end

  def test_unassigned_row_when_overdue_without_assignee
    create_issue!(status: @new, assigned_to: nil, due_date: @today - 1.day)
    stats = RedmineCustomDashboard::DashboardStats.new(@project, period: '30', today: @today).call
    row = stats.assignee_stats.find { |r| r[:unassigned] }
    assert row
    assert_equal 1, row[:overdue]
  end

  def test_period_7_excludes_older_resolved
    create_issue!(
      status: @closed,
      assigned_to: @alice,
      closed_on: (@today - 20.days).to_time,
      updated_on: (@today - 20.days).to_time
    )
    create_issue!(
      status: @closed,
      assigned_to: @alice,
      closed_on: (@today - 2.days).to_time,
      updated_on: (@today - 2.days).to_time
    )

    stats30 = RedmineCustomDashboard::DashboardStats.new(@project, period: '30', today: @today).call
    stats7 = RedmineCustomDashboard::DashboardStats.new(@project, period: '7', today: @today).call
    assert_equal 2, stats30.resolved_in_period
    assert_equal 1, stats7.resolved_in_period
  end

  def test_delta_resolved_vs_previous_period
    create_issue!(
      status: @closed,
      assigned_to: @alice,
      closed_on: (@today - 3.days).to_time,
      updated_on: (@today - 3.days).to_time
    )
    create_issue!(
      status: @closed,
      assigned_to: @alice,
      closed_on: (@today - 40.days).to_time,
      updated_on: (@today - 40.days).to_time
    )
    create_issue!(
      status: @closed,
      assigned_to: @alice,
      closed_on: (@today - 45.days).to_time,
      updated_on: (@today - 45.days).to_time
    )

    stats = RedmineCustomDashboard::DashboardStats.new(@project, period: '30', today: @today).call
    assert_equal 1, stats.resolved_in_period
    # Previous equal-length window has the two older closures → delta -1
    assert_equal(-1, stats.delta_resolved)
  end

  def test_issue_filters_present
    stats = RedmineCustomDashboard::DashboardStats.new(@project, period: '30', today: @today).call
    assert stats.issue_filters[:open][:set_filter]
    assert_equal 'c', stats.issue_filters[:resolved][:op][:status_id]
    assert_equal '><', stats.issue_filters[:due_soon][:op][:due_date]
  end

  # Redmine rejects op[due_date]=< (404). Overdue must use <= yesterday.
  def test_overdue_filter_uses_supported_date_operator
    stats = RedmineCustomDashboard::DashboardStats.new(@project, period: '30', today: @today).call
    overdue = stats.issue_filters[:overdue]
    assert_equal '<=', overdue[:op][:due_date]
    assert_not_equal '<', overdue[:op][:due_date]
    assert_equal [(@today - 1).to_s], overdue[:v][:due_date]
    assert_equal 'o', overdue[:op][:status_id]
  end
end


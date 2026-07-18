# frozen_string_literal: true

module CustomDashboardsHelper
  def dashboard_issues_path(project, filter)
    project_issues_path(project, filter)
  end

  def dashboard_kpi_delta(delta)
    return if delta.nil? || delta.zero?

    css = delta.positive? ? 'custom-dashboard-delta-up' : 'custom-dashboard-delta-down'
    sign = delta.positive? ? '+' : ''
    content_tag(:span, "#{sign}#{delta}", class: "custom-dashboard-delta #{css}", title: l('redmine_custom_dashboard.delta_hint'))
  end

  def dashboard_assignee_cell(row)
    if row[:unassigned]
      content_tag(:em, l('redmine_custom_dashboard.unassigned'))
    else
      link_to_user(row[:user])
    end
  end

  def dashboard_date_range_label(stats)
    l(
      'redmine_custom_dashboard.date_range_span',
      from: format_date(stats.from_date),
      to: format_date(stats.to_date)
    )
  end
end

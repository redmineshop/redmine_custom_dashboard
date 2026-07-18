# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class CustomDashboardsControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :roles, :members, :member_roles, :issues,
           :trackers, :projects_trackers, :issue_statuses, :enumerations,
           :enabled_modules

  def setup
    @project = Project.find(1)
    EnabledModule.create!(project: @project, name: 'custom_dashboard') unless @project.module_enabled?(:custom_dashboard)

    Role.find(1).add_permission!(:view_custom_dashboard)
    Role.find(2).remove_permission!(:view_custom_dashboard) if Role.find(2).has_permission?(:view_custom_dashboard)
  end

  def test_index_success_for_member_with_permission
    @request.session[:user_id] = 2
    get :index, params: { project_id: @project.id }
    assert_response :success
    assert_select 'h2', /Project Dashboard|Bảng điều khiển/
    assert_select 'a.custom-dashboard-kpi-link', 5
    assert_select 'table.list.custom-dashboard-assignees, p.nodata'
    assert_select 'select.custom-dashboard-period-select'
    assert_select '.custom-dashboard-period-range'
  end

  def test_index_forbidden_without_permission
    member = Member.find_by(project_id: @project.id, user_id: 3)
    if member
      member.role_ids = [2]
      member.save!
    end
    @request.session[:user_id] = 3
    get :index, params: { project_id: @project.id }
    assert_response :forbidden
  end

  def test_index_respects_period_param
    @request.session[:user_id] = 2
    get :index, params: { project_id: @project.id, period: '7' }
    assert_response :success
    assert_select 'select#period option[selected][value=?]', '7'
  end

  def test_index_invalid_period_falls_back
    @request.session[:user_id] = 2
    get :index, params: { project_id: @project.id, period: '999' }
    assert_response :success
    assert_select 'select#period option[selected][value=?]', '30'
  end
end

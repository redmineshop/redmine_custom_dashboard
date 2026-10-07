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

  def test_index_period_90_and_stripped_period
    @request.session[:user_id] = 2
    get :index, params: { project_id: @project.id, period: '90' }
    assert_response :success
    assert_select 'select#period option[selected][value=?]', '90'

    get :index, params: { project_id: @project.id, period: ' 7 ' }
    assert_response :success
    assert_select 'select#period option[selected][value=?]', '7'
  end

  def test_index_requires_login
    @request.session[:user_id] = nil
    get :index, params: { project_id: @project.id }
    assert_response :redirect
  end

  def test_index_forbidden_when_module_disabled
    EnabledModule.where(project_id: @project.id, name: 'custom_dashboard').delete_all
    assert_not Project.find(@project.id).module_enabled?(:custom_dashboard)
    @request.session[:user_id] = 2
    get :index, params: { project_id: @project.id }
    assert_response :forbidden
    assert_select '.custom-dashboard-kpis', count: 0
  end

  def test_index_missing_project
    @request.session[:user_id] = 2
    get :index, params: { project_id: 'missing-dashboard-project' }
    assert_response :not_found
  end

  def test_index_forbidden_on_private_project_for_non_member
    private_project = Project.find(2)
    outsider = User.find(3)
    assert_not private_project.is_public?
    assert_nil Member.find_by(project_id: private_project.id, user_id: outsider.id)
    @request.session[:user_id] = outsider.id
    get :index, params: { project_id: private_project.id }
    assert_response :forbidden
    assert_select '.custom-dashboard-kpis', count: 0
  end

  def test_index_renders_scoped_kpis_and_drilldown_links
    prepare_known_issues
    @request.session[:user_id] = 2
    get :index, params: { project_id: @project.id, period: '30' }
    assert_response :success
    assert_select '.custom-dashboard-kpi-open', text: '4'
    assert_select '.custom-dashboard-kpi-resolved', text: '2'
    assert_select '.custom-dashboard-kpi-overdue', text: '1'
    assert_select '.custom-dashboard-kpi-progress', text: '1'
    assert_select '.custom-dashboard-kpi-due-soon', text: '1'
    assert_select 'form.custom-dashboard-period-form' do |forms|
      assert_includes ['', 'get'], forms.first['method'].to_s.downcase
    end

    open_query = query_for('View open issues')
    assert_equal ['status_id'], Array(open_query['f'])
    assert_equal 'o', open_query.dig('op', 'status_id')

    resolved_query = query_for('View issues closed in this period')
    assert_equal 'c', resolved_query.dig('op', 'status_id')
    assert_equal '><', resolved_query.dig('op', 'closed_on')
    assert_equal [(Date.current - 30).to_s, Date.current.to_s], Array(resolved_query.dig('v', 'closed_on'))

    overdue_query = query_for('View overdue open issues')
    assert_equal 'o', overdue_query.dig('op', 'status_id')
    assert_equal '<=', overdue_query.dig('op', 'due_date')
    assert_not_equal '<', overdue_query.dig('op', 'due_date')
    assert_equal [(Date.current - 1).to_s], Array(overdue_query.dig('v', 'due_date'))

    due_soon_query = query_for('View open issues due in the next 7 days')
    assert_equal '><', due_soon_query.dig('op', 'due_date')
    assert_equal [Date.current.to_s, (Date.current + 7).to_s], Array(due_soon_query.dig('v', 'due_date'))

    progress_query = query_for('View in-progress issues')
    assert_equal '=', progress_query.dig('op', 'status_id')
    assert_includes Array(progress_query.dig('v', 'status_id')), @in_progress.id.to_s

    css_select('a.custom-dashboard-kpi-link').each do |link|
      assert_includes link['href'], "/projects/#{@project.identifier}/issues"
      assert_not_includes link['href'], '/projects/onlinestore/'
      assert_not_includes link['href'], '/projects/subproject1/'
    end

    get :index, params: { project_id: @project.id, period: '7' }
    assert_response :success
    assert_select '.custom-dashboard-kpi-resolved', text: '1'
    assert_select '.custom-dashboard-kpi-open', text: '4'
    week_query = query_for('View issues closed in this period')
    assert_equal [(Date.current - 7).to_s, Date.current.to_s], Array(week_query.dig('v', 'closed_on'))
  end

  def test_private_project_dashboard_omits_other_projects
    private_project = Project.find(2)
    Role.find(2).add_permission!(:view_custom_dashboard)
    enable_dashboard!(private_project)
    Issue.where(project_id: [@project.id, private_project.id]).delete_all
    create_issue_on!(@project, subject: 'Public project only')
    create_issue_on!(@project, subject: 'Public project only 2')
    create_issue_on!(private_project, subject: 'Private project only')

    @request.session[:user_id] = 2
    get :index, params: { project_id: private_project.id, period: '30' }
    assert_response :success
    assert_select '.custom-dashboard-kpi-open', text: '1'
    css_select('a.custom-dashboard-kpi-link').each do |link|
      assert_includes link['href'], "/projects/#{private_project.identifier}/issues"
      assert_not_includes link['href'], "/projects/#{@project.identifier}/"
    end
  end

  def test_rendered_counts_hide_private_issues_from_developer
    Role.find(2).add_permission!(:view_custom_dashboard)
    Issue.where(project_id: @project.id).delete_all
    create_issue_on!(@project, subject: 'Visible open', assigned_to_id: 2)
    hidden = create_issue_on!(@project, subject: 'Secret open', assigned_to_id: 2, author_id: 1)
    Issue.where(id: hidden.id).update_all(is_private: true)
    hidden.reload
    assert hidden.is_private?
    assert_not hidden.visible?(User.find(3))

    @request.session[:user_id] = 3
    get :index, params: { project_id: @project.id, period: '30' }
    assert_response :success
    assert_select '.custom-dashboard-kpi-open', text: '1'
    assert_no_match(/Secret open/, response.body)
  end

  def test_assignee_name_is_escaped
    payload = '<img src=x onerror=alert(1)>'
    User.find(2).update_columns(firstname: payload, lastname: 'Safe')
    Issue.where(project_id: @project.id).delete_all
    create_issue_on!(@project, subject: 'Assigned xss', assigned_to_id: 2)

    @request.session[:user_id] = 2
    get :index, params: { project_id: @project.id }
    assert_response :success
    assert_no_match(/<img src=x onerror=alert\(1\)>/, response.body)
    assert_match(/&lt;img src=x onerror=alert\(1\)&gt;/, response.body)
  end

  def test_invalid_period_is_not_reflected
    @request.session[:user_id] = 2
    get :index, params: { project_id: @project.id, period: '<script>dashperiod</script>' }
    assert_response :success
    assert_no_match(/<script>dashperiod<\/script>/, response.body)
    assert_select 'select#period option[selected][value=?]', '30'
  end

  def test_index_does_not_assign_or_write_records
    @request.session[:user_id] = 2
    assert_no_difference %w[Issue.count Project.count User.count Member.count] do
      get :index, params: {
        project_id: @project.id,
        period: "7'; DROP TABLE issues;--",
        user: { admin: '1', login: 'attacker' },
        project: { name: 'hacked', is_public: '0' },
        issue: { subject: 'injected', project_id: 2 }
      }
    end
    assert_response :success
    assert_not User.find(3).admin?
    assert_equal 'eCookbook', Project.find(1).name
    assert_equal 0, Issue.where(subject: 'injected').count
    assert_select 'select#period option[selected][value=?]', '30'
  end

  def test_only_get_index_is_routed
    path = "/projects/#{@project.identifier}/custom_dashboards"
    assert_routing(
      { path: path, method: :get },
      { controller: 'custom_dashboards', action: 'index', project_id: @project.identifier }
    )
    %i[post put patch delete].each do |verb|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(path, method: verb)
      end
    end
  end

  private

  def enable_dashboard!(project)
    return if project.module_enabled?(:custom_dashboard)

    EnabledModule.create!(project: project, name: 'custom_dashboard')
  end

  def prepare_known_issues
    @new = IssueStatus.where(is_closed: false).order(:position).first
    @in_progress = IssueStatus.where(is_closed: false).order(:position).second
    @in_progress.update_column(:name, 'In Progress')
    @closed = IssueStatus.where(is_closed: true).order(:position).first
    today = Date.current
    Issue.where(project_id: [@project.id, 2, 3]).delete_all

    create_issue_on!(@project, subject: 'Open plain', assigned_to_id: 2, status: @new)
    create_issue_on!(
      @project,
      subject: 'Open overdue progress',
      assigned_to_id: 3,
      status: @in_progress,
      due_date: today - 1.day
    )
    create_issue_on!(
      @project,
      subject: 'Open due soon',
      assigned_to_id: nil,
      status: @new,
      due_date: today + 3.days
    )
    create_closed!(@project, days_ago: 2, assigned_to_id: 2)
    create_closed!(@project, days_ago: 20, assigned_to_id: 2)
    create_closed!(@project, days_ago: 40, assigned_to_id: 2)
    secret = create_issue_on!(@project, subject: 'Manager private', assigned_to_id: 2, status: @new, author_id: 1)
    Issue.where(id: secret.id).update_all(is_private: true)
    create_issue_on!(Project.find(2), subject: 'Other project open')
    create_issue_on!(Project.find(3), subject: 'Subproject open')
  end

  def create_closed!(project, days_ago:, assigned_to_id:)
    closed_on = (Date.current - days_ago).in_time_zone.change(hour: 12)
    issue = create_issue_on!(
      project,
      subject: "Closed #{days_ago}",
      assigned_to_id: assigned_to_id,
      status: @closed
    )
    Issue.where(id: issue.id).update_all(closed_on: closed_on, updated_on: closed_on)
    issue
  end

  def create_issue_on!(project, attrs = {})
    previous = User.current
    User.current = User.find(1)
    Issue.create!(
      {
        project: project,
        tracker: project.trackers.first,
        author: User.find(1),
        priority: IssuePriority.first || IssuePriority.default,
        subject: "Dash #{SecureRandom.hex(4)}",
        status: IssueStatus.where(is_closed: false).order(:position).first
      }.merge(attrs)
    )
  ensure
    User.current = previous
  end

  def query_for(title)
    link = css_select(%(a.custom-dashboard-kpi-link[title="#{title}"])).first
    assert link, "missing KPI link #{title}"
    assert_includes link['href'], "/projects/"
    Rack::Utils.parse_nested_query(URI.parse(link['href']).query.to_s)
  end
end

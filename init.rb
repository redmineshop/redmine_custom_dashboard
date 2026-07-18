# frozen_string_literal: true

require File.expand_path('../lib/redmine_custom_dashboard/version', __FILE__)
require File.expand_path('../lib/redmine_custom_dashboard/dashboard_stats', __FILE__)

Redmine::Plugin.register :redmine_custom_dashboard do
  name        'Redmine Custom Dashboard'
  author      'RedmineShop'
  author_url  'https://redmineshop.com'
  description 'Employee performance dashboard with KPI tracking, completion rates, and date-range filtering.'
  version     RedmineCustomDashboard::VERSION
  url         'https://redmineshop.com/products/redmine-custom-dashboard'

  requires_redmine version_or_higher: '5.0'

  menu :project_menu,
       :custom_dashboard,
       { controller: 'custom_dashboards', action: 'index' },
       caption: :label_custom_dashboard,
       after: :overview,
       param: :project_id,
       if: proc { |project| User.current.allowed_to?(:view_custom_dashboard, project) }

  project_module :custom_dashboard do
    permission :view_custom_dashboard, { custom_dashboards: :index }, read: true
  end
end

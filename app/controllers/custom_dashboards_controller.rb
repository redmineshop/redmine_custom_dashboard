# frozen_string_literal: true

class CustomDashboardsController < ApplicationController
  menu_item :custom_dashboard

  before_action :find_project_by_project_id, :authorize
  helper :custom_dashboards

  def index
    @stats = RedmineCustomDashboard::DashboardStats.new(
      @project,
      period: params[:period]
    ).call
  end
end

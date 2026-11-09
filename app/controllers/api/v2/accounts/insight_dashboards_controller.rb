class Api::V2::Accounts::InsightDashboardsController < Api::V1::Accounts::BaseController
  include InsightsFeatureCheck

  FIELDS = %i[id name audience custom_role_id widgets filters refresh_seconds user_id updated_at].freeze
  WIDGET_PARAMS = [:id, :title, :display, :metric, :saved_report_id, { config: Insights::ReportConfig::PERMITTED_PARAMS }].freeze
  FILTER_PARAMS = [:period, Insights::ReportConfig::FILTERS.index_with { [] }].freeze

  before_action :fetch_dashboard, except: [:index, :create]
  before_action :ensure_can_change, only: [:update, :destroy]

  def index
    render json: dashboards.includes(:user).order(:name).map { |dashboard| serialize(dashboard) }
  end

  def show
    render json: serialize(@dashboard)
  end

  def create
    save_dashboard(Current.account.insight_dashboards.new(user: Current.user))
  end

  def update
    save_dashboard(@dashboard)
  end

  def destroy
    @dashboard.destroy!
    head :ok
  end

  private

  # People who can view all reports see every dashboard, so they can look after shared ones
  def dashboards
    scope = Current.account.insight_dashboards
    manager? ? scope : scope.visible_to(Current.account_user)
  end

  def fetch_dashboard
    @dashboard = dashboards.find(params[:id])
  end

  def ensure_can_change
    render_unauthorized(I18n.t('errors.insights.not_your_dashboard')) unless @dashboard.user_id == Current.user.id || manager?
  end

  def save_dashboard(dashboard)
    dashboard.assign_attributes(dashboard_params)
    return render_unauthorized(I18n.t('errors.insights.share_dashboard')) if sharing?(dashboard) && !manager?

    dashboard.save!
    render json: serialize(dashboard)
  end

  # Sharing needs report_manage; changing the widgets of a dashboard already shared doesn't
  def sharing?(dashboard)
    !dashboard.for_private? && (dashboard.new_record? || dashboard.audience_changed? || dashboard.custom_role_id_changed?)
  end

  # Widgets keep each report's settings with named periods, like saved reports; empty dashboard filters are dropped
  def dashboard_params
    attributes = params.require(:insight_dashboard).permit(:name, :audience, :custom_role_id, :refresh_seconds,
                                                           filters: FILTER_PARAMS, widgets: WIDGET_PARAMS).to_h
    attributes['filters'] = attributes['filters'].compact_blank if attributes.key?('filters')
    if attributes.key?('widgets')
      attributes['widgets'] = attributes['widgets'].map do |widget|
        widget.merge('config' => Insights::ReportConfig.new(widget['config'] || {}).definition.deep_stringify_keys)
      end
    end
    attributes
  end

  def serialize(dashboard)
    dashboard.as_json(only: FIELDS).merge(owner_name: dashboard.user.name)
  end

  def manager?
    Current.account_user.can?('report_manage')
  end
end

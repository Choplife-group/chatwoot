class Api::V2::Accounts::SavedReportsController < Api::V1::Accounts::BaseController
  include InsightsFeatureCheck

  FIELDS = %i[id name config shared user_id created_at updated_at].freeze

  before_action :fetch_saved_report, except: [:index, :create]

  def index
    reports = Current.account.saved_reports.visible_to(Current.user).includes(:user).order(updated_at: :desc)
    render json: reports.map { |report| serialize(report) }
  end

  def show
    authorize @saved_report
    render json: serialize(@saved_report)
  end

  def create
    @saved_report = Current.account.saved_reports.new(user: Current.user)
    save_report
  end

  def update
    authorize @saved_report
    save_report
  end

  def destroy
    authorize @saved_report
    @saved_report.destroy!
    head :ok
  end

  private

  def fetch_saved_report
    @saved_report = Current.account.saved_reports.find(params[:id])
  end

  def save_report
    attributes = params.require(:saved_report).permit(:name, :shared, config: Insights::ReportConfig::PERMITTED_PARAMS)
    attributes[:config] = Insights::ReportConfig.new(attributes[:config]).definition if attributes.key?(:config)
    if ActiveModel::Type::Boolean.new.cast(attributes[:shared]) && !policy(SavedReport).share?
      return render_unauthorized(I18n.t('errors.insights.cannot_share'))
    end

    @saved_report.update!(attributes)
    render json: serialize(@saved_report)
  end

  def serialize(report)
    report.as_json(only: FIELDS).merge(owner_name: report.user.name)
  end
end

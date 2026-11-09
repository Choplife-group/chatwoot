class Api::V2::Accounts::ReportSnapshotsController < Api::V1::Accounts::BaseController
  include InsightsFeatureCheck

  LIST_FIELDS = %i[id name saved_report_id captured_at].freeze

  def index
    snapshots = own_snapshots.select(*LIST_FIELDS).order(captured_at: :desc)
    render json: snapshots.as_json(only: LIST_FIELDS)
  end

  def show
    render json: own_snapshots.find(params[:id]).as_json(only: [*LIST_FIELDS, :config, :result])
  end

  # Works the report out now, as the person taking the snapshot, and keeps the figures
  def create
    attributes = params.require(:report_snapshot).permit(:name, :saved_report_id, config: Insights::ReportConfig::PERMITTED_PARAMS)
    config = Insights::ReportConfig.new(attributes[:config])
    return render_could_not_create_error(config.errors.full_messages.to_sentence) unless config.valid?

    snapshot = own_snapshots.create!(
      name: attributes[:name], saved_report: saved_report(attributes[:saved_report_id]), config: config.to_h, captured_at: Time.current,
      result: Insights::QueryService.new(account: Current.account, user: Current.user, config: config).perform
    )
    render json: snapshot.as_json(only: [*LIST_FIELDS, :config, :result])
  end

  # The stored dates, not the named period: "last 7 days" in a snapshot means the 7 days before it was taken
  def export
    file_type = params[:file_type]
    return render_could_not_create_error(I18n.t('errors.insights.invalid_file_type')) unless Insights::ExportService::FORMATS.include?(file_type)

    snapshot = own_snapshots.find(params[:id])
    config = Insights::ReportConfig.new(snapshot.config.merge('period' => 'custom', 'compare' => ('custom' if snapshot.config['compare'])))
    export = Insights::ExportService.new(title: snapshot.name, config: config, result: snapshot.result)
    send_data export.render(file_type), filename: export.filename(file_type), type: Insights::ExportService::CONTENT_TYPES[file_type]
  end

  def destroy
    own_snapshots.find(params[:id]).destroy!
    head :ok
  end

  private

  def own_snapshots
    Current.account.report_snapshots.where(user: Current.user)
  end

  def saved_report(id)
    Current.account.saved_reports.visible_to(Current.user).find(id) if id.present?
  end
end

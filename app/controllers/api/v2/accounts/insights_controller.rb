class Api::V2::Accounts::InsightsController < Api::V1::Accounts::BaseController
  DATE_PATTERN = /\A\d{4}-\d{2}-\d{2}\z/

  include InsightsFeatureCheck

  before_action :build_config

  def query
    render json: Insights::QueryService.new(account: Current.account, user: Current.user, config: @config).perform
  end

  # A file of the report: file_type is csv, xlsx or pdf; title names the file and heads the sheet
  def export
    file_type = params[:file_type]
    return render_could_not_create_error(I18n.t('errors.insights.invalid_file_type')) unless Insights::ExportService::FORMATS.include?(file_type)

    result = Insights::QueryService.new(account: Current.account, user: Current.user, config: @config).perform
    export = Insights::ExportService.new(title: params[:title].presence&.first(255) || I18n.t('insights.title'), config: @config, result: result)
    send_data export.render(file_type), filename: export.filename(file_type), type: Insights::ExportService::CONTENT_TYPES[file_type]
  end

  def drilldown
    return render_could_not_create_error(I18n.t('errors.insights.invalid_drilldown')) unless valid_drilldown?

    render json: Insights::DrilldownService.new(
      account: Current.account, user: Current.user, config: @config, page: params[:page],
      figure: { metric: params[:metric], dimensions: drilldown_dimensions, previous: previous_period? }
    ).perform
  end

  private

  def build_config
    @config = Insights::ReportConfig.new(params.permit(*Insights::ReportConfig::PERMITTED_PARAMS))
    render_could_not_create_error(@config.errors.full_messages.to_sentence) unless @config.valid?
  end

  # One row of the report: a value, or empty for "none", for some of the dimensions the report groups by
  def drilldown_dimensions
    @drilldown_dimensions ||= params.fetch(:dimensions, {}).permit(*@config.group_by).to_h.transform_values(&:presence)
  end

  def valid_drilldown?
    return false unless Insights::ReportConfig::METRICS.include?(params[:metric])
    return false if previous_period? && !@config.compare?
    return false if (params.fetch(:dimensions, {}).keys - @config.group_by).any?

    valid_dimension_values?
  end

  def valid_dimension_values?
    drilldown_dimensions.all? do |dimension, value|
      value.nil? || value.match?(Insights::ReportConfig::TIME_DIMENSIONS.include?(dimension) ? DATE_PATTERN : /\A\d+\z/)
    end
  end

  # The figure is from the comparison period. Not called "period", which already names the report's period.
  def previous_period?
    ActiveModel::Type::Boolean.new.cast(params[:from_comparison])
  end
end

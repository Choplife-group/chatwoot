module InsightsFeatureCheck
  extend ActiveSupport::Concern

  included do
    before_action :ensure_insights_enabled
  end

  private

  def ensure_insights_enabled
    return if Current.account.feature_enabled?('insights')

    render json: { error: I18n.t('errors.insights.feature_not_enabled') }, status: :forbidden
  end
end

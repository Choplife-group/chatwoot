module ConversationResolveGuardConcern
  extend ActiveSupport::Concern

  included do
    before_action :ensure_category_before_resolve, only: :toggle_status # rubocop:disable Rails/LexicallyScopedActionFilter
  end

  private

  def ensure_category_before_resolve
    return unless resolving? && Conversations::ResolveGuard.blocked?(conversation, Current.user)

    render_could_not_create_error(I18n.t('errors.conversations.category_required'))
  end

  # Mirrors Conversation#toggle_status: without an explicit status, an open conversation gets resolved
  def resolving?
    params[:status].present? ? params[:status] == 'resolved' : conversation.open?
  end
end

# A conversation's reason for contact. Agents pick a leaf of the account's category tree;
# a person can't resolve a conversation until one is set (see Conversations::ResolveGuard).
module CategoryHandler
  extend ActiveSupport::Concern

  included do
    belongs_to :category, class_name: 'ConversationCategory', optional: true

    validate :category_selectable, if: -> { category_id_changed? && category }
    after_update_commit :create_category_change_activity, if: :saved_change_to_category_id?
  end

  def categorised?
    category_id.present?
  end

  private

  def category_selectable
    return if category.account_id == account_id && !category.archived? && category.leaf?

    errors.add(:category, I18n.t('errors.conversations.invalid_category'))
  end

  def create_category_change_activity
    user_name = activity_message_owner(Current.user&.name)
    return if user_name.blank?

    content = if category_id.nil?
                I18n.t('conversations.activity.category.removed', user_name: user_name)
              else
                I18n.t('conversations.activity.category.set', user_name: user_name, category_path: category.path)
              end

    ::Conversations::ActivityMessageJob.perform_later(self, activity_message_params(content))
  end
end

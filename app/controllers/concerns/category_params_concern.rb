module CategoryParamsConcern
  private

  # Adds category_id to the permitted params when the request sends it. Only active categories of the account can be set;
  # Conversation validates that it is the last level of its branch.
  def with_category_id(permitted)
    return permitted unless params.key?(:category_id)

    category_id = params[:category_id]
    permitted.merge(category_id: category_id.present? ? Current.account.conversation_categories.active.find(category_id).id : nil)
  end
end

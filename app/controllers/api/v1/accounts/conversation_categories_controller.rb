class Api::V1::Accounts::ConversationCategoriesController < Api::V1::Accounts::BaseController
  before_action :fetch_category, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @categories = categories.ordered
  end

  def show; end

  def create
    @category = categories.create!(params.require(:conversation_category).permit(:name, :parent_id, :position))
  end

  def update
    @category.update!(params.require(:conversation_category).permit(:name, :position))
    archive_subtree(ActiveModel::Type::Boolean.new.cast(params[:conversation_category][:archived])) if params[:conversation_category].key?(:archived)
  end

  # Categories are archived, not deleted, so conversations and reports keep their category
  def destroy
    archive_subtree(true)
    head :ok
  end

  # Sets the order of sibling categories: ids are given in their new order
  def reorder
    ids = params.require(:ids)
    siblings = categories.where(id: ids)
    return render_could_not_create_error('Categories must share a parent') if siblings.pluck(:parent_id).uniq.size > 1

    ConversationCategory.transaction do
      ids.each_with_index { |id, position| siblings.find(id).update!(position: position) }
    end
    head :ok
  end

  private

  def categories
    Current.account.conversation_categories
  end

  def fetch_category
    @category = categories.find(params[:id])
  end

  # Archiving or restoring a category applies to everything below it
  def archive_subtree(archived)
    return render_could_not_create_error('Restore the parent category first') if !archived && @category.parent&.archived?

    subtree = categories.where(id: ConversationCategory.subtree_ids(Current.account, @category.id))
    subtree.update_all(archived_at: archived ? Time.current : nil) # rubocop:disable Rails/SkipsModelValidations
    @category.reload
  end
end

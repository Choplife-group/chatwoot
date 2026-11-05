class AddConversationCategoryIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :conversations, [:account_id, :category_id], algorithm: :concurrently, if_not_exists: true
  end
end

class CreateConversationCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_categories do |t|
      t.references :account, null: false, index: false
      t.bigint :parent_id
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.integer :depth, null: false, default: 1
      t.integer :ancestor_ids, array: true, null: false, default: []
      t.datetime :archived_at
      t.timestamps
    end
    add_index :conversation_categories, [:account_id, :parent_id, :name], unique: true
    add_index :conversation_categories, :ancestor_ids, using: :gin

    add_column :conversations, :category_id, :bigint
    # Snapshot at resolution time, so later recategorisation doesn't change historical reports
    add_column :reporting_events, :market_id, :bigint
    add_column :reporting_events, :category_id, :bigint
  end
end

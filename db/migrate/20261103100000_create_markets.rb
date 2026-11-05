class CreateMarkets < ActiveRecord::Migration[7.2]
  def change
    create_table :markets do |t|
      t.references :account, null: false, index: false
      t.string :name, null: false
      t.string :code, null: false
      t.integer :position, null: false, default: 0
      t.datetime :archived_at
      t.timestamps
    end
    add_index :markets, [:account_id, :code], unique: true
    add_index :markets, [:account_id, :name], unique: true

    add_column :inboxes, :market_id, :bigint
    add_column :contacts, :market_id, :bigint
    add_column :conversations, :market_id, :bigint
  end
end

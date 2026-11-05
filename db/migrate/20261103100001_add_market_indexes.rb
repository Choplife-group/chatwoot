class AddMarketIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :inboxes, :market_id, algorithm: :concurrently, if_not_exists: true
    add_index :contacts, [:account_id, :market_id], algorithm: :concurrently, if_not_exists: true
    add_index :conversations, [:account_id, :market_id], algorithm: :concurrently, if_not_exists: true
  end
end

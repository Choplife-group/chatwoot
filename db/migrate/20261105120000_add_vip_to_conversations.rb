class AddVipToConversations < ActiveRecord::Migration[7.2]
  def change
    add_column :conversations, :vip, :boolean, default: false, null: false
  end
end

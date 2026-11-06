class AddUniqueIndexToCustomRoles < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :custom_roles, [:account_id, :name], unique: true, algorithm: :concurrently, if_not_exists: true
  end
end

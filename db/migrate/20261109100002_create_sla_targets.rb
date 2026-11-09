class CreateSlaTargets < ActiveRecord::Migration[7.2]
  def change
    create_table :sla_targets do |t|
      t.references :account, null: false, index: true
      t.bigint :market_id
      t.integer :priority
      t.integer :first_response_seconds
      t.integer :resolution_seconds
      t.boolean :business_hours, null: false, default: false
      t.timestamps
    end
    # One target per market and priority, where an empty market or priority counts as a value of its own
    add_index :sla_targets, 'account_id, COALESCE(market_id, 0), COALESCE(priority, -1)', unique: true,
                                                                                          name: 'index_sla_targets_on_account_market_priority'
  end
end

class CreateInsightDashboards < ActiveRecord::Migration[7.2]
  def change
    create_table :insight_dashboards do |t|
      t.references :account, null: false, index: true
      t.references :user, null: false, index: true
      t.string :name, null: false
      t.integer :audience, null: false, default: 0
      t.bigint :custom_role_id
      t.jsonb :widgets, null: false, default: []
      t.jsonb :filters, null: false, default: {}
      t.integer :refresh_seconds, null: false, default: 60
      t.timestamps
    end
    add_index :insight_dashboards, :custom_role_id
  end
end

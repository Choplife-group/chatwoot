class CreateReportSchedules < ActiveRecord::Migration[7.2]
  def change
    create_table :report_schedules do |t|
      t.references :account, null: false, index: true
      t.references :saved_report, null: false, index: true
      t.references :user, null: false, index: true
      t.integer :frequency, null: false, default: 0
      t.integer :hour, null: false, default: 8
      t.integer :weekday
      t.integer :day_of_month
      t.string :timezone, null: false, default: 'UTC'
      t.bigint :recipient_ids, array: true, null: false, default: []
      t.string :file_types, array: true, null: false, default: []
      t.boolean :active, null: false, default: true
      t.datetime :next_run_at
      t.datetime :last_sent_at
      t.timestamps
    end
    add_index :report_schedules, [:active, :next_run_at]
  end
end

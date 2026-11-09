class CreateSavedReportsAndReportSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :saved_reports do |t|
      t.references :account, null: false, index: true
      t.references :user, null: false, index: true
      t.string :name, null: false
      t.jsonb :config, null: false, default: {}
      t.boolean :shared, null: false, default: false
      t.timestamps
    end

    create_table :report_snapshots do |t|
      t.references :account, null: false, index: true
      t.references :user, null: false, index: true
      t.references :saved_report, index: true
      t.string :name, null: false
      t.jsonb :config, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.datetime :captured_at, null: false
      t.timestamps
    end
  end
end

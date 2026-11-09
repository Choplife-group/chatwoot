class AddInsightsIndexesToReportingEvents < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  # Insights reports filter by event name and the time the event happened
  def change
    add_index :reporting_events, [:account_id, :name, :event_end_time], algorithm: :concurrently, if_not_exists: true,
                                                                        name: 'index_reporting_events_on_account_name_event_end_time'
  end
end

class AddTeamIdToReportingEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :reporting_events, :team_id, :bigint
  end
end

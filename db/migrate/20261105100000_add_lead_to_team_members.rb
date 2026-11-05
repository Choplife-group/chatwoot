class AddLeadToTeamMembers < ActiveRecord::Migration[7.2]
  def change
    add_column :team_members, :lead, :boolean, default: false, null: false
  end
end

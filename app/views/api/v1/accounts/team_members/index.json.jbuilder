json.array! @team_members do |team_member|
  json.partial! 'api/v1/models/agent', formats: [:json], resource: team_member
  json.lead lead_ids.include?(team_member.id)
end

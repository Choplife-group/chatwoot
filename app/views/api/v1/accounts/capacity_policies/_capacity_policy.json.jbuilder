json.id capacity_policy.id
json.account_id capacity_policy.account_id
json.name capacity_policy.name
json.description capacity_policy.description
json.exclusion_rules do
  json.excluded_labels capacity_policy.excluded_labels
  json.exclude_older_than_hours capacity_policy.exclude_older_than_hours
end
json.assigned_agent_count capacity_policy.account_users.count
json.inbox_capacity_limits capacity_policy.capacity_limits do |capacity_limit|
  json.partial! 'api/v1/accounts/capacity_policies/inbox_limits/capacity_limit', capacity_limit: capacity_limit
end
json.created_at capacity_policy.created_at.to_i
json.updated_at capacity_policy.updated_at.to_i

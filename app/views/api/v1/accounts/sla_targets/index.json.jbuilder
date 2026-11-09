json.array! @sla_targets do |sla_target|
  json.partial! 'api/v1/models/sla_target', formats: [:json], resource: sla_target
end

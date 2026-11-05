json.array! @categories do |category|
  json.partial! 'api/v1/models/conversation_category', formats: [:json], resource: category
end

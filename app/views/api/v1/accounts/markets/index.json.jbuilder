json.array! @markets do |market|
  json.partial! 'api/v1/models/market', formats: [:json], resource: market
end

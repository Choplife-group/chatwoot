# Names for the ids in a report, so the client can show them without loading every market, team, category, agent and inbox
class Insights::Labels
  SOURCES = { 'market' => :markets, 'team' => :teams, 'agent' => :users, 'inbox' => :inboxes, 'category' => :conversation_categories }.freeze

  def initialize(account, ids_by_dimension)
    @account = account
    @ids_by_dimension = ids_by_dimension
  end

  def perform
    @ids_by_dimension.each_with_object({}) do |(dimension, ids), labels|
      ids = ids.compact.uniq
      labels[dimension] = names(dimension, ids).transform_keys(&:to_s) if ids.any?
    end
  end

  private

  def names(dimension, ids)
    return @account.conversation_categories.where(id: ids).to_h { |category| [category.id, category.path] } if dimension == 'subcategory'

    @account.public_send(SOURCES.fetch(dimension)).where(id: ids).pluck(:id, :name).to_h
  end
end

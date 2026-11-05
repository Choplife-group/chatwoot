# A person (agent or admin) can't resolve a conversation until it has a category.
# System resolutions (auto-resolve, the contact ending the chat, bots, automations) are not checked:
# they would otherwise leave conversations stuck open, and they show up as uncategorised in reports.
class Conversations::ResolveGuard
  def self.applies_to?(user)
    user.is_a?(User)
  end

  def self.blocked?(conversation, user)
    applies_to?(user) && !conversation.categorised?
  end
end

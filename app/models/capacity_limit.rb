# Choplife fork: the most open conversations an agent on a CapacityPolicy can hold in one inbox.
# Uses the shared inbox_capacity_limits table; see CapacityPolicy for why the class name differs.
class CapacityLimit < ApplicationRecord
  self.table_name = 'inbox_capacity_limits'

  belongs_to :capacity_policy, foreign_key: :agent_capacity_policy_id, inverse_of: :capacity_limits
  belongs_to :inbox

  validates :conversation_limit, numericality: { only_integer: true, greater_than: 0 }
  validates :inbox_id, uniqueness: { scope: :agent_capacity_policy_id }
  validate :inbox_belongs_to_policy_account

  private

  def inbox_belongs_to_policy_account
    return if inbox.blank? || capacity_policy.blank? || inbox.account_id == capacity_policy.account_id

    errors.add(:inbox, 'must belong to the same account')
  end
end

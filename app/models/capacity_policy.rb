# Choplife fork: agent capacity for the Community Edition build.
# Uses the shared agent_capacity_policies table and the existing settings UI. enterprise/ ships its own
# AgentCapacityPolicy class (commercially licensed, stripped from our image), so ours has a different name.
#
# exclusion_rules: { 'excluded_labels' => [...], 'exclude_older_than_hours' => Integer }
# Conversations matching either rule don't count towards an agent's limit.
class CapacityPolicy < ApplicationRecord
  self.table_name = 'agent_capacity_policies'

  belongs_to :account
  has_many :capacity_limits, foreign_key: :agent_capacity_policy_id, dependent: :destroy, inverse_of: :capacity_policy
  has_many :account_users, foreign_key: :agent_capacity_policy_id, dependent: :nullify, inverse_of: :capacity_policy

  validates :name, presence: true, length: { maximum: 255 }
  validate :validate_exclusion_rules

  def excluded_labels
    Array(exclusion_rules['excluded_labels'])
  end

  def exclude_older_than_hours
    exclusion_rules['exclude_older_than_hours'].presence&.to_i
  end

  private

  def validate_exclusion_rules
    hours = exclusion_rules['exclude_older_than_hours']
    return if hours.blank? || (hours.to_s.match?(/\A\d+\z/) && hours.to_i.positive?)

    errors.add(:exclusion_rules, 'exclude_older_than_hours must be a positive whole number')
  end
end

CapacityPolicy.include(ChopwinAudited)

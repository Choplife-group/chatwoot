# == Schema Information
#
# Table name: sla_targets
#
#  id                     :bigint           not null, primary key
#  business_hours         :boolean          default(FALSE), not null
#  first_response_seconds :integer
#  priority               :integer
#  resolution_seconds     :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  market_id              :bigint
#
# Indexes
#
#  index_sla_targets_on_account_id               (account_id)
#  index_sla_targets_on_account_market_priority  (account_id, COALESCE(market_id, (0)::bigint), COALESCE(priority, '-1'::integer)) UNIQUE
#
# The first response and resolution times Insights measures SLA compliance against.
# A target with no market or no priority covers all of them. The most specific target for a conversation applies.
class SlaTarget < ApplicationRecord
  belongs_to :account
  belongs_to :market, optional: true

  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }, validate: { allow_nil: true }

  validates :first_response_seconds, :resolution_seconds, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :sets_a_target
  validate :one_target_per_market_and_priority
  validate :market_in_account

  private

  def sets_a_target
    errors.add(:base, I18n.t('errors.sla_targets.needs_a_target')) if first_response_seconds.blank? && resolution_seconds.blank?
  end

  def one_target_per_market_and_priority
    return unless SlaTarget.where(account_id: account_id, market_id: market_id, priority: priority).where.not(id: id).exists?

    errors.add(:base, I18n.t('errors.sla_targets.taken'))
  end

  def market_in_account
    errors.add(:market_id, :invalid) if market && market.account_id != account_id
  end
end

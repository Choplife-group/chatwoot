# == Schema Information
#
# Table name: insight_dashboards
#
#  id              :bigint           not null, primary key
#  audience        :integer          default("private"), not null
#  filters         :jsonb            not null
#  name            :string           not null
#  refresh_seconds :integer          default(60), not null
#  widgets         :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  custom_role_id  :bigint
#  user_id         :bigint           not null
#
# Indexes
#
#  index_insight_dashboards_on_account_id      (account_id)
#  index_insight_dashboards_on_custom_role_id  (custom_role_id)
#  index_insight_dashboards_on_user_id         (user_id)
#
# A page of Insights widgets that refreshes on its own. It can be private, for everyone with one role, or for everyone.
# Each widget keeps a copy of a report's settings, and every viewer's figures are worked out for them,
# so a shared dashboard never shows anyone more than they're allowed to see.
class InsightDashboard < ApplicationRecord
  DISPLAYS = %w[number bar table].freeze
  REFRESH_SECONDS = [30, 60, 300, 900].freeze
  MAX_WIDGETS = 12
  # Dashboard filters replace each widget's own period and filters
  FILTER_KEYS = ['period', *Insights::ReportConfig::FILTERS].freeze

  belongs_to :account
  belongs_to :user
  belongs_to :support_role, foreign_key: :custom_role_id, optional: true, inverse_of: :insight_dashboards

  enum :audience, { private: 0, role: 1, everyone: 2 }, prefix: :for, validate: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :refresh_seconds, inclusion: { in: REFRESH_SECONDS }
  validates :custom_role_id, presence: true, if: :for_role?
  validate :role_in_account, :valid_widgets, :valid_filters

  before_validation { self.custom_role_id = nil unless for_role? }

  # Your own, the ones for everyone, and the ones for your role. A role dashboard whose role was deleted shows only to its owner.
  scope :visible_to, lambda { |account_user|
    visible = where(user_id: account_user.user_id).or(for_everyone)
    account_user.custom_role_id ? visible.or(for_role.where(custom_role_id: account_user.custom_role_id)) : visible
  }

  private

  def role_in_account
    errors.add(:custom_role_id, :invalid) if support_role && support_role.account_id != account_id
  end

  def valid_widgets
    return errors.add(:widgets, :too_long, count: MAX_WIDGETS) if !widgets.is_a?(Array) || widgets.size > MAX_WIDGETS

    errors.add(:widgets, :invalid) unless widgets.all? { |widget| valid_widget?(widget) }
  end

  def valid_widget?(widget)
    config = Insights::ReportConfig.new(widget['config'] || {})
    widget['id'].present? && DISPLAYS.include?(widget['display']) && config.valid? && config.metrics.include?(widget['metric'])
  end

  def valid_filters
    return errors.add(:filters, :invalid) unless filters.is_a?(Hash) && (filters.keys - FILTER_KEYS).empty?

    period = filters['period']
    errors.add(:filters, :invalid) if period.present? && Insights::Period::PRESETS.exclude?(period)
  end
end

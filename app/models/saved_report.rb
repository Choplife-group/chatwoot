# A report someone built in Insights, kept so they can open it again. Shared reports show to everyone in the account,
# each person seeing only the figures they're allowed to see, because the report is worked out for whoever opens it.
# == Schema Information
#
# Table name: saved_reports
#
#  id         :bigint           not null, primary key
#  config     :jsonb            not null
#  name       :string           not null
#  shared     :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_saved_reports_on_account_id  (account_id)
#  index_saved_reports_on_user_id     (user_id)
#
class SavedReport < ApplicationRecord
  belongs_to :account
  belongs_to :user
  has_many :report_snapshots, dependent: :nullify
  has_many :report_schedules, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validate :config_is_a_valid_report

  scope :visible_to, ->(user) { where(user: user).or(where(shared: true)) }

  def report_config
    Insights::ReportConfig.new(config)
  end

  private

  def config_is_a_valid_report
    report = report_config
    errors.add(:config, report.errors.full_messages.to_sentence) unless report.valid?
  end
end

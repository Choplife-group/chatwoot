# Figures frozen at one moment. They stay the same after conversations move to another market, team or category.
# Only the person who took it sees it, because the figures were worked out with what they're allowed to see.
# == Schema Information
#
# Table name: report_snapshots
#
#  id              :bigint           not null, primary key
#  captured_at     :datetime         not null
#  config          :jsonb            not null
#  name            :string           not null
#  result          :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  saved_report_id :bigint
#  user_id         :bigint           not null
#
# Indexes
#
#  index_report_snapshots_on_account_id       (account_id)
#  index_report_snapshots_on_saved_report_id  (saved_report_id)
#  index_report_snapshots_on_user_id          (user_id)
#
class ReportSnapshot < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :saved_report, optional: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :config, :result, :captured_at, presence: true
end

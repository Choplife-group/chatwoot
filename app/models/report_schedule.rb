# == Schema Information
#
# Table name: report_schedules
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  day_of_month    :integer
#  file_types      :string           default([]), not null, is an Array
#  frequency       :integer          default("daily"), not null
#  hour            :integer          default(8), not null
#  last_sent_at    :datetime
#  next_run_at     :datetime
#  recipient_ids   :bigint           default([]), not null, is an Array
#  timezone        :string           default("UTC"), not null
#  weekday         :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  saved_report_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_report_schedules_on_account_id              (account_id)
#  index_report_schedules_on_active_and_next_run_at  (active,next_run_at)
#  index_report_schedules_on_saved_report_id         (saved_report_id)
#  index_report_schedules_on_user_id                 (user_id)
#
# Emails a saved report on a daily, weekly or monthly cadence. Each recipient gets the report worked out for them,
# so they only ever see the figures they're allowed to see, with the files attached.
class ReportSchedule < ApplicationRecord
  belongs_to :account
  belongs_to :saved_report
  belongs_to :user

  enum :frequency, { daily: 0, weekly: 1, monthly: 2 }, validate: true

  validates :hour, inclusion: { in: 0..23 }
  validates :weekday, inclusion: { in: 0..6 }, if: :weekly?
  # Up to the 28th, so every month has the day
  validates :day_of_month, inclusion: { in: 1..28 }, if: :monthly?
  validates :recipient_ids, presence: true
  validate :recipients_in_account, :known_file_types, :known_timezone

  before_save :set_next_run_at, if: -> { new_record? || changed.intersect?(%w[frequency hour weekday day_of_month timezone active]) }

  scope :due, -> { where(active: true).where(next_run_at: ..Time.current) }

  def recipients
    account.users.where(id: recipient_ids)
  end

  # The next time it should go out after the given moment, in the schedule's time zone
  def next_run_after(moment)
    local = moment.in_time_zone(timezone)
    candidate = local.change(hour: hour, min: 0)
    candidate = candidate.change(day: day_of_month) if monthly?
    candidate += ((weekday - candidate.wday) % 7).days if weekly?
    return candidate if candidate > local

    candidate + { 'daily' => 1.day, 'weekly' => 1.week, 'monthly' => 1.month }.fetch(frequency)
  end

  private

  def set_next_run_at
    self.next_run_at = active? ? next_run_after(Time.current) : nil
  end

  def recipients_in_account
    errors.add(:recipient_ids, :invalid) if recipients.count != recipient_ids.uniq.size
  end

  def known_file_types
    errors.add(:file_types, :invalid) if file_types.blank? || (file_types - Insights::ExportService::FORMATS).any?
  end

  def known_timezone
    errors.add(:timezone, :invalid) if ActiveSupport::TimeZone[timezone].nil?
  end
end

# == Schema Information
#
# Table name: reporting_events
#
#  id                      :bigint           not null, primary key
#  event_end_time          :datetime
#  event_start_time        :datetime
#  name                    :string
#  value                   :float
#  value_in_business_hours :float
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :integer
#  category_id             :bigint
#  conversation_id         :integer
#  inbox_id                :integer
#  market_id               :bigint
#  team_id                 :bigint
#  user_id                 :integer
#
# Indexes
#
#  index_reporting_events_for_response_distribution       (account_id,name,inbox_id,created_at)
#  index_reporting_events_on_account_id                   (account_id)
#  index_reporting_events_on_account_name_event_end_time  (account_id,name,event_end_time)
#  index_reporting_events_on_conversation_id              (conversation_id)
#  index_reporting_events_on_created_at                   (created_at)
#  index_reporting_events_on_inbox_id                     (inbox_id)
#  index_reporting_events_on_name                         (name)
#  index_reporting_events_on_user_id                      (user_id)
#  reporting_events__account_id__name__created_at         (account_id,name,created_at)
#

class ReportingEvent < ApplicationRecord
  validates :account_id, presence: true
  validates :name, presence: true
  validates :value, presence: true

  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :inbox, optional: true
  belongs_to :conversation, optional: true

  # Record the conversation's market, team and category as they were when the event happened,
  # so moving a conversation to another market, team or category later doesn't change past reports
  before_create :snapshot_conversation_dimensions, if: :conversation

  # Scopes for filtering
  scope :filter_by_date_range, lambda { |range|
    where(created_at: range) if range.present?
  }

  scope :filter_by_inbox_id, lambda { |inbox_id|
    where(inbox_id: inbox_id) if inbox_id.present?
  }

  scope :filter_by_user_id, lambda { |user_id|
    where(user_id: user_id) if user_id.present?
  }

  scope :filter_by_name, lambda { |name|
    where(name: name) if name.present?
  }

  private

  def snapshot_conversation_dimensions
    self.market_id ||= conversation.market_id
    self.team_id ||= conversation.team_id
    self.category_id ||= conversation.category_id
  end
end

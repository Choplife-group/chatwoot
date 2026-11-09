# == Schema Information
#
# Table name: markets
#
#  id          :bigint           not null, primary key
#  archived_at :datetime
#  code        :string           not null
#  name        :string           not null
#  position    :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_markets_on_account_id_and_code  (account_id,code) UNIQUE
#  index_markets_on_account_id_and_name  (account_id,name) UNIQUE
#
class Market < ApplicationRecord
  belongs_to :account
  has_many :inboxes, dependent: :nullify
  has_many :contacts, dependent: :nullify
  has_many :sla_targets, dependent: :destroy
  has_many :conversations, dependent: :nullify

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(:position, :name) }

  validates :name, presence: true, uniqueness: { scope: :account_id }
  # ISO-3166 alpha-2, the same country codes our backend services use
  validates :code, presence: true, format: { with: /\A[A-Z]{2}\z/ }, uniqueness: { scope: :account_id }

  before_validation do
    self.name = name.strip if name.present?
    self.code = code.strip.upcase if code.present?
  end

  def archived?
    archived_at.present?
  end

  def push_event_data
    { id: id, name: name, code: code }
  end
end

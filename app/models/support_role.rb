# == Schema Information
#
# Table name: custom_roles
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string
#  permissions :text             default([]), is an Array
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_custom_roles_on_account_id           (account_id)
#  index_custom_roles_on_account_id_and_name  (account_id,name) UNIQUE
#
# A named set of permissions, given to agents through account_users.custom_role_id. Administrators don't need one.
# Named SupportRole, not CustomRole, so it can't resolve to the commercial class in enterprise/, which loads even with DISABLE_ENTERPRISE.
class SupportRole < ApplicationRecord
  self.table_name = 'custom_roles'

  PERMISSIONS = %w[
    conversation_manage conversation_assign conversation_delete vip_manage report_manage category_manage team_manage market_manage inbox_manage agent_manage role_manage
  ].freeze

  belongs_to :account
  has_many :account_users, foreign_key: :custom_role_id, dependent: :nullify, inverse_of: :support_role

  validates :name, presence: true, length: { maximum: 255 }, uniqueness: { scope: :account_id }
  validates :permissions, presence: true
  validate :permissions_are_known

  before_validation { self.name = name.strip if name.present? }

  private

  def permissions_are_known
    errors.add(:permissions, :invalid) if (permissions - PERMISSIONS).present?
  end
end

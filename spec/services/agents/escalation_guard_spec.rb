require 'rails_helper'

RSpec.describe Agents::EscalationGuard do
  subject(:guard) { described_class.new(account_user: actor) }

  let(:account) { create(:account) }
  let(:own_role) { create(:support_role, account: account, permissions: %w[agent_manage role_manage report_manage]) }
  let(:smaller_role) { create(:support_role, account: account, permissions: ['report_manage']) }
  let(:bigger_role) { create(:support_role, account: account, permissions: %w[report_manage vip_manage]) }
  let(:actor) { create(:user, account: account, role: :agent).account_users.first }
  let(:target) { create(:user, account: account, role: :agent).account_users.first }

  before do
    account.enable_features!('support_roles')
    actor.update!(custom_role_id: own_role.id)
  end

  describe '#can_give?' do
    it 'allows agent and roles within their own permissions' do
      expect(guard.can_give?('agent', nil)).to be(true)
      expect(guard.can_give?(nil, smaller_role.id)).to be(true)
    end

    it 'refuses administrator in any form' do
      ['administrator', 1, '1', ''].each { |role| expect(guard.can_give?(role, nil)).to be(false) }
    end

    it 'refuses a role with a permission they lack' do
      expect(guard.can_give?(nil, bigger_role.id)).to be(false)
    end
  end

  describe '#can_manage_agent?' do
    it 'allows someone with no more access' do
      target.update!(custom_role_id: smaller_role.id)

      expect(guard.can_manage_agent?(target)).to be(true)
    end

    it 'refuses administrators, themselves and anyone with more access' do
      administrator = create(:user, account: account, role: :administrator).account_users.first
      target.update!(custom_role_id: bigger_role.id)

      expect(guard.can_manage_agent?(administrator)).to be(false)
      expect(guard.can_manage_agent?(actor)).to be(false)
      expect(guard.can_manage_agent?(target)).to be(false)
    end
  end

  describe 'roles' do
    it 'only allows permissions they hold' do
      expect(guard.can_set_permissions?(['report_manage'])).to be(true)
      expect(guard.can_set_permissions?(%w[report_manage vip_manage])).to be(false)
    end

    it 'refuses their own role and roles with more access' do
      expect(guard.can_manage_role?(smaller_role)).to be(true)
      expect(guard.can_manage_role?(own_role)).to be(false)
      expect(guard.can_manage_role?(bigger_role)).to be(false)
    end
  end

  it 'lets an administrator do all of it' do
    admin_guard = described_class.new(account_user: create(:user, account: account, role: :administrator).account_users.first)

    expect(admin_guard.can_give?('administrator', bigger_role.id)).to be(true)
    expect(admin_guard.can_manage_role?(bigger_role)).to be(true)
    expect(admin_guard.can_set_permissions?(SupportRole::PERMISSIONS)).to be(true)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountUser do
  include ActiveJob::TestHelper

  let!(:account_user) { create(:account_user) }
  let!(:inbox) { create(:inbox, account: account_user.account) }

  describe 'notification_settings' do
    it 'gets created with the right default settings' do
      expect(account_user.user.notification_settings).not_to be_nil

      expect(account_user.user.notification_settings.first.email_conversation_creation?).to be(false)
      expect(account_user.user.notification_settings.first.email_conversation_assignment?).to be(true)
    end
  end

  describe 'permissions' do
    it 'returns the right permissions' do
      expect(account_user.permissions).to eq(['agent'])
    end

    it 'returns the right permissions for administrator' do
      account_user.administrator!
      expect(account_user.permissions).to eq(['administrator'])
    end
  end

  describe 'destroy call agent::destroy service' do
    it 'gets created with the right default settings' do
      create(:conversation, account: account_user.account, assignee: account_user.user, inbox: inbox)
      user = account_user.user

      expect(user.assigned_conversations.count).to eq(1)

      perform_enqueued_jobs do
        account_user.destroy!
      end

      expect(user.assigned_conversations.count).to eq(0)
    end
  end

  describe 'filtered unread count invalidation' do
    let(:account) { create(:account) }
    let(:user) { create(:user) }
    let(:invalidator) { instance_double(Conversations::UnreadCounts::FilteredCountInvalidator, user_visibility_changed!: true) }

    before do
      allow(Conversations::UnreadCounts::FilteredCountInvalidator).to receive(:new).and_return(invalidator)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'invalidates filtered counts when the user is added to an account' do
      create(:account_user, account: account, user: user)

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id)
    end

    it 'invalidates filtered counts when the user role changes' do
      account_user = create(:account_user, account: account, user: user)

      account_user.update!(role: :administrator)

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id).twice
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.cache_invalidated',
        kind_of(Time),
        account: account,
        cache_keys: account.cache_keys
      )
    end

    it 'invalidates filtered counts when the user is removed from an account' do
      account_user = create(:account_user, account: account, user: user)

      account_user.destroy!

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id).twice
    end
  end

  describe 'support roles' do
    let(:role) { create(:support_role, account: account_user.account, permissions: %w[report_manage vip_manage]) }

    before { account_user.update!(role: :agent) }

    it 'adds the role\'s permissions to the agent\'s when the feature is on' do
      account_user.account.enable_features!('support_roles')
      account_user.update!(custom_role_id: role.id)

      expect(account_user.reload.permissions).to eq(%w[agent report_manage vip_manage])
    end

    it 'ignores the role when the feature is off' do
      account_user.update!(custom_role_id: role.id)

      expect(account_user.reload.permissions).to eq(['agent'])
    end

    it 'turns an administrator given a role into an agent' do
      account_user.update!(role: :administrator)

      account_user.update!(custom_role_id: role.id)

      expect(account_user.reload).to have_attributes(role: 'agent', custom_role_id: role.id)
    end

    it 'clears the role when someone becomes an administrator' do
      account_user.update!(custom_role_id: role.id)

      account_user.update!(role: :administrator)

      expect(account_user.reload.custom_role_id).to be_nil
    end

    it 'rejects a role from another account' do
      expect(account_user.update(custom_role_id: create(:support_role).id)).to be(false)
    end
  end

  describe 'conversation permissions' do
    let(:account) { account_user.account }
    let(:role) { create(:support_role, account: account, permissions: ['conversation_manage']) }

    before do
      account_user.update!(role: :agent, custom_role_id: role.id)
      account.enable_features!('support_roles')
    end

    it 'checks a single permission, and administrators have them all' do
      expect(account_user.reload.can?('conversation_manage')).to be(true)
      expect(account_user.can?('vip_manage')).to be(false)

      account_user.update!(role: :administrator)
      expect(account_user.reload.can?('vip_manage')).to be(true)
    end

    it 'only lifts the conversation limits when restricted_inbox_access is on' do
      expect(account_user.reload.sees_all_conversations?).to be(false)

      account.enable_features!('restricted_inbox_access')

      expect(account_user.reload.sees_all_conversations?).to be(true)
    end

    it 'finds people by a permission in their role' do
      expect(described_class.with_permission('conversation_manage')).to include(account_user)
      expect(described_class.with_permission('vip_manage')).not_to include(account_user)
    end
  end
end

require 'rails_helper'

RSpec.describe ConversationCategory do
  let(:account) { create(:account) }
  let(:withdrawal) { create(:conversation_category, account: account, name: 'Withdrawal') }
  let(:pending_approval) { create(:conversation_category, account: account, name: 'Pending approval', parent: withdrawal) }

  describe 'tree' do
    it 'sets depth and ancestors from the parent' do
      expect(withdrawal).to have_attributes(depth: 1, ancestor_ids: [])
      expect(pending_approval).to have_attributes(depth: 2, ancestor_ids: [withdrawal.id])
      expect(pending_approval.path).to eq('Withdrawal › Pending approval')
    end

    it 'allows at most five levels' do
      node = pending_approval
      3.times { |i| node = create(:conversation_category, account: account, name: "Level #{i + 3}", parent: node) }

      expect(node.depth).to eq(5)
      expect(build(:conversation_category, account: account, parent: node)).not_to be_valid
    end

    it 'keeps names unique among siblings only' do
      pending_approval
      deposit = create(:conversation_category, account: account, name: 'Deposit')

      expect(build(:conversation_category, account: account, name: 'Pending approval', parent: withdrawal)).not_to be_valid
      expect(build(:conversation_category, account: account, name: 'Pending approval', parent: deposit)).to be_valid
    end

    it 'does not move to another parent' do
      pending_approval.parent = create(:conversation_category, account: account)

      expect(pending_approval).not_to be_valid
    end

    it 'does not take a parent from another account' do
      expect(build(:conversation_category, account: account, parent: create(:conversation_category))).not_to be_valid
    end
  end

  describe '#leaf?' do
    it 'ignores archived children' do
      pending_approval
      expect(withdrawal.leaf?).to be false

      pending_approval.update!(archived_at: Time.current)
      expect(withdrawal.leaf?).to be true
    end
  end

  describe '.subtree_ids' do
    it 'returns the categories and everything below them' do
      pending_approval
      other = create(:conversation_category, account: account)

      expect(described_class.subtree_ids(account, withdrawal.id)).to contain_exactly(withdrawal.id, pending_approval.id)
      expect(described_class.subtree_ids(account, [pending_approval.id, other.id])).to contain_exactly(pending_approval.id, other.id)
    end
  end
end

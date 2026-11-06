require 'rails_helper'

RSpec.describe SupportRole do
  let(:account) { create(:account) }

  it 'uses the custom_roles table' do
    expect(described_class.table_name).to eq('custom_roles')
  end

  it 'accepts every core permission' do
    expect(build(:support_role, account: account, permissions: described_class::PERMISSIONS)).to be_valid
  end

  it 'rejects an unknown permission' do
    expect(build(:support_role, account: account, permissions: ['do_anything'])).not_to be_valid
  end

  it 'needs at least one permission' do
    expect(build(:support_role, account: account, permissions: [])).not_to be_valid
  end

  it 'needs a name that is unique in the account' do
    create(:support_role, account: account, name: 'Head of Support')

    expect(build(:support_role, account: account, name: 'Head of Support')).not_to be_valid
    expect(build(:support_role, name: 'Head of Support')).to be_valid
  end

  it 'turns its holders into plain agents when deleted' do
    role = create(:support_role, account: account)
    account_user = create(:user, account: account, role: :agent).account_users.first
    account_user.update!(custom_role_id: role.id)

    role.destroy!

    expect(account_user.reload).to have_attributes(custom_role_id: nil, role: 'agent')
  end
end

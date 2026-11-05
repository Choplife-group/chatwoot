require 'rails_helper'

RSpec.describe Market do
  let(:account) { create(:account) }

  describe 'validations' do
    it 'normalises the code to upper case' do
      expect(create(:market, account: account, code: ' ug ').code).to eq('UG')
    end

    it 'only accepts two-letter codes' do
      expect(build(:market, account: account, code: 'UGA')).not_to be_valid
      expect(build(:market, account: account, code: 'U1')).not_to be_valid
    end

    it 'keeps names and codes unique per account' do
      create(:market, account: account, name: 'Uganda', code: 'UG')

      expect(build(:market, account: account, name: 'Uganda', code: 'KE')).not_to be_valid
      expect(build(:market, account: account, name: 'Kenya', code: 'UG')).not_to be_valid
      expect(build(:market, account: create(:account), name: 'Uganda', code: 'UG')).to be_valid
    end
  end

  it 'lists active markets in display order' do
    second = create(:market, account: account, name: 'B', position: 2)
    first = create(:market, account: account, name: 'A', position: 1)
    create(:market, account: account, archived_at: Time.current)

    expect(account.markets.active.ordered).to eq([first, second])
  end
end

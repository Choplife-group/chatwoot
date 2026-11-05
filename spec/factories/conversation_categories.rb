FactoryBot.define do
  factory :conversation_category do
    sequence(:name) { |n| "Category #{n}" }
    account
  end
end

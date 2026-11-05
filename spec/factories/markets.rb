FactoryBot.define do
  factory :market do
    sequence(:name) { |n| "Market #{n}" }
    sequence(:code) { |n| ('AA'..'ZZ').to_a[n % 676] }
    account
  end
end

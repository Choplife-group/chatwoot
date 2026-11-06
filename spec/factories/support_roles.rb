# frozen_string_literal: true

FactoryBot.define do
  factory :support_role do
    account
    sequence(:name) { |n| "Role #{n}" }
    permissions { ['conversation_manage'] }
  end
end

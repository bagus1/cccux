FactoryBot.define do
  factory :post do
    title   { "Test Post" }
    content { "Test content" }
    association :user
  end
end 
FactoryBot.define do
  factory :post_manager do
    association :user
    association :post
  end
end

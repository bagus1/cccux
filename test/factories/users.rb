FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "Test" }
    last_name  { "User" }
    active     { true }
    password   { "password123" }
    password_confirmation { "password123" }
  end
end 
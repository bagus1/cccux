FactoryBot.define do
  factory :role, class: 'Cccux::Role' do
    sequence(:name) { |n| "Role#{n}" }
    active { true }
  end
end 
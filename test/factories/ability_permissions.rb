FactoryBot.define do
  factory :ability_permission, class: 'Cccux::AbilityPermission' do
    action  { "read" }
    subject { "Post" }
  end
end 
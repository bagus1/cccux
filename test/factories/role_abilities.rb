FactoryBot.define do
  factory :role_ability, class: 'Cccux::RoleAbility' do
    association :role, factory: :role
    association :ability_permission, factory: :ability_permission
    owned { false }
    context { 'global' }
  end
end 
# Seeds for CCCUX Engine
puts "🌱 Seeding CCCUX data..."

# Create comprehensive permissions for all CCCUX models
cccux_models = ['User', 'Role', 'AbilityPermission', 'UserRole', 'RoleAbility']
# Use granular RESTful actions instead of simplified CRUD
restful_actions = ['index', 'show', 'new', 'create', 'edit', 'update', 'destroy']

puts "📋 Creating permissions for CCCUX models..."
cccux_models.each do |model|
  restful_actions.each do |action|
    permission = Cccux::AbilityPermission.find_or_create_by(
      action: action,
      subject: "Cccux::#{model}"
    ) do |p|
      p.description = "#{action.capitalize} #{model.downcase.pluralize}"
      p.active = true
    end
  end
end

# Create permissions for host app models (without Cccux namespace)
host_models = ['User', 'Role', 'AbilityPermission']
host_models.each do |model|
  restful_actions.each do |action|
    permission = Cccux::AbilityPermission.find_or_create_by(
      action: action,
      subject: model
    ) do |p|
      p.description = "#{action.capitalize} host app #{model.downcase.pluralize}"
      p.active = true
    end
  end
end

# Create special 'manage' permissions for Role and AbilityPermission
['Role', 'AbilityPermission'].each do |model|
  permission = Cccux::AbilityPermission.find_or_create_by(
    action: 'manage',
    subject: model
  ) do |p|
    p.description = "Full management of #{model.downcase.pluralize}"
    p.active = true
  end
end

puts "✅ Created #{Cccux::AbilityPermission.count} permissions"

# Create Role Manager Role
role_manager_role = Cccux::Role.find_or_create_by(name: 'Role Manager') do |role|
  role.description = 'System administrator with full access to all CCCUX functionality'
  role.active = true
  role.priority = 1
end

# Create Guest Role  
guest_role = Cccux::Role.find_or_create_by(name: 'Guest') do |role|
  role.description = 'Guest users with minimal read-only permissions'
  role.active = true
  role.priority = 10
end

# Create Basic User Role (for new registrations)
basic_role = Cccux::Role.find_or_create_by(name: 'Basic User') do |role|
  role.description = 'Standard registered user with limited permissions'
  role.active = true
  role.priority = 5
end

puts "✅ Created #{Cccux::Role.count} roles"

puts "🔑 Assigning permissions to Role Manager role..."
# Assign Role Manager permissions - all RESTful actions:
role_manager_permissions = []

# CCCUX models: all RESTful actions
cccux_models.each do |model|
  restful_actions.each do |action|
    permission = Cccux::AbilityPermission.find_by(
      action: action, 
      subject: "Cccux::#{model}"
    )
    role_manager_permissions << permission if permission
  end
end

# Host app models: all RESTful actions
host_models.each do |model|
  restful_actions.each do |action|
    permission = Cccux::AbilityPermission.find_by(
      action: action,
      subject: model
    )
    role_manager_permissions << permission if permission
  end
end

# Special manage permissions for Role and AbilityPermission
['Role', 'AbilityPermission'].each do |model|
  permission = Cccux::AbilityPermission.find_by(
    action: 'manage',
    subject: model
  )
  role_manager_permissions << permission if permission
end

# Assign all permissions to Role Manager role
role_manager_permissions.compact.each do |permission|
  unless role_manager_role.ability_permissions.include?(permission)
    Cccux::RoleAbility.create!(role: role_manager_role, ability_permission: permission)
  end
end

puts "🔐 Assigning minimal permissions to Guest role..."
# Guest users get minimal read-only permissions
guest_permissions = [
  { action: 'index', subject: 'Order' },
  { action: 'show', subject: 'Order' }
]

guest_permissions.each do |perm|
  permission = Cccux::AbilityPermission.find_by(action: perm[:action], subject: perm[:subject])
  if permission && !guest_role.ability_permissions.include?(permission)
    Cccux::RoleAbility.create!(role: guest_role, ability_permission: permission)
  end
end

puts "✅ CCCUX seeded successfully!"
puts "🔧 #{role_manager_role.ability_permissions.count} permissions assigned to Role Manager role"
puts "👥 #{guest_role.ability_permissions.count} permissions assigned to Guest role"
puts "📊 #{Cccux::Role.count} roles created"
puts ""
puts "🎯 Next steps:"
puts "   1. Run the interactive setup: rake cccux:engine_init"
puts "   2. Or manually create your first Role Manager via console"
puts "   3. Visit /cccux to access the admin interface" 
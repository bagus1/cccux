# Seeds for CCCUX Engine
puts "🌱 Seeding CCCUX data..."

# Create Admin Role
admin_role = Cccux::Role.find_or_create_by(name: 'Admin') do |role|
  role.description = 'Full system administrator access'
  role.active = true
end

# Create Basic User Role  
basic_role = Cccux::Role.find_or_create_by(name: 'Basic User') do |role|
  role.description = 'Standard user with limited permissions'
  role.active = true
end

# Create Admin User with Devise authentication
admin_user = Cccux::User.find_or_create_by(email: 'admin@example.com') do |user|
  user.first_name = 'Admin'
  user.last_name = 'User'
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.active = true
end

# Assign Admin role to admin user
unless admin_user.has_role?('Admin')
  Cccux::UserRole.create!(user: admin_user, role: admin_role)
end

# Create some basic permissions
permissions = [
  { action: 'read', subject: 'User', description: 'View users' },
  { action: 'create', subject: 'User', description: 'Create new users' },
  { action: 'update', subject: 'User', description: 'Edit user information' },
  { action: 'destroy', subject: 'User', description: 'Delete users' },
  { action: 'manage', subject: 'Role', description: 'Full role management' },
  { action: 'manage', subject: 'AbilityPermission', description: 'Full permission management' }
]

permissions.each do |perm|
  Cccux::AbilityPermission.find_or_create_by(
    action: perm[:action], 
    subject: perm[:subject]
  ) do |permission|
    permission.description = perm[:description]
    permission.active = true
  end
end

# Assign all permissions to Admin role
admin_permissions = Cccux::AbilityPermission.all
admin_permissions.each do |permission|
  unless admin_role.ability_permissions.include?(permission)
    Cccux::RoleAbility.create!(role: admin_role, ability_permission: permission)
  end
end

puts "✅ CCCUX seeded successfully!"
puts "👤 Admin user created: admin@example.com / password123"
puts "🔑 #{admin_permissions.count} permissions assigned to Admin role"
puts "📊 #{Cccux::Role.count} roles created" 
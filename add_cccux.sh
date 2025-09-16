#!/bin/bash

# Script to add cccux gem to Gemfile in current directory
# Usage: ../cccux/add_cccux.sh

# Check if we're in a Rails project directory
if [ ! -f "Gemfile" ]; then
    echo "Error: No Gemfile found in current directory"
    echo "Make sure you're in a Rails project directory"
    exit 1
fi

# Check if cccux gem is already in Gemfile
if grep -q "gem 'cccux'" Gemfile; then
    echo "cccux gem is already in Gemfile"
    exit 0
fi

# Add the gem line to Gemfile
echo "gem 'cccux', path: '../cccux'" >> Gemfile

echo "Added 'gem \"cccux\", path: \"../cccux\"' to Gemfile"
echo "Installing CCCUX gem..."

# Run bundle install
bundle install

if [ $? -eq 0 ]; then
    echo "✅ CCCUX gem installed successfully"
else
    echo "❌ Failed to install CCCUX gem"
    echo "💡 Try running 'bundle install' manually"
    exit 1
fi

echo ""
echo "🔧 Setting up CCCUX authorization..."
echo "===================================="

# Run CCCUX setup
bundle exec rake cccux:setup

if [ $? -eq 0 ]; then
    echo "✅ CCCUX setup completed successfully"
else
    echo "❌ CCCUX setup failed"
    exit 1
fi

echo ""
echo "🔧 Initializing MegaBar with authorization..."
echo "============================================="

# Run MegaBar engine init
bundle exec rake mega_bar:engine_init

if [ $? -eq 0 ]; then
    echo "✅ MegaBar engine initialized successfully"
else
    echo "❌ MegaBar engine initialization failed"
    exit 1
fi

echo ""
echo "🔧 Creating missing 'all' permissions for MegaBar routes..."
echo "========================================================="

# Create missing 'all' permissions for MegaBar::Model and MegaBar::Page BEFORE creating the role
bundle exec rails runner "
begin
  # Create all permission for MegaBar::Model
  model_all_permission = Cccux::AbilityPermission.find_or_create_by(
    subject: 'MegaBar::Model',
    action: 'all'
  ) do |perm|
    perm.description = 'All megabar::models'
    perm.active = true
  end
  puts \"✅ Created all permission for MegaBar::Model\"
  
  # Create all permission for MegaBar::Page
  page_all_permission = Cccux::AbilityPermission.find_or_create_by(
    subject: 'MegaBar::Page',
    action: 'all'
  ) do |perm|
    perm.description = 'All megabar::pages'
    perm.active = true
  end
  puts \"✅ Created all permission for MegaBar::Page\"
  
  puts \"✅ All permissions created for MegaBar admin routes\"
rescue => e
  puts \"❌ Failed to create all permissions: #{e.message}\"
end
"

if [ $? -eq 0 ]; then
    echo "✅ All permissions creation completed"
else
    echo "⚠️  All permissions creation had issues (but setup continues)"
fi

echo ""
echo "🔧 Creating Mega Role for MegaBar permissions..."
echo "==============================================="

# Create Mega Role (this will now include the 'all' permissions we just created)
bundle exec rake cccux:megabar:create_mega_role

if [ $? -eq 0 ]; then
    echo "✅ Mega Role created with full MegaBar permissions"
else
    echo "❌ Mega Role creation failed"
    exit 1
fi

echo ""
echo "🔧 Assigning Mega Role to admin user..."
echo "======================================"

# Assign Mega Role to the admin user created during cccux:setup
bundle exec rails runner "
begin
  admin_user = User.first
  mega_role = Cccux::Role.find_by(name: 'Mega Role')
  
  if admin_user && mega_role
    # Check if user already has the role
    unless Cccux::UserRole.exists?(user: admin_user, role: mega_role)
      Cccux::UserRole.create!(user: admin_user, role: mega_role)
      puts \"✅ Assigned Mega Role to admin user: #{admin_user.email}\"
    else
      puts \"ℹ️  Admin user already has Mega Role\"
    end
  else
    puts \"⚠️  Could not find admin user or Mega Role\"
  end
rescue => e
  puts \"❌ Failed to assign Mega Role: #{e.message}\"
end
"

if [ $? -eq 0 ]; then
    echo "✅ Mega Role assignment completed"
else
    echo "⚠️  Mega Role assignment had issues (but setup continues)"
fi

echo ""
echo "🎉 Complete setup finished!"
echo "=========================="
echo ""
echo "🚀 Starting Rails server..."
echo "   Visit admin interfaces:"
echo "   - MegaBar: http://localhost:3000/mega-bar"
echo "   - CCCUX: http://localhost:3000/cccux"
echo ""
echo "💡 Users with 'Mega Role' have full MegaBar access!"
echo "   Press Ctrl+C to stop the server"
echo ""

# Start the Rails server
rails server 
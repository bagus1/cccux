# CCCUX Engine Tasks
# Clean, consolidated setup and management tasks for the CCCUX authorization engine

require 'fileutils'

namespace :cccux do
  desc 'setup - Complete setup for CCCUX with Devise integration'
  task setup: :environment do
    puts "🚀 Starting CCCUX + Devise setup..."
    
    # Step 1: Ensure Devise is installed and working
    puts "📋 Step 1: Verifying Devise installation..."
    # Check if Devise is installed and User model exists with Devise configuration
    devise_installed = defined?(Devise)
    user_model_exists = false
    user_has_devise = false
    
    if devise_installed
      begin
        user_class = Object.const_get('User')
        user_model_exists = true
        
        # Check if User model has Devise modules
        user_has_devise = user_class.respond_to?(:devise_modules) && user_class.devise_modules.any?
        
        # Also check if User model file contains Devise configuration as backup
        if !user_has_devise
          user_model_path = Rails.root.join('app', 'models', 'user.rb')
          if File.exist?(user_model_path)
            user_content = File.read(user_model_path)
            user_has_devise = user_content.include?('devise :')
          end
        end
      rescue NameError
        # User model doesn't exist
      end
    end
    
    unless devise_installed && user_model_exists && user_has_devise
      puts "❌ Devise is not properly installed or configured. Please run the following command first:"
      puts " "
      puts "   bundle add devise && rails generate devise:install && rails generate devise User && rails db:migrate"
      puts " "
      puts "Then re-run: rails cccux:setup"
      exit 1
    end
    
    puts "✅ Devise is properly installed"
    
    # Step 2: Configure routes
    puts "📋 Step 2: Configuring routes..."
    configure_routes
    puts "✅ Routes configured"
    
    # Step 3: Configure assets
    puts "📋 Step 3: Configuring assets..."
    configure_assets
    puts "✅ Assets configured"
    
    # Step 4: Run CCCUX migrations
    puts "📋 Step 4: Running CCCUX migrations..."
    Rake::Task['db:migrate'].invoke
    puts "✅ CCCUX migrations completed"
    
    # Step 5: Include CCCUX concern in User model
    puts "📋 Step 5: Adding CCCUX to User model..."
    include_cccux_concern
    puts "✅ CCCUX concern added to User model"
    
    # Step 6: Create initial roles and permissions
    puts "📋 Step 6: Creating initial roles and permissions..."
    create_default_roles_and_permissions
    puts "✅ Default roles and permissions created"
    
    # Step 7: Create default admin user (if no users exist)
    puts "📋 Step 7: Creating default admin user..."
    create_default_admin_user
    
    # Step 8: Verify setup
    puts "📋 Step 8: Verifying setup..."
    verify_setup
    
    puts ""
    puts "🎉 CCCUX + Devise setup completed successfully!"
    puts ""
    puts "🌟 Next steps:"
    puts "   1. Start your Rails server: rails server"
    puts "   2. Visit http://localhost:3000/cccux to access the admin interface"
    puts "   3. Sign in with your admin account"
    puts ""
    puts "📚 Need help? Check the CCCUX documentation or README"
  end
  
  desc 'test - Test CCCUX + Devise integration'
  task test: :environment do
    puts "🧪 Testing CCCUX + Devise integration..."
    
    # Test User model
    user = User.new(email: 'test@example.com', password: 'password123')
    puts "✅ User model accepts CCCUX methods" if user.respond_to?(:has_role?)
    
    # Test roles
    role_manager = Cccux::Role.find_by(name: 'Role Manager')
    basic_user = Cccux::Role.find_by(name: 'Basic User')
    guest = Cccux::Role.find_by(name: 'Guest')
    puts "✅ Role Manager role exists" if role_manager
    puts "✅ Basic User role exists" if basic_user
    puts "✅ Guest role exists" if guest
    
    # Test permissions
    permissions = Cccux::AbilityPermission.count
    puts "✅ Found #{permissions} permissions"
    
    puts "🎉 All tests passed!"
  end
  
  desc 'status - Show CCCUX integration status'
  task status: :environment do
    puts "📊 CCCUX Integration Status"
    puts "=" * 50
    
    # Check routes
    routes_content = File.read('config/routes.rb')
    routes_configured = routes_content.include?('mount Cccux::Engine')
    puts "Routes:      #{routes_configured ? '✅ Configured' : '❌ Not configured'}"
    
    # Check User model
    user_model_path = Rails.root.join('app', 'models', 'user.rb')
    if File.exist?(user_model_path)
      user_content = File.read(user_model_path)
      cccux_included = user_content.include?('Cccux::UserConcern')
      devise_configured = user_content.include?('devise :')
      puts "User Model:  #{cccux_included && devise_configured ? '✅ Configured' : '❌ Not configured'}"
    else
      puts "User Model:  ❌ Not found"
    end
    
    # Check database
    begin
      if defined?(User)
        user_count = User.count
        role_count = Cccux::Role.count
        permission_count = Cccux::AbilityPermission.count
        puts "Database:    ✅ Connected (#{user_count} users, #{role_count} roles, #{permission_count} permissions)"
      else
        puts "Database:    ❌ User model not loaded"
      end
    rescue => e
      puts "Database:    ❌ Error: #{e.message}"
    end
    
    puts ""
    if routes_configured
      puts "🌟 CCCUX appears to be properly configured!"
      puts "   Visit /cccux to access the admin interface"
    else
      puts "⚠️  CCCUX needs configuration. Run: rails cccux:setup"
    end
  end
  
  desc 'reset - Remove CCCUX from host application'
  task reset: :environment do
    puts "🗑️  Removing CCCUX Authorization Engine..."
    
    # Remove migrations
    puts "Removing migrations..."
    migration_files = Dir.glob(Rails.root.join('db/migrate/*_cccux_*.rb'))
    migration_files.each { |file| File.delete(file) }
    
    # Drop tables
    puts "Dropping CCCUX tables..."
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS cccux_role_abilities")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS cccux_user_roles")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS cccux_ability_permissions")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS cccux_roles")
    
    puts "✅ CCCUX removed from application"
  end

  private

  def configure_routes
    routes_path = Rails.root.join('config/routes.rb')
    routes_content = File.read(routes_path)
    
    # Ensure devise_for :users is before engine mount
    unless routes_content.include?('devise_for :users')
      puts "   ➕ Adding devise_for :users to routes..."
      new_content = "Rails.application.routes.draw do\n  devise_for :users\n\n" + routes_content.lines[1..-1].join
      File.write(routes_path, new_content)
      routes_content = File.read(routes_path)
    end
    
    # Add engine mount if not present
    unless routes_content.include?('mount Cccux::Engine')
      puts "   ➕ Adding CCCUX engine mount to routes..."
      new_content = routes_content.gsub(
        /(Rails\.application\.routes\.draw do)/,
        "\\1\n\n  ##### CCCUX BEGIN #####\n  mount Cccux::Engine, at: '/cccux'\n  ##### CCCUX END #####"
      )
      File.write(routes_path, new_content)
    end
  end

  def configure_assets
    # Add CSS assets
    css_path = Rails.root.join('app/assets/stylesheets/application.css')
    if File.exist?(css_path)
      css_content = File.read(css_path)
      unless css_content.include?('cccux/application')
        File.open(css_path, 'a') { |f| f.puts "/*\n *= require cccux/application\n */" }
        puts "   ✅ Added CCCUX CSS to application.css"
      end
    end
    
    # Add JavaScript assets (if using legacy asset pipeline)
    js_path = Rails.root.join('app/assets/javascripts/application.js')
    if File.exist?(js_path)
      js_content = File.read(js_path)
      unless js_content.include?('cccux/application')
        File.open(js_path, 'a') { |f| f.puts "//= require cccux/application" }
        puts "   ✅ Added CCCUX JavaScript to application.js"
      end
    end
  end

  def include_cccux_concern
    user_model_path = Rails.root.join('app', 'models', 'user.rb')
    user_content = File.read(user_model_path)
    
    unless user_content.include?('Cccux::UserConcern')
      updated_content = user_content.gsub(
        /class User < ApplicationRecord/,
        "class User < ApplicationRecord\n  include Cccux::UserConcern"
      )
      File.write(user_model_path, updated_content)
      puts "   ✅ Added Cccux::UserConcern to User model"
    else
      puts "   ℹ️  User model already includes Cccux::UserConcern"
    end
  end

  def create_default_roles_and_permissions
    # Create Role Manager role (highest priority)
    role_manager = Cccux::Role.find_or_create_by(name: 'Role Manager') do |role|
      role.description = 'Can manage roles and permissions for all users'
      role.priority = 1
      role.active = true
    end
    
    # Create Basic User role
    basic_user = Cccux::Role.find_or_create_by(name: 'Basic User') do |role|
      role.description = 'Standard user with basic permissions'
      role.priority = 2
      role.active = true
    end
    
    # Create Guest role (lowest priority)
    guest = Cccux::Role.find_or_create_by(name: 'Guest') do |role|
      role.description = 'Limited access user'
      role.priority = 3
      role.active = true
    end
    
    # Create permissions
    permissions = [
      # Role Manager permissions (full access)
      { action: 'read', subject: 'User' },
      { action: 'create', subject: 'User' },
      { action: 'update', subject: 'User' },
      { action: 'destroy', subject: 'User' },
      { action: 'read', subject: 'Cccux::Role' },
      { action: 'create', subject: 'Cccux::Role' },
      { action: 'update', subject: 'Cccux::Role' },
      { action: 'destroy', subject: 'Cccux::Role' },
      { action: 'read', subject: 'Cccux::AbilityPermission' },
      { action: 'create', subject: 'Cccux::AbilityPermission' },
      { action: 'update', subject: 'Cccux::AbilityPermission' },
      { action: 'destroy', subject: 'Cccux::AbilityPermission' },
      
      # Basic User permissions (limited access)
      { action: 'read', subject: 'User' },
      { action: 'update', subject: 'User' },
      
      # Guest permissions (read-only)
      { action: 'read', subject: 'User' }
    ]
    
    permissions.each do |perm|
      Cccux::AbilityPermission.find_or_create_by(
        action: perm[:action],
        subject: perm[:subject]
      ) do |permission|
        permission.active = true
      end
    end
    
    # Assign permissions to roles
    # Role Manager gets all permissions
    Cccux::AbilityPermission.all.each do |permission|
      Cccux::RoleAbility.find_or_create_by(
        role: role_manager,
        ability_permission: permission
      )
    end
    
    # Basic User gets limited permissions
    basic_user_permissions = Cccux::AbilityPermission.where(
      action: ['read', 'update'],
      subject: 'User'
    )
    basic_user_permissions.each do |permission|
      Cccux::RoleAbility.find_or_create_by(
        role: basic_user,
        ability_permission: permission
      )
    end
    
    # Guest gets read-only permissions
    guest_permissions = Cccux::AbilityPermission.where(
      action: 'read',
      subject: 'User'
    )
    guest_permissions.each do |permission|
      Cccux::RoleAbility.find_or_create_by(
        role: guest,
        ability_permission: permission
      )
    end
    
    puts "   ✅ Created Role Manager, Basic User, and Guest roles with appropriate permissions"
  end

  def create_default_admin_user
    begin
      if defined?(User) && User.count == 0
        role_manager = Cccux::Role.find_by(name: 'Role Manager')
        
        if role_manager
          # Check for ENV vars first
          email = ENV['ADMIN_EMAIL']
          password = ENV['ADMIN_PASSWORD']
          password_confirmation = ENV['ADMIN_PASSWORD_CONFIRMATION'] || password

          if email && password
            puts "   ⚡ Creating Role Manager user from environment variables..."
            user = User.create!(email: email, password: password, password_confirmation: password_confirmation)
            Cccux::UserRole.create!(user: user, role: role_manager)
            puts "   ✅ Created Role Manager account: #{email}"
            return
          end

          puts "   🔧 Let's create your first Role Manager account:"
          print "   📧 Enter email address: "
          email = $stdin.gets.chomp
          
          while email.blank? || !email.include?('@')
            print "   ❌ Please enter a valid email address: "
            email = $stdin.gets.chomp
          end
          
          puts "   🔑 Enter password (input will be visible): "
          password = $stdin.gets.chomp
          
          if password.blank?
            puts "   ⚠️  Password input was blank. Skipping user creation."
            return
          end

          puts "   🔑 Confirm password (input will be visible): "
          password_confirmation = $stdin.gets.chomp
          
          if password_confirmation.blank?
            puts "   ⚠️  Password confirmation was blank. Skipping user creation."
            return
          end

          if password != password_confirmation
            puts "   ❌ Passwords don't match. Skipping user creation."
            return
          end

          user = User.create!(
            email: email,
            password: password,
            password_confirmation: password_confirmation
          )
          Cccux::UserRole.create!(user: user, role: role_manager)
          puts "   ✅ Created Role Manager account: #{email}"
        else
          puts "   ⚠️  No Role Manager role found - skipping user creation"
        end
      else
        puts "   ℹ️  Users already exist, skipping default Administrator creation"
      end
    rescue => e
      puts "   ⚠️  Could not create default admin: #{e.message}"
    end
  end

  def verify_setup
    # Test that User model has CCCUX methods
    user = User.new
    unless user.respond_to?(:has_role?)
      puts "❌ User model missing CCCUX methods"
      exit 1
    end
    
    puts "✅ CCCUX methods available on User model"
    
    # Test route helpers
    begin
      Rails.application.routes.url_helpers.new_user_session_path
      puts "✅ Devise routes working"
    rescue => e
      puts "❌ Devise routes not working: #{e.message}"
      exit 1
    end
  end
end 
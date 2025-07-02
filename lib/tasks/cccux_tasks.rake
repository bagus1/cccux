# CCCUX Engine Tasks
# Automated setup and management tasks for the CCCUX authorization engine

require 'fileutils'

namespace :cccux do
  desc 'setup - Install and configure CCCUX Authorization Engine'
  task setup: :environment do
    puts "🚀 Setting up CCCUX Authorization Engine..."
    puts ""

    # 1. Check for existing User model
    user_model_exists = check_for_user_model
    if user_model_exists
      puts "✅ Found existing User model - will integrate with it"
    else
      puts "❌ No User model found"
      setup_devise_and_user if offer_devise_setup
    end

    # 2. Run migrations
    puts ""
    puts "📦 Running database migrations..."
    Rake::Task['cccux:install:migrations'].invoke
    Rake::Task['db:migrate'].invoke

    # 3. Create default roles and permissions
    puts ""
    puts "👥 Creating default roles and permissions..."
    create_default_roles_and_permissions

    # 4. Create default admin user (if no users exist)
    puts ""
    puts "👤 Creating default admin user..."
    create_default_admin_user

    # 5. Setup complete
    puts ""
    puts "🎉 CCCUX Authorization Engine setup complete!"
    puts ""
    puts "✅ Engine mounted at /cccux"
    puts "✅ Database migrations run"
    puts "✅ Default roles and permissions created"
    puts "✅ Default admin user created (if needed)"
    puts ""
    puts "🌟 Next steps:"
    puts "   1. Include CCCUX in your User model:"
    puts "      class User < ApplicationRecord"
    puts "        include CccuxUserConcern"
    puts "        # ... your existing code"
    puts "      end"
    puts ""
    puts "   2. Start your Rails server: rails server"
    puts "   3. Visit http://localhost:3000/cccux"
    puts "   4. Begin configuring users, roles, and permissions"
    puts ""
    puts "📚 Need help? Check the CCCUX documentation or README"
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
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS cccux_users")
    
    puts "✅ CCCUX removed from application"
  end
  
  desc 'status - Show CCCUX integration status'
  task status: :environment do
    puts "📊 CCCUX Integration Status"
    puts "=" * 50
    
    # Check routes
    routes_content = File.read('config/routes.rb')
    routes_configured = routes_content.include?('mount Cccux::Engine')
    puts "Routes:      #{routes_configured ? '✅ Configured' : '❌ Not configured'}"
    
    # Check JavaScript
    js_path = 'app/assets/javascripts/application.js'
    if File.exist?(js_path)
      js_content = File.read(js_path)
      js_configured = js_content.include?('cccux/application')
      puts "JavaScript:  #{js_configured ? '✅ Configured' : '❌ Not configured'}"
    else
      puts "JavaScript:  ℹ️  No legacy asset pipeline detected"
    end
    
    # Check CSS
    css_path = 'app/assets/stylesheets/application.css'
    if File.exist?(css_path)
      css_content = File.read(css_path)
      css_configured = css_content.include?('cccux/application')
      puts "CSS:         #{css_configured ? '✅ Configured' : '❌ Not configured'}"
    else
      puts "CSS:         ❌ No application.css found"
    end
    
    # Check database
    begin
      if defined?(Cccux::User)
        user_count = Cccux::User.count
        role_count = Cccux::Role.count
        permission_count = Cccux::AbilityPermission.count
        puts "Database:    ✅ Connected (#{user_count} users, #{role_count} roles, #{permission_count} permissions)"
      else
        puts "Database:    ❌ CCCUX models not loaded"
      end
    rescue => e
      puts "Database:    ❌ Error: #{e.message}"
    end
    
    puts ""
    if routes_configured
      puts "🌟 CCCUX appears to be properly configured!"
      puts "   Visit /cccux to access the admin interface"
    else
      puts "⚠️  CCCUX needs configuration. Run: rake cccux:engine_init"
    end
  end

  private

  def check_for_user_model
    # Check if User model exists
    user_model_path = Rails.root.join('app/models/user.rb')
    user_constant_exists = Object.const_defined?('User')
    
    if File.exist?(user_model_path)
      puts "   📁 Found User model at app/models/user.rb"
      return true
    elsif user_constant_exists
      puts "   🔍 Found User constant (defined elsewhere)"
      return true
    else
      return false
    end
  end

  def offer_devise_setup
    puts ""
    puts "🔧 I see your app doesn't have a User model yet."
    puts "   Would you like me to install Devise and create a User model for you?"
    print "   (y/n): "
    
    response = $stdin.gets.chomp.downcase
    return response == 'y' || response == 'yes'
  end

  def setup_devise_and_user
    puts ""
    puts "📦 Installing Devise and creating User model..."
    
    # Add Devise to Gemfile
    gemfile_path = Rails.root.join('Gemfile')
    gemfile_content = File.read(gemfile_path)
    
    unless gemfile_content.include?("gem 'devise'")
      File.write(gemfile_path, gemfile_content + "\ngem 'devise'\n")
      puts "   ✅ Added Devise to Gemfile"
    end
    
    # Install gems
    puts "   📦 Installing gems..."
    system('bundle install')
    
    # Run Devise installation
    puts "   🔧 Running Devise installation..."
    system('rails generate devise:install')
    
    # Generate User model
    puts "   👤 Generating User model..."
    system('rails generate devise User')
    
    # Run migrations
    puts "   📊 Running migrations..."
    system('rails db:migrate')
    
    puts "   ✅ Devise and User model setup complete!"
  end

  def create_default_roles_and_permissions
    # Create default roles
    roles = [
      { name: 'Guest', description: 'Unauthenticated users', priority: 100 },
      { name: 'Basic User', description: 'Standard authenticated users', priority: 50 },
      { name: 'Role Manager', description: 'Can manage roles and permissions', priority: 25 },
      { name: 'Administrator', description: 'Full system access', priority: 1 }
    ]

    roles.each do |role_attrs|
      role = Cccux::Role.find_or_create_by(name: role_attrs[:name]) do |r|
        r.description = role_attrs[:description]
        r.active = true
        r.priority = role_attrs[:priority]
      end
      puts "   ✅ Role: #{role.name}"
    end

    # Create basic permissions for common models
    create_basic_permissions
  end

  def create_basic_permissions
    # Define basic CRUD permissions for common models
    common_models = ['Order', 'Product', 'Article', 'Post']
    basic_actions = ['index', 'show', 'create', 'update', 'destroy']

    common_models.each do |model|
      basic_actions.each do |action|
        permission = Cccux::AbilityPermission.find_or_create_by(
          subject: model,
          action: action
        ) do |p|
          p.description = "#{action.capitalize} #{model.pluralize.downcase}"
          p.active = true
        end
      end
    end

    # Assign permissions to roles
    assign_permissions_to_roles
  end

  def assign_permissions_to_roles
    # Guest role - read only
    guest_role = Cccux::Role.find_by(name: 'Guest')
    if guest_role
      ['Order', 'Product', 'Article'].each do |model|
        ['index', 'show'].each do |action|
          permission = Cccux::AbilityPermission.find_by(subject: model, action: action)
          if permission
            Cccux::RoleAbility.find_or_create_by(role: guest_role, ability_permission: permission) do |ra|
              ra.owned = false
            end
          end
        end
      end
    end

    # Basic User role - full access to own records
    basic_user_role = Cccux::Role.find_by(name: 'Basic User')
    if basic_user_role
      ['Order', 'Product', 'Article'].each do |model|
        ['index', 'show', 'create', 'update', 'destroy'].each do |action|
          permission = Cccux::AbilityPermission.find_by(subject: model, action: action)
          if permission
            Cccux::RoleAbility.find_or_create_by(role: basic_user_role, ability_permission: permission) do |ra|
              ra.owned = true
            end
          end
        end
      end
    end

    # Role Manager - manage roles and permissions
    role_manager_role = Cccux::Role.find_by(name: 'Role Manager')
    if role_manager_role
      ['Cccux::Role', 'Cccux::AbilityPermission', 'Cccux::UserRole', 'Cccux::RoleAbility'].each do |model|
        ['index', 'show', 'create', 'update', 'destroy'].each do |action|
          permission = Cccux::AbilityPermission.find_or_create_by(subject: model, action: action) do |p|
            p.description = "#{action.capitalize} #{model.demodulize.pluralize.downcase}"
            p.active = true
          end
          
          Cccux::RoleAbility.find_or_create_by(role: role_manager_role, ability_permission: permission) do |ra|
            ra.owned = false
          end
        end
      end
    end

    # Administrator - full access to everything
    admin_role = Cccux::Role.find_by(name: 'Administrator')
    if admin_role
      Cccux::AbilityPermission.all.each do |permission|
        Cccux::RoleAbility.find_or_create_by(role: admin_role, ability_permission: permission) do |ra|
          ra.owned = false
        end
      end
    end
  end

  def create_default_admin_user
    begin
      if defined?(User) && User.count == 0
        admin_role = Cccux::Role.find_by(name: 'Administrator')
        
        if admin_role
          puts ""
          puts "🔧 Let's create your first Administrator account:"
          
          # Get email address
          print "   📧 Enter email address: "
          email = $stdin.gets.chomp
          
          while email.blank? || !email.include?('@')
            print "   ❌ Please enter a valid email address: "
            email = $stdin.gets.chomp
          end
          
          # Get first name
          print "   👤 Enter first name: "
          first_name = $stdin.gets.chomp
          
          while first_name.blank?
            print "   ❌ First name cannot be blank: "
            first_name = $stdin.gets.chomp
          end
          
          # Get last name
          print "   👤 Enter last name: "
          last_name = $stdin.gets.chomp
          
          while last_name.blank?
            print "   ❌ Last name cannot be blank: "
            last_name = $stdin.gets.chomp
          end
          
          # Get password
          require 'io/console'
          print "   🔑 Enter password: "
          password = $stdin.noecho(&:gets).chomp
          puts ""  # New line after hidden input
          
          while password.length < 6
            print "   ❌ Password must be at least 6 characters: "
            password = $stdin.noecho(&:gets).chomp
            puts ""
          end
          
          # Confirm password
          print "   🔑 Confirm password: "
          password_confirmation = $stdin.noecho(&:gets).chomp
          puts ""
          
          while password != password_confirmation
            print "   ❌ Passwords don't match. Confirm password: "
            password_confirmation = $stdin.noecho(&:gets).chomp
            puts ""
          end
          
          # Create user
          user = User.create!(
            email: email,
            first_name: first_name,
            last_name: last_name
          )
          
          # Set password (Devise handles encryption)
          user.update!(password: password, password_confirmation: password_confirmation)
          
          # Assign admin role
          Cccux::UserRole.create!(user: user, role: admin_role)
          
          puts "   ✅ Created administrator account: #{email}"
        else
          puts "   ⚠️  No Administrator role found - skipping user creation"
        end
      else
        puts "   ℹ️  Users already exist, skipping default admin creation"
      end
    rescue => e
      puts "   ⚠️  Could not create default admin: #{e.message}"
    end
  end
end
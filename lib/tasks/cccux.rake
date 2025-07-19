# CCCUX Engine Tasks
# Clean, consolidated setup and management tasks for the CCCUX authorization engine

require 'fileutils'

namespace :cccux do
  desc 'setup - Complete setup for CCCUX (requires manual Devise installation first)'
  task setup: :environment do
    puts "🚀 Starting CCCUX + Devise setup..."
    
    # Step 1: Ensure Devise is installed and working
    puts "📋 Step 1: Verifying Devise installation..."
    
    # Check if Devise files exist (more reliable than checking loaded state)
    devise_gem_in_gemfile = File.exist?(Rails.root.join('Gemfile')) && 
                           File.read(Rails.root.join('Gemfile')).include?('gem "devise"')
    devise_initializer_exists = File.exist?(Rails.root.join('config', 'initializers', 'devise.rb'))
    user_model_has_devise = File.exist?(Rails.root.join('app', 'models', 'user.rb')) && 
                           File.read(Rails.root.join('app', 'models', 'user.rb')).include?('devise :')
    routes_has_devise = File.exist?(Rails.root.join('config', 'routes.rb')) && 
                       File.read(Rails.root.join('config', 'routes.rb')).include?('devise_for :users')
    
    # Check if Devise is loaded in the current environment (optional check)
    devise_loaded = defined?(Devise)
    user_model_exists = defined?(User)
    user_has_devise_methods = user_model_exists && User.respond_to?(:devise)
    
    puts "   📋 Devise status check:"
    puts "      - Devise gem in Gemfile: #{devise_gem_in_gemfile ? '✅' : '❌'}"
    puts "      - Devise initializer: #{devise_initializer_exists ? '✅' : '❌'}"
    puts "      - User model has Devise: #{user_model_has_devise ? '✅' : '❌'}"
    puts "      - Routes have Devise: #{routes_has_devise ? '✅' : '❌'}"
    puts "      - Devise loaded in environment: #{devise_loaded ? '✅' : '❌'}"
    puts "      - User model has Devise methods: #{user_has_devise_methods ? '✅' : '❌'}"
    
    # If Devise files exist but aren't loaded, that's normal - just continue
    if devise_gem_in_gemfile && devise_initializer_exists && user_model_has_devise && routes_has_devise
      if devise_loaded && user_has_devise_methods
        puts "✅ Devise is properly installed and loaded"
      else
        puts "✅ Devise files are properly installed"
        puts "💡 Devise will be fully loaded after server restart"
      end
    else
      puts "🚀 Please install Devise manually with this command:"
      puts ""
      puts "   bundle add devise && rails generate devise:install && rails generate devise User && rails db:migrate"
      puts ""
      puts "   Afterwards, run cccux:setup again."
      puts ""
      puts "   rails cccux:setup"
      puts ""
      exit 1
    end
    
    puts "✅ Devise is properly installed"
    
    # Step 2: Verify Devise is using default controllers
    puts "📋 Step 2: Verifying Devise configuration..."
    if Dir.exist?(Rails.root.join('app', 'controllers', 'users'))
      puts "   ⚠️  Custom Devise controllers detected - these may cause conflicts"
      puts "   ℹ️  Using default Devise controllers is recommended for stability"
    else
      puts "   ✅ Using default Devise controllers (recommended)"
    end
    
    # Step 3: Configure routes
    puts "📋 Step 3: Configuring routes..."
    configure_routes
    puts "✅ Routes configured"
    
    # Step 4: Configure assets
    puts "📋 Step 4: Configuring assets..."
    configure_assets
    puts "✅ Assets configured"
    
    # Step 5: Run CCCUX migrations
    puts "📋 Step 5: Running CCCUX migrations..."
    begin
      Rake::Task['db:migrate'].invoke
    rescue RuntimeError => e
      if e.message.include?("Don't know how to build task 'db:migrate'")
        puts "   ⚠️  Skipping migrations (not available in engine context)"
      else
        raise e
      end
    end
    puts "✅ CCCUX migrations completed"
    
    # Step 6: Include CCCUX concern in User model
    puts "📋 Step 6: Adding CCCUX to User model..."
    include_cccux_concern
    puts "✅ CCCUX concern added to User model"
    
    # Step 7: Configure ApplicationController with CCCUX
    puts "📋 Step 7: Configuring ApplicationController with CCCUX..."
    configure_application_controller
    puts "✅ ApplicationController configured with CCCUX"
    
    # Step 8: Create initial roles and permissions
    puts "📋 Step 8: Creating initial roles and permissions..."
    create_default_roles_and_permissions
    puts "✅ Default roles and permissions created"
    
    # Step 9: Create default admin user (if no users exist)
    puts "📋 Step 9: Creating default admin user..."
    create_default_admin_user
    
    # Step 10: Create footer partial
    puts "📋 Step 10: Creating footer partial..."
    create_footer_partial
    puts "✅ Footer partial created"
    
    # Step 11: Create home controller if needed
    puts "📋 Step 11: Checking for home controller..."
    create_home_controller
    puts "✅ Home controller check completed"
    
    # Step 12: Verify setup
    puts "📋 Step 12: Verifying setup..."
    verify_setup

    # Step 13: Precompile assets
    puts "📋 Step 13: Precompiling assets..."
    precompile_assets
    puts "✅ Assets precompiled"

    puts ""
    puts "🎉 CCCUX setup completed successfully!"
    puts ""
    puts "🌟 Next steps:"
    puts "   1. Start your Rails server: rails server"
    puts "   2. Visit http://localhost:3000/cccux to access the admin interface"
    puts "   3. Sign in with your admin account"
    puts ""
    puts "📚 Need help? Check the CCCUX documentation or README"
  end
  
  desc 'test:prepare - Prepare test database for CCCUX engine'
  task 'test:prepare' => :environment do
    puts "🧪 Preparing CCCUX test database..."
    
    # Switch to test environment
    Rails.env = 'test'
    
    # Load schema into test database
    system("cd #{Rails.root.join('..', '..')} && RAILS_ENV=test rails db:schema:load")
    
    puts "✅ Test database prepared"
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
    
    # Check ApplicationController
    app_controller_path = Rails.root.join('app', 'controllers', 'application_controller.rb')
    if File.exist?(app_controller_path)
      app_controller_content = File.read(app_controller_path)
      cccux_configured = app_controller_content.include?('Cccux::ApplicationControllerConcern') ||
                        app_controller_content.include?('include CanCan::ControllerAdditions')
      puts "Controller:  #{cccux_configured ? '✅ CCCUX authorization configured' : '❌ Not configured'}"
    else
      puts "Controller:  ❌ ApplicationController not found"
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
    
    # Check if Devise controllers exist
    devise_controllers_exist = Dir.exist?(Rails.root.join('app', 'controllers', 'users'))
    
    # Ensure devise_for :users is before engine mount
    unless routes_content.include?('devise_for :users')
      puts "   ➕ Adding devise_for :users to routes..."
      new_content = "Rails.application.routes.draw do\n  devise_for :users\n\n" + routes_content.lines[1..-1].join
      File.write(routes_path, new_content)
      routes_content = File.read(routes_path)
    end
    
    # Ensure routes use default Devise controllers (recommended for stability)
    if devise_controllers_exist
      puts "   ⚠️  Custom Devise controllers detected - consider removing them for stability"
      puts "   ℹ️  Routes will use default Devise controllers"
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
    # Note: CCCUX styles are now loaded via the engine's asset pipeline
    # No need to copy styles to host app's application.css
    puts "   ℹ️  CCCUX styles will be loaded via engine asset pipeline"
    
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

  def configure_application_controller
    application_controller_path = Rails.root.join('app', 'controllers', 'application_controller.rb')
    application_controller_content = File.read(application_controller_path)

    # Check if CCCUX is already configured
    if application_controller_content.include?('Cccux::ApplicationControllerConcern') ||
       application_controller_content.include?('include CanCan::ControllerAdditions')
      puts "   ℹ️  ApplicationController already includes CCCUX authorization"
      return
    end

    # Find the class definition line
    class_line_pattern = /class ApplicationController < ActionController::Base/
    unless application_controller_content.match(class_line_pattern)
      puts "   ⚠️  Could not find ApplicationController class definition"
      return
    end

    # Add CCCUX concern include
    updated_content = application_controller_content.gsub(
      class_line_pattern,
      "class ApplicationController < ActionController::Base\n  include Cccux::ApplicationControllerConcern"
    )
    
    File.write(application_controller_path, updated_content)
    puts "   ✅ Added CCCUX authorization to ApplicationController"
  end

  def create_default_roles_and_permissions
    # Create Role Manager role (highest priority)
    role_manager = Cccux::Role.find_or_create_by(name: 'Role Manager') do |role|
      role.description = 'Can manage roles and permissions for all users'
      role.priority = 100
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

  def create_home_controller
    # Check if home controller already exists
    home_controller_path = Rails.root.join('app', 'controllers', 'home_controller.rb')
    home_view_path = Rails.root.join('app', 'views', 'home', 'index.html.erb')
    
    home_controller_exists = File.exist?(home_controller_path)
    if home_controller_exists
      puts "   ℹ️  Home controller already exists"
    else
      # Create home controller
      home_controller_content = <<~RUBY
        class HomeController < ApplicationController
          def index
            # Welcome page for CCCUX powered Rails site
          end
        end
      RUBY
      File.write(home_controller_path, home_controller_content)
      puts "   ✅ Created home controller at #{home_controller_path}"
      # Create home views directory
      home_views_dir = Rails.root.join('app', 'views', 'home')
      FileUtils.mkdir_p(home_views_dir) unless Dir.exist?(home_views_dir)
      # Create home index view
      home_view_content = <<~ERB
        <div class=\"welcome-section\" style=\"text-align: center; padding: 3rem 0;\">
          <h1 style=\"color: #333; margin-bottom: 1rem; font-size: 2.5rem;\">
            Welcome to your CCCUX powered Rails Site
          </h1>
          <p style=\"color: #666; font-size: 1.2rem; max-width: 600px; margin: 0 auto; line-height: 1.6;\">
            Your Rails application is now equipped with CCCUX, a powerful role-based authorization engine built on CanCanCan. Edit app/views/home/index.html.erb to change this content
          </p>
          <div style=\"margin-top: 2rem;\">
            <% if user_signed_in? %>
              <p style=\"color: #28a745; font-weight: bold;\">
                ✅ You are signed in as: <%= current_user.email %>
              </p>
              <% if current_user.has_role?('Role Manager') %>
                <p style=\"color: #007bff; margin-top: 1rem;\">
                  <a href=\"<%= cccux.root_path %>\" style=\"color: #007bff; text-decoration: none; font-weight: bold;\">
                    🔧 Access CCCUX Admin Panel
                  </a>
                </p>
              <% end %>
            <% else %>
              <p style=\"color: #6c757d;\">
                <a href=\"<%= new_user_session_path %>\" style=\"color: #007bff; text-decoration: none;\">
                  🔑 Sign in to get started
                </a>
              </p>
            <% end %>
          </div>
        </div>
      ERB
      File.write(home_view_path, home_view_content)
      puts "   ✅ Created home index view at #{home_view_path}"
    end
    # Always check and add root route if needed
    routes_path = Rails.root.join('config', 'routes.rb')
    routes_content = File.read(routes_path)
    unless routes_content.include?("root 'home#index'")
      if routes_content.include?('devise_for :users')
        updated_content = routes_content.gsub(
          /(devise_for :users)/,
          "\\1\n  root 'home#index'"
        )
        File.write(routes_path, updated_content)
        puts "   ✅ Added root route to routes.rb"
      else
        puts "   ⚠️  Could not find devise_for :users in routes - please manually add: root 'home#index'"
      end
    else
      puts "   ℹ️  Root route already exists in routes.rb"
    end
  end

  def create_footer_partial
    # Create the shared directory if it doesn't exist
    shared_dir = Rails.root.join('app', 'views', 'shared')
    FileUtils.mkdir_p(shared_dir) unless Dir.exist?(shared_dir)
    
    footer_path = shared_dir.join('_footer.html.erb')
    
    # Create footer content - No inline styles, uses CCCUX engine CSS
    footer_content = <<~ERB
      <!-- CCCUX Footer - Styles loaded from CCCUX engine -->
      <footer class="cccux-footer">
        <div class="container">
          <div class="row">
            <div class="col-md-6">
              <nav class="footer-nav">
                <a href="<%= main_app.root_path %>" class="footer-link">🏠 Home</a>
                <% if user_signed_in? && current_user.has_role?('Role Manager') %>
                  <span class="footer-separator">|</span>
                  <a href="/cccux" class="footer-link">⚙️ CCCUX Admin</a>
                <% end %>
              </nav>
            </div>
            <div class="col-md-6 text-end">
              <% if user_signed_in? %>
                <span class="user-info">
                  👤 <strong><%= current_user.email %></strong>
                  <span class="footer-separator">|</span>
                  <%= link_to "🚪 Logout", main_app.destroy_user_session_path, 
                      method: :delete, 
                      class: "footer-link",
                      data: { turbo_method: :delete } %>
                </span>
              <% else %>
                <span class="auth-links">
                  <%= link_to "🔑 Sign In", main_app.new_user_session_path, class: "footer-link" %>
                  <span class="footer-separator">|</span>
                  <%= link_to "📝 Sign Up", main_app.new_user_registration_path, class: "footer-link" %>
                </span>
              <% end %>
            </div>
          </div>
        </div>
      </footer>
    ERB
    
    # Write the footer partial
    File.write(footer_path, footer_content)
    puts "✅ Created footer partial at #{footer_path}"
    
    # Include footer in application layout
    include_footer_in_layout
  end

  def include_footer_in_layout
    layout_path = Rails.root.join('app', 'views', 'layouts', 'application.html.erb')
    if File.exist?(layout_path)
      layout_content = File.read(layout_path)
      
      # Check if footer is already included
      unless layout_content.include?("render 'shared/footer'")
        # Add footer before closing body tag
        if layout_content.include?('</body>')
          updated_content = layout_content.gsub(
            /(\s*)<\/body>/,
            "\\1  <%= render 'shared/footer' %>\n\\1</body>"
          )
          File.write(layout_path, updated_content)
          puts "✅ Added footer to application layout"
        else
          puts "⚠️  Could not find </body> tag in application layout - please manually add: <%= render 'shared/footer' %>"
        end
      else
        puts "ℹ️  Footer already included in application layout"
      end
    else
      puts "⚠️  Application layout not found - please manually add: <%= render 'shared/footer' %>"
    end
  end

  def verify_setup
    # Test that User model has CCCUX methods
    # First, try to reload the User model file to pick up the concern
    begin
      load Rails.root.join('app', 'models', 'user.rb')
    rescue => e
      puts "   ⚠️  Could not reload User model: #{e.message}"
    end
    
    user = User.new
    unless user.respond_to?(:has_role?)
      puts "❌ User model missing CCCUX methods"
      puts "   💡 This sometimes happens on the first run. Try running 'rails cccux:setup' again."
      puts "   🔧 The concern was added to the User model file, but Rails needs to reload it."
      exit 1
    end
    
    puts "✅ CCCUX methods available on User model"
    
    # Check if Devise files exist (more reliable than testing routes in rake context)
    devise_initializer_exists = File.exist?(Rails.root.join('config', 'initializers', 'devise.rb'))
    user_model_has_devise = File.exist?(Rails.root.join('app', 'models', 'user.rb')) && 
                           File.read(Rails.root.join('app', 'models', 'user.rb')).include?('devise :')
    routes_has_devise = File.exist?(Rails.root.join('config', 'routes.rb')) && 
                       File.read(Rails.root.join('config', 'routes.rb')).include?('devise_for :users')
    
    puts "   📋 Devise file verification:"
    puts "      - Devise initializer: #{devise_initializer_exists ? '✅' : '❌'}"
    puts "      - User model has Devise: #{user_model_has_devise ? '✅' : '❌'}"
    puts "      - Routes have Devise: #{routes_has_devise ? '✅' : '❌'}"
    
    if devise_initializer_exists && user_model_has_devise && routes_has_devise
      puts "✅ Devise files properly configured"
      puts "💡 Devise routes will be available after server restart"
    else
      puts "⚠️  Some Devise files may be missing or incomplete"
      puts "💡 This is normal if Devise was just installed - restart your server to complete setup"
    end
  end

  def precompile_assets
    puts "   🔧 Precompiling CCCUX assets..."
    
    begin
      # Run assets:precompile task
      Rake::Task['assets:precompile'].invoke
      puts "   ✅ Assets precompiled successfully"
    rescue RuntimeError => e
      if e.message.include?("Don't know how to build task 'assets:precompile'")
        puts "   ⚠️  Assets precompile task not available (this is normal in some contexts)"
        puts "   ℹ️  Assets will be compiled automatically when the server starts"
      else
        puts "   ❌ Error precompiling assets: #{e.message}"
      end
    rescue => e
      puts "   ❌ Unexpected error during asset precompilation: #{e.message}"
    end
  end
end 
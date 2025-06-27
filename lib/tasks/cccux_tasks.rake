# CCCUX Engine Tasks
# Automated setup and management tasks for the CCCUX authorization engine

require 'fileutils'

namespace :cccux do
  desc 'engine_init - Automated setup for CCCUX authorization engine'
  task engine_init: :environment do
    puts "🚀 Initializing CCCUX Authorization Engine..."
    
    # Check if already initialized
    routes_content = File.read('config/routes.rb')
    if routes_content.include?('##### CCCUX BEGIN #####')
      puts "⚠️  CCCUX already appears to be initialized in routes.rb"
      puts "   Delete the CCCUX section and re-run if you want to reinitialize"
      next
    end
    
    # 1. Add mount line to routes.rb
    puts "📝 Adding CCCUX mount to routes.rb..."
    line = 'Rails.application.routes.draw do'
    text = File.read('config/routes.rb')
    new_contents = text.gsub(
      /(#{Regexp.escape(line)})/mi, 
      "#{line}\n\n  ##### CCCUX BEGIN #####\n  mount Cccux::Engine, at: '/cccux'\n  ##### CCCUX END #####\n"
    )
    File.open('config/routes.rb', "w") { |file| file.puts new_contents }
    
    # 2. Add JavaScript assets
    puts "📦 Adding CCCUX JavaScript assets..."
    js_path = 'app/assets/javascripts/application.js'
    js_import_path = 'app/assets/javascript/application.js'
    
    # Handle both legacy asset pipeline and modern importmap approaches
    if File.exist?(js_path)
      # Legacy asset pipeline
      unless File.directory?('app/assets/javascripts')
        FileUtils.mkdir_p('app/assets/javascripts')
      end
      
      js_content = File.read(js_path)
      unless js_content.include?('cccux/application')
        File.open(js_path, 'a') { |f| f.puts "//= require cccux/application" }
        puts "   ✅ Added to #{js_path}"
      else
        puts "   ℹ️  JavaScript already configured in #{js_path}"
      end
    elsif File.exist?(js_import_path)
      # Modern approach - just inform user
      puts "   ℹ️  Modern JavaScript detected at #{js_import_path}"
      puts "   ℹ️  CCCUX uses engine-scoped assets, no additional JS config needed"
    else
      puts "   ⚠️  No JavaScript application file found - CCCUX will still work"
    end
    
    # 3. Add CSS assets
    puts "🎨 Adding CCCUX CSS assets..."
    css_path = 'app/assets/stylesheets/application.css'
    
    if File.exist?(css_path)
      css_content = File.read(css_path)
      unless css_content.include?('cccux/application')
        File.open(css_path, 'a') { |f| f.puts "/*\n *= require cccux/application\n */" }
        puts "   ✅ Added to #{css_path}"
      else
        puts "   ℹ️  CSS already configured in #{css_path}"
      end
    else
      puts "   ⚠️  No CSS application file found - CCCUX styling may not load"
    end
    
    # 4. Run migrations (engine migrations are automatically available)
    puts "🗄️  Setting up CCCUX database..."
    begin
      Rake::Task['db:migrate'].invoke
      puts "   ✅ Ran database migrations"
    rescue => e
      puts "   ⚠️  Migration error: #{e.message}"
    end
    
    # 5. Run seeds to create roles and permissions
    puts "🌱 Setting up roles and permissions..."
    begin
      # Load seeds from the CCCUX engine
      cccux_seeds_path = File.join(File.dirname(__FILE__), '..', '..', 'db', 'seeds.rb')
      load cccux_seeds_path
      puts "   ✅ Roles and permissions created"
    rescue => e
      puts "   ⚠️  Could not run seeds: #{e.message}"
    end

    # 6. Interactive Role Manager creation
    puts ""
    puts "👤 Creating initial Role Manager..."
    begin
      if defined?(Cccux::User) && Cccux::User.count == 0
        role_manager_role = Cccux::Role.find_by(name: 'Role Manager')
        
        if role_manager_role
          puts ""
          puts "🔧 Let's create your first Role Manager account:"
          
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
            puts "   ❌ Passwords don't match. Try again."
            print "   🔑 Enter password: "
            password = $stdin.noecho(&:gets).chomp
            puts ""
            print "   🔑 Confirm password: "
            password_confirmation = $stdin.noecho(&:gets).chomp
            puts ""
          end
          
          # Create the role manager
          role_manager = Cccux::User.create!(
            email: email,
            first_name: first_name,
            last_name: last_name,
            password: password,
            password_confirmation: password_confirmation,
            active: true,
            notes: 'Initial Role Manager created during setup'
          )
          
          # Assign Role Manager role
          Cccux::UserRole.create!(user: role_manager, role: role_manager_role)
          
          puts ""
          puts "   ✅ Role Manager created successfully!"
          puts "   📧 Email: #{email}"
          puts "   👤 Name: #{first_name} #{last_name}"
          puts "   🎉 You can now login at /cccux/auth/sign_in"
        else
          puts "   ❌ Role Manager role not found. Please run seeds first."
        end
      else
        puts "   ℹ️  Users already exist, skipping Role Manager creation"
      end
    rescue => e
      puts "   ⚠️  Could not create Role Manager: #{e.message}"
    end
    
    # 7. Setup complete
    puts ""
    puts "🎉 CCCUX Authorization Engine setup complete!"
    puts ""
    puts "✅ Engine mounted at /cccux"
    puts "✅ Assets configured"
    puts "✅ Database migrations run"
    puts "✅ Roles and permissions configured"
    puts "✅ Role Manager created (if needed)"
    puts ""
    puts "🌟 Next steps:"
    puts "   1. Start your Rails server: rails server"
    puts "   2. Visit http://localhost:3000/cccux"
    puts "   3. Begin configuring users, roles, and permissions"
    puts ""
    puts "📚 Need help? Check the CCCUX documentation or README"
  end
  
  desc 'reset - Remove CCCUX from host application'
  task reset: :environment do
    puts "🧹 Removing CCCUX from host application..."
    
    # Remove from routes.rb
    routes_content = File.read('config/routes.rb')
    if routes_content.include?('##### CCCUX BEGIN #####')
      new_content = routes_content.gsub(/\n*  ##### CCCUX BEGIN #####.*?##### CCCUX END #####\n*/m, '')
      File.open('config/routes.rb', 'w') { |file| file.puts new_content }
      puts "   ✅ Removed from routes.rb"
    end
    
    # Remove from application.js
    js_path = 'app/assets/javascripts/application.js'
    if File.exist?(js_path)
      js_content = File.read(js_path)
      if js_content.include?('cccux/application')
        new_content = js_content.gsub(/\/\/= require cccux\/application\n?/, '')
        File.open(js_path, 'w') { |file| file.puts new_content }
        puts "   ✅ Removed from #{js_path}"
      end
    end
    
    # Remove from application.css
    css_path = 'app/assets/stylesheets/application.css'
    if File.exist?(css_path)
      css_content = File.read(css_path)
      if css_content.include?('cccux/application')
        new_content = css_content.gsub(/\/\*\n \*= require cccux\/application\n \*\/\n?/, '')
        File.open(css_path, 'w') { |file| file.puts new_content }
        puts "   ✅ Removed from #{css_path}"
      end
    end
    
    puts ""
    puts "🗑️  CCCUX removed from host application configuration"
    puts "   Note: Database tables and migrations were not touched"
    puts "   Run 'rake db:rollback' manually if you want to remove CCCUX tables"
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
end
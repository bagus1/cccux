module Cccux
  class DashboardController < CccuxController
    # Skip CanCanCan resource loading for dashboard since it doesn't work with a specific model
    skip_load_and_authorize_resource
    
    # Ensure only Role Managers can access the dashboard
    before_action :ensure_role_manager
    
    def index
      @user_count = User.count
      @role_count = Cccux::Role.count
      @permission_count = Cccux::AbilityPermission.count
      @total_assignments = Cccux::UserRole.count + (Cccux::Role.joins(:ability_permissions).count)
    end

    def model_discovery
      @detected_models = detect_application_models
      @existing_models = get_models_with_permissions
      @missing_models = @detected_models - @existing_models
      @actions = %w[read create update destroy]
      
    end

    def sync_permissions
      models_to_add = params[:models] || []
      actions = %w[read create update destroy]
      
      added_permissions = []
      
      models_to_add.each do |model_name|
        next if model_name.blank?
        
        actions.each do |action|
          permission = Cccux::AbilityPermission.find_or_create_by(
            action: action,
            subject: model_name
          ) do |p|
            p.description = "#{action.capitalize} #{model_name.pluralize.downcase}"
            p.active = true
          end
          
          if permission.persisted? && !permission.previously_persisted?
            added_permissions << permission
          end
        end
      end
      
      if added_permissions.any?
        redirect_to cccux.model_discovery_path, 
                   notice: "Successfully added #{added_permissions.count} permissions for #{models_to_add.count} models! For each of these models, you'll probably want to add 'load_and_authorize_resource' to the controller."
      else
        redirect_to cccux.model_discovery_path, 
                   alert: "No new permissions were added. Models may already have permissions."
      end
    end

    def clear_model_cache
      clear_model_discovery_cache
      redirect_to cccux.model_discovery_path, 
                 notice: "Model discovery cache cleared! New models should now be visible."
    end
    
    # Handle any unmatched routes in CCCUX - redirect to home
    def not_found
      redirect_to main_app.root_path, alert: 'The requested page was not found.'
    end

    private

    def detect_application_models
      # Use cached results if available
      return @detected_models_cache if @detected_models_cache
      
      # Force Rails to reload constants for better model discovery
      begin
        Rails.application.eager_load! if Rails.application.config.eager_load
      rescue => e
        Rails.logger.warn "Could not eager load: #{e.message}"
      end
      
      # Also try to load models from app/models directory
      begin
        app_models_path = Rails.root.join('app', 'models')
        if Dir.exist?(app_models_path)
          Dir.glob(File.join(app_models_path, '**', '*.rb')).each do |model_file|
            begin
              load model_file unless $LOADED_FEATURES.include?(model_file)
            rescue => e
              Rails.logger.debug "Could not load model file #{model_file}: #{e.message}"
            end
          end
        end
      rescue => e
        Rails.logger.warn "Could not load models from app/models: #{e.message}"
      end
      
      models = []
      
      begin
        # Primary approach: Use Rails' built-in model discovery
        Rails.logger.info "🔍 Using Rails model discovery approach..."
        
        # Get all ApplicationRecord descendants (this includes all models)
        if defined?(ApplicationRecord)
          ApplicationRecord.descendants.each do |model_class|
            next if model_class.abstract_class?
            next if model_class.name.nil?
            next if skip_model_by_name?(model_class.name)
            
            models << model_class.name
            Rails.logger.debug "Found model via ApplicationRecord: #{model_class.name}"
          end
        end
        
        # Fallback: Get all ActiveRecord::Base descendants
        ActiveRecord::Base.descendants.each do |model_class|
          next if model_class.abstract_class?
          next if model_class.name.nil?
          next if skip_model_by_name?(model_class.name)
          next if models.include?(model_class.name) # Avoid duplicates
          
          models << model_class.name
          Rails.logger.debug "Found model via ActiveRecord::Base: #{model_class.name}"
        end
        
        # Secondary approach: Database table discovery for any missing models
        Rails.logger.info "🔍 Using database table discovery as backup..."
        
        application_tables = ActiveRecord::Base.connection.tables.reject do |table|
          # Skip Rails internal tables and CCCUX tables
          table.start_with?('schema_migrations', 'ar_internal_metadata', 'cccux_') ||
          skip_table?(table)
        end
        
        # Discover modules and their table patterns
        module_table_patterns = discover_module_table_patterns
        
        application_tables.each do |table|
          # Convert table name to model name
          model_name = table.singularize.camelize
          
          # Check if this table belongs to a discovered module
          module_name = find_module_for_table(table, module_table_patterns)
          if module_name
            # Extract the model name from the table (e.g., 'pages' from 'mega_bar_pages')
            # Use the module's table prefix to extract the model name
            prefix = module_table_patterns[module_name]
            model_part = table.gsub(prefix, '').singularize.camelize
            model_name = "#{module_name}::#{model_part}"
          end
          
          # Only add if not already found and not skipped
          unless models.include?(model_name) || skip_model_by_name?(model_name)
            # Try to verify the model exists
            begin
              if Object.const_defined?(model_name)
                model_class = Object.const_get(model_name)
                if model_class.respond_to?(:table_name) && model_class.table_name == table
                  models << model_name
                  Rails.logger.debug "Found model via table discovery: #{model_name}"
                end
              else
                # Model constant doesn't exist but table does - likely a valid model
                models << model_name
                Rails.logger.debug "Found potential model via table: #{model_name}"
              end
            rescue => e
              Rails.logger.debug "Error verifying model #{model_name}: #{e.message}"
            end
          end
        end
        
      rescue => e
        Rails.logger.error "Error detecting models: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
      
      # Always include CCCUX engine models for management (but not User since host app owns it)
      cccux_models = %w[Cccux::Role Cccux::AbilityPermission Cccux::UserRole Cccux::RoleAbility]
      models += cccux_models
      
      # Debug what we found
      Rails.logger.info "Model detection summary:"
      Rails.logger.info "  Total models found: #{models.uniq.count}"
      Rails.logger.info "  Application models: #{models.reject { |m| m.start_with?('Cccux::') }.join(', ')}"
      Rails.logger.info "  CCCUX models: #{models.select { |m| m.start_with?('Cccux::') }.join(', ')}"
      
      # Cache the results
      @detected_models_cache = models.uniq.sort
      @detected_models_cache
    end

    def discover_module_table_patterns
      # Use cached results if available
      return @module_table_patterns_cache if @module_table_patterns_cache
      
      patterns = {}
      
      # Skip Rails internal engines and third-party gems
      skip_engines = %w[
        Rails ActionView SolidCache Stimulus Turbo Importmap ActiveStorage 
        ActionCable ActionMailbox BestInPlace SolidCable SolidQueue ActionText 
        Devise Kaminari Mega132
      ]
      
      # Find Rails engines by looking for Engine classes
      ObjectSpace.each_object(Class) do |klass|
        next unless klass < Rails::Engine
        next if klass == Rails::Engine # Skip the base class
        
        # Extract module name from engine class (e.g., MegaBar::Engine -> MegaBar)
        module_name = klass.name.split('::').first
        next if skip_engines.include?(module_name) # Skip unwanted engines
        
        # Convert module name to expected table prefix
        table_prefix = module_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, '') + '_'
        patterns[module_name] = table_prefix
        Rails.logger.info "Discovered engine: #{module_name} with table prefix: #{table_prefix}"
      end
      
      Rails.logger.info "Module table patterns: #{patterns}"
      
      # Cache the results
      @module_table_patterns_cache = patterns
      @module_table_patterns_cache
    end
    
    def find_table_prefix_for_module(module_name)
      begin
        # Look for models in this module
        module_const = Object.const_get(module_name)
        
        # Find the first model in this module to determine the table prefix
        module_const.constants.each do |const|
          const_obj = module_const.const_get(const)
          if const_obj.is_a?(Class) && const_obj < ActiveRecord::Base && const_obj != ActiveRecord::Base
            table_name = const_obj.table_name
            # Convert camelCase to snake_case for the prefix
            expected_prefix = module_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, '') + '_'
            if table_name.start_with?(expected_prefix)
              Rails.logger.debug "Found table prefix for #{module_name}: #{expected_prefix}"
              return expected_prefix
            end
          end
        end
      rescue => e
        Rails.logger.debug "Could not find table prefix for module #{module_name}: #{e.message}"
      end
      
      nil
    end
    
    def find_table_prefix_for_engine(engine_class)
      begin
        # Get the module name from the engine class
        module_name = engine_class.name.split('::').first
        
        # Look for models in this module
        module_const = Object.const_get(module_name)
        
        # Find the first model in this module to determine the table prefix
        module_const.constants.each do |const|
          const_obj = module_const.const_get(const)
          if const_obj.is_a?(Class) && const_obj < ActiveRecord::Base && const_obj != ActiveRecord::Base
            table_name = const_obj.table_name
            # Convert camelCase to snake_case for the prefix
            expected_prefix = module_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, '') + '_'
            if table_name.start_with?(expected_prefix)
              Rails.logger.debug "Found table prefix for engine #{module_name}: #{expected_prefix}"
              return expected_prefix
            end
          end
        end
      rescue => e
        Rails.logger.debug "Could not find table prefix for engine #{engine_class.name}: #{e.message}"
      end
      
      nil
    end

    def find_module_for_table(table_name, module_patterns)
      module_patterns.each do |module_name, prefix|
        if table_name.start_with?(prefix)
          return module_name
        end
      end
      
      nil
    end

    def get_models_with_permissions
      Cccux::AbilityPermission.distinct.pluck(:subject).compact.sort
    end

    def skip_model?(model_class)
      skip_model_by_name?(model_class.name)
    end
    
    def skip_model_by_name?(model_name)
      # Skip models that shouldn't have permissions
      excluded_patterns = [
        /^ActiveRecord::/,
        /^ActiveStorage::/,
        /^ActionText::/,
        /^ActionMailbox::/,
        /^ApplicationRecord$/,
        /Version$/, # PaperTrail versions
        /Schema/,
        /Migration/
      ]
      
      # Don't skip any namespaced models (they should be discoverable)
      return false if model_name.include?('::')
      
      excluded_patterns.any? { |pattern| model_name.match?(pattern) }
    end
    
    def skip_table?(table_name)
      # Skip tables that are not meant to have corresponding models
      excluded_tables = [
        'active_storage_blobs',
        'active_storage_attachments',
        'active_storage_variant_records',
        'action_text_rich_texts',
        'action_mailbox_inbound_emails',
        'versions' # PaperTrail
      ]
      
      # Don't skip any module-prefixed tables (they should be discoverable)
      # This will be handled by the module discovery logic
      return false if table_name.include?('_') && !excluded_tables.include?(table_name)
      
      excluded_tables.include?(table_name) ||
      table_name.end_with?('_versions') # PaperTrail version tables
    end

    def clear_model_discovery_cache
      @detected_models_cache = nil
      @module_table_patterns_cache = nil
      Rails.logger.info "🔄 Model discovery cache cleared"
    end
  end
end
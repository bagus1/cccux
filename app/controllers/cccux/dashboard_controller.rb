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
                   notice: "Successfully added #{added_permissions.count} permissions for #{models_to_add.count} models!"
      else
        redirect_to cccux.model_discovery_path, 
                   alert: "No new permissions were added. Models may already have permissions."
      end
    end
    
    # Handle any unmatched routes in CCCUX - redirect to home
    def not_found
      redirect_to main_app.root_path, alert: 'The requested page was not found.'
    end

    private

    def detect_application_models
      models = []
      
      begin
        # Direct approach: Get models from database tables (bypasses all autoloading issues)
        
        application_tables = ActiveRecord::Base.connection.tables.reject do |table|
          # Skip Rails internal tables and CCCUX tables
          table.start_with?('schema_migrations', 'ar_internal_metadata', 'cccux_') ||
          skip_table?(table)
        end
        
        
        application_tables.each do |table|
          # Convert table name to model name
          model_name = table.singularize.camelize
          
          # Verify the model exists and is valid
          begin
            if Object.const_defined?(model_name)
              model_class = Object.const_get(model_name)
              if model_class.respond_to?(:table_name) && 
                 model_class.table_name == table &&
                 !skip_model_by_name?(model_name)
                models << model_name
              end
            else
              # Model constant doesn't exist yet, but table does - likely a valid model
              unless skip_model_by_name?(model_name)
                models << model_name
              end
            end
          rescue => e
          end
        end
        
      rescue => e
        Rails.logger.error "Error detecting models from database: #{e.message}"
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
      
      models.uniq.sort
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
      
      excluded_tables.include?(table_name) ||
      table_name.end_with?('_versions') # PaperTrail version tables
    end
  end
end
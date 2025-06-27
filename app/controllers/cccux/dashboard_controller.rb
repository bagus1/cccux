module Cccux
  class DashboardController < BaseController
    def index
      @user_count = Cccux::User.count
      @role_count = Cccux::Role.count
      @permission_count = Cccux::AbilityPermission.count
      @total_assignments = Cccux::UserRole.count + (Cccux::Role.joins(:ability_permissions).count)
    end

    def model_discovery
      @detected_models = detect_application_models
      @existing_models = get_models_with_permissions
      @missing_models = @detected_models - @existing_models
      @actions = %w[read create update destroy]
      
      # Debug logging
      Rails.logger.info "DEBUG: Detected models: #{@detected_models.inspect}"
      Rails.logger.info "DEBUG: Existing models: #{@existing_models.inspect}"
      Rails.logger.info "DEBUG: Missing models: #{@missing_models.inspect}"
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

    private

    def detect_application_models
      models = []
      
      begin
        # Load all models to ensure they're discovered
        Rails.application.eager_load!
        
        # Get all classes that inherit from ApplicationRecord (host app models)
        ApplicationRecord.descendants.each do |model_class|
          # Skip abstract classes and problematic models
          next if model_class.abstract_class?
          next if model_class.name.nil?
          next if skip_model?(model_class)
          
          models << model_class.name
        end
        
        # If ApplicationRecord.descendants didn't find anything, try alternative methods
        if models.empty?
          # Try to find models by scanning the models directory
          model_files = Dir[Rails.application.root.join('app/models/**/*.rb')]
          model_files.each do |file|
            model_name = File.basename(file, '.rb').camelize
            next if model_name == 'ApplicationRecord'
            
            begin
              if Object.const_defined?(model_name)
                model_class = Object.const_get(model_name)
                if model_class.respond_to?(:ancestors) && model_class.ancestors.include?(ApplicationRecord)
                  models << model_name unless skip_model_by_name?(model_name)
                end
              end
            rescue => e
              # Skip problematic models
            end
          end
        end
        
        # Also include some common models that might exist
        potential_models = %w[Order Product User Customer Item]
        potential_models.each do |model_name|
          begin
            if Object.const_defined?(model_name) && Object.const_get(model_name) < ApplicationRecord
              models << model_name unless models.include?(model_name)
            end
          rescue => e
            # Model doesn't exist or can't be loaded, skip it
          end
        end
        
      rescue => e
        Rails.logger.error "Error detecting models: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
      
      # Also add CCCUX engine models (so they can be managed through permissions)
      cccux_models = %w[Cccux::User Cccux::Role Cccux::AbilityPermission Cccux::UserRole Cccux::RoleAbility]
      models += cccux_models
      
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
  end
end
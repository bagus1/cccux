module Cccux
  class AbilityPermissionsController < CccuxController

    before_action :set_ability_permission, only: [:show, :edit, :update, :destroy]

    def index
      @ability_permissions = Cccux::AbilityPermission.all.order(:subject, :action)
      @grouped_permissions = @ability_permissions.group_by(&:subject)
    end

    def show
    end

    def new
      @ability_permission = Cccux::AbilityPermission.new
      @ability_permission.subject = params[:subject] if params[:subject].present?
      @available_subjects = get_available_subjects
      @available_actions = get_available_actions
      @subject_actions_map = get_subject_actions_map
    end

    def create
      # Handle bulk creation if actions is an array
      if params[:ability_permission][:actions].is_a?(Array)
        create_bulk_permissions
      else
        create_single_permission
      end
    end

    def edit
      @available_subjects = get_available_subjects
      @available_actions = get_available_actions
      @subject_actions_map = get_subject_actions_map
    end

    def update
      if @ability_permission.update(ability_permission_params)
        redirect_to cccux.ability_permissions_path, notice: 'Permission was successfully updated.'
      else
        @available_subjects = get_available_subjects
        @available_actions = get_available_actions
        @subject_actions_map = get_subject_actions_map
        render :edit
      end
    end

    def destroy
      @ability_permission.destroy
      redirect_to cccux.ability_permissions_path, notice: 'Permission was successfully deleted.'
    end

    def actions_for_subject
      subject = params[:subject]
      actions = get_actions_for_subject(subject)
      render json: { actions: actions }
    end

    private

    def set_ability_permission
      @ability_permission = Cccux::AbilityPermission.find(params[:id])
    end

    def ability_permission_params
      params.require(:ability_permission).permit(:subject, :action, :description, :active)
    end

    def bulk_permission_params
      params.require(:ability_permission).permit(:subject, :description, :active, actions: [])
    end

    def create_bulk_permissions
      subject = params[:ability_permission][:subject]
      actions = params[:ability_permission][:actions].reject(&:blank?)
      description_template = params[:ability_permission][:description]
      active = params[:ability_permission][:active]
      
      created_permissions = []
      failed_permissions = []
      
      actions.each do |action|
        permission = Cccux::AbilityPermission.new(
          subject: subject,
          action: action,
          description: description_template.present? ? "#{action.capitalize} #{subject.pluralize.downcase}" : "",
          active: active
        )
        
        if permission.save
          created_permissions << permission
        else
          failed_permissions << { action: action, errors: permission.errors.full_messages }
        end
      end
      
      if failed_permissions.empty?
        redirect_to cccux.ability_permissions_path, 
                    notice: "Successfully created #{created_permissions.count} permissions for #{subject}!"
      else
        @ability_permission = Cccux::AbilityPermission.new(subject: subject)
        @available_subjects = get_available_subjects
        @available_actions = get_available_actions
        @subject_actions_map = get_subject_actions_map
        flash[:alert] = "Some permissions could not be created: #{failed_permissions.map { |f| f[:action] }.join(', ')}"
        render :new
      end
    end

    def create_single_permission
      @ability_permission = Cccux::AbilityPermission.new(ability_permission_params)
      
      unless @ability_permission.save
        raise "AbilityPermission creation failed: \n#{@ability_permission.errors.full_messages.join(', ')}"
      end
      redirect_to cccux.ability_permissions_path, notice: 'Permission was successfully created.'
    end

    def get_available_subjects
      # Get existing subjects plus discovered models
      existing_subjects = Cccux::AbilityPermission.distinct.pluck(:subject).compact
      discovered_models = discover_application_models
      (existing_subjects + discovered_models).uniq.sort
    end

    def get_available_actions
      # Get existing actions plus common CRUD actions
      existing_actions = Cccux::AbilityPermission.distinct.pluck(:action).compact
      common_actions = %w[read create update destroy manage index show new edit]
      (existing_actions + common_actions).uniq.sort
    end

    def get_subject_actions_map
      subjects = get_available_subjects
      map = {}
      
      subjects.each do |subject|
        map[subject] = get_actions_for_subject(subject)
      end
      
      map
    end

    def get_actions_for_subject(subject)
      return [] if subject.blank?
      
      # Start with common CRUD actions
      actions = %w[read create update destroy]
      
      # Add route-discovered actions
      route_actions = discover_actions_for_model(subject)
      Rails.logger.debug "Route actions for #{subject}: #{route_actions}"
      actions += route_actions
      # Add module-specific custom actions
      if subject.include?('::')
        module_name = subject.split('::').first
        model_name = subject.split('::').last
        
        # Discover custom actions for this module's controllers
        custom_actions = discover_custom_actions_for_module(module_name, model_name)
        actions += custom_actions
        Rails.logger.debug "Added #{module_name} custom actions: #{custom_actions}"
      end
      
      # Add existing actions for this subject
      existing_actions = Cccux::AbilityPermission.where(subject: subject).distinct.pluck(:action).compact
      actions += existing_actions
      
      final_actions = actions.uniq.sort
      Rails.logger.debug "Final actions for #{subject}: #{final_actions}"
      final_actions
    end

    def discover_application_models
      models = []
      
      begin
        Rails.application.eager_load!
        
        # Get all ApplicationRecord descendants from the host app
        ApplicationRecord.descendants.each do |model_class|
          next if model_class.abstract_class?
          next if model_class.name.nil?
          next if skip_model?(model_class)
          
          models << model_class.name
        end
        
        # Also add CCCUX engine models (so they can be managed through permissions)
        cccux_models = %w[Cccux::Role Cccux::AbilityPermission Cccux::UserRole Cccux::RoleAbility]
        models += cccux_models
        
      rescue => e
        Rails.logger.warn "Error discovering models: #{e.message}"
      end
      
      models.uniq.sort
    end

    def discover_actions_for_model(subject)
      actions = []
      
      begin
        Rails.logger.debug "Discovering actions for subject: #{subject}"
        
        # Handle namespaced models (e.g., MegaBar::Page)
        if subject.include?('::')
          module_name = subject.split('::').first
          model_name = subject.split('::').last.underscore.pluralize
          controller_pattern = "#{module_name.underscore}/#{model_name}"
          
          Rails.logger.debug "Namespaced model detected. Looking for controller: #{controller_pattern}"
          
          # Try to find the engine for this module
          engine_class = "#{module_name}::Engine".constantize rescue nil
          
          if engine_class
            Rails.logger.debug "Found engine: #{engine_class}"
            
            # Look through engine routes for this namespaced controller
            engine_class.routes.routes.each do |route|
              controller_name = route.defaults[:controller]
              next unless controller_name&.start_with?("#{module_name.underscore}/")
              next unless route.defaults[:action]
              
              action = route.defaults[:action]
              Rails.logger.debug "Found #{module_name} engine route: #{controller_name}##{action}"
              
              # Map HTTP verbs to standard actions and include custom actions
              case action
              when 'index' then actions << 'read'
              when 'show' then actions << 'read'
              when 'create' then actions << 'create'
              when 'update' then actions << 'update'
              when 'destroy' then actions << 'destroy'
              when 'edit', 'new' then next # Skip these as they're UI actions
              else
                # Custom actions like 'move', 'administer_page', etc.
                actions << action
              end
            end
          else
            Rails.logger.debug "No engine found for #{module_name}, checking main routes"
            
            # Fallback to main Rails routes
            Rails.application.routes.routes.each do |route|
              controller_name = route.defaults[:controller]
              next unless controller_name&.start_with?("#{module_name.underscore}/")
              next unless route.defaults[:action]
              
              action = route.defaults[:action]
              Rails.logger.debug "Found #{module_name} route: #{controller_name}##{action}"
              
              # Map HTTP verbs to standard actions and include custom actions
              case action
              when 'index' then actions << 'read'
              when 'show' then actions << 'read'
              when 'create' then actions << 'create'
              when 'update' then actions << 'update'
              when 'destroy' then actions << 'destroy'
              when 'edit', 'new' then next # Skip these as they're UI actions
              else
                # Custom actions like 'move', 'administer_page', etc.
                actions << action
              end
            end
          end
          
        # Handle CCCUX models
        elsif subject.start_with?('Cccux::')
          cccux_resource_name = subject.gsub('Cccux::', '').underscore.pluralize
          
          # Look through CCCUX engine routes for this resource
          Cccux::Engine.routes.routes.each do |route|
            next unless route.path.spec.to_s.include?(cccux_resource_name)
            
            # Extract action from route
            if route.defaults[:action]
              action = route.defaults[:action]
              # Map HTTP verbs to standard actions and include custom actions
              case action
              when 'index' then actions << 'read'
              when 'show' then actions << 'read'
              when 'create' then actions << 'create'
              when 'update' then actions << 'update'
              when 'destroy' then actions << 'destroy'
              when 'edit', 'new' then next # Skip these as they're UI actions
              else
                # Custom actions like 'reorder', 'toggle_active', etc.
                actions << action
              end
            end
          end
          
        # Handle regular models
        else
          resource_name = subject.underscore.pluralize
          Rails.logger.debug "Regular model detected. Resource name: #{resource_name}"
          
          # Look through main Rails routes for this resource
          Rails.application.routes.routes.each do |route|
            next unless route.path.spec.to_s.include?(resource_name)
            
            # Extract action from route
            if route.defaults[:action]
              action = route.defaults[:action]
              # Map HTTP verbs to standard actions and include custom actions
              case action
              when 'index' then actions << 'read'
              when 'show' then actions << 'read'
              when 'create' then actions << 'create'
              when 'update' then actions << 'update'
              when 'destroy' then actions << 'destroy'
              when 'edit', 'new' then next # Skip these as they're UI actions
              else
                # Custom actions
                actions << action
              end
            end
          end
        end
        
      rescue => e
        Rails.logger.warn "Error discovering actions for #{subject}: #{e.message}"
      end
      
      actions.uniq
    end

    def discover_custom_actions_for_module(module_name, model_name)
      custom_actions = []
      
      begin
        # Convert model name to controller name pattern
        controller_name = "#{module_name.downcase}/#{model_name.underscore.pluralize}"
        
        Rails.logger.debug "Looking for custom actions in controller: #{controller_name}"
        
        # Look through Rails routes for this module's controllers
        Rails.application.routes.routes.each do |route|
          next unless route.defaults[:controller]&.start_with?("#{module_name.downcase}/")
          next unless route.defaults[:action]
          
          action = route.defaults[:action]
          
          # Skip standard CRUD actions and UI actions
          next if %w[index show create update destroy new edit].include?(action)
          
          # Include custom actions
          custom_actions << action
          Rails.logger.debug "Found custom action: #{action} in #{route.defaults[:controller]}"
        end
        
      rescue => e
        Rails.logger.warn "Error discovering custom actions for #{module_name}::#{model_name}: #{e.message}"
      end
      
      custom_actions.uniq
    end

    def skip_model?(model_class)
      excluded_patterns = [
        /^ActiveRecord::/,
        /^ActiveStorage::/,
        /^ActionText::/,
        /^ActionMailbox::/,
        /^ApplicationRecord$/,
        /Version$/,
        /Schema/,
        /Migration/
      ]
      
      excluded_patterns.any? { |pattern| model_class.name.match?(pattern) }
    end
  end
end

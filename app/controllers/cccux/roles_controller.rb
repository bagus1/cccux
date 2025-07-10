module Cccux
  class RolesController < CccuxController
    # Skip authorization for model_columns since it's just a helper endpoint
    skip_authorization_check only: [:model_columns]

    # Add load_and_authorize_resource to automatically load roles
    load_and_authorize_resource class: Cccux::Role

    # Remove manual set_role - let load_and_authorize_resource handle it
    # before_action :set_role, only: [:show, :edit, :update, :destroy]
    
    def index
      @roles = Cccux::Role.includes(:ability_permissions, :users)
                         .order(:priority, :name)
    end
    
    def show
      @permission_matrix = build_permission_matrix
      @users_with_role = @role.users
    end
    
    def new
      @role = Cccux::Role.new(priority: 50)
    end
    
    def create
      @role = Cccux::Role.new(role_params)
      
      respond_to do |format|
        format.html { redirect_to cccux.role_path(@role), notice: 'Role was successfully created.' } if @role.save
        if defined?(Turbo::StreamsChannel) && @role.save
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update("new_role_form", ""),
              turbo_stream.append("roles_list", partial: "role", locals: { role: @role }),
              turbo_stream.update("flash", partial: "flash", locals: { notice: "Role was successfully created." })
            ]
          end
        end
        unless @role.save
          format.html { render :new, status: :unprocessable_entity }
          if defined?(Turbo::StreamsChannel)
            format.turbo_stream do
              render turbo_stream: turbo_stream.update("new_role_form", 
                partial: "form", locals: { role: @role })
            end
          end
        end
      end
    end
    
    def edit
      @permission_matrix = build_permission_matrix
      @available_permissions = Cccux::AbilityPermission.all.group_by(&:subject)
      @available_ownership_models = discover_application_models
    end
    
    def update
      @available_ownership_models = discover_application_models
      if @role.update(role_params)
        update_permissions
        redirect_to cccux.roles_path, notice: 'Role was successfully updated.'
      else
        @permission_matrix = build_permission_matrix
        @available_permissions = Cccux::AbilityPermission.all.group_by(&:subject)
        render :edit, status: :unprocessable_entity
      end
    end
    
    def destroy
      respond_to do |format|
        if @role.users.any?
          if defined?(Turbo::StreamsChannel)
            format.turbo_stream do
              render turbo_stream: turbo_stream.update("flash", 
                partial: "flash", locals: { alert: "Cannot delete role that has users assigned to it." })
            end
          end
          format.html { redirect_to cccux.roles_path, alert: 'Cannot delete role that has users assigned to it.' }
        else
          @role.destroy
          if defined?(Turbo::StreamsChannel)
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.remove("role_#{@role.id}"),
                turbo_stream.update("flash", partial: "flash", locals: { notice: "Role was successfully deleted." })
              ]
            end
          end
          format.html { redirect_to cccux.roles_path, notice: 'Role was successfully deleted.' }
        end
      end
    end
    
    def permissions
      @permission_matrix = build_permission_matrix
    end
    
    def reorder
      role_ids = params[:role_ids]
      
      if role_ids.present?
        # Update priorities based on order (first item gets priority 1, second gets 10, etc.)
        role_ids.each_with_index do |role_id, index|
          role = Cccux::Role.find(role_id)
          new_priority = (index + 1) * 10  # 10, 20, 30, 40, etc.
          role.update!(priority: new_priority)
        end
        
        render json: { success: true, message: 'Role priorities updated successfully' }
      else
        render json: { success: false, error: 'No role order provided' }, status: :bad_request
      end
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
    
    def model_columns
      model_name = params[:model]
      Rails.logger.info "CCCUX: Fetching columns for model: #{model_name}"
      
      begin
        model_class = model_name.constantize
        columns = model_class.column_names
        Rails.logger.info "CCCUX: Found columns for #{model_name}: #{columns.inspect}"
        render json: { columns: columns }
      rescue NameError => e
        Rails.logger.warn "CCCUX: Model not found: #{model_name}"
        render json: { columns: [], error: "Model '#{model_name}' not found" }, status: 422
      rescue => e
        Rails.logger.error "CCCUX: Error fetching columns for #{model_name}: #{e.message}"
        render json: { columns: [], error: e.message }, status: 422
      end
    end
    
    private
    
    # Remove set_role method - load_and_authorize_resource handles this
    # def set_role
    #   @role = Cccux::Role.find(params[:id])
    # end
    
    def build_permission_matrix
      subjects = Cccux::AbilityPermission.distinct.pluck(:subject).sort
      actions = Cccux::AbilityPermission.distinct.pluck(:action).sort
      
      matrix = {}
      subjects.each do |subject|
        matrix[subject] = {}
        actions.each do |action|
          permission = Cccux::AbilityPermission.find_by(action: action, subject: subject)
          matrix[subject][action] = {
            permission: permission,
            granted: permission && @role.ability_permissions.include?(permission)
          }
        end
      end
      matrix
    end
    
    def update_permissions
      permission_ids = params[:role][:ability_permission_ids] || []
      permission_access_type = params[:role][:permission_access_type] || {}
      ownership_source = params[:role][:ownership_source] || {}
      ownership_foreign_key = params[:role][:ownership_foreign_key] || {}
      ownership_user_key = params[:role][:ownership_user_key] || {}
      
      # Get selected permissions
      selected_permissions = Cccux::AbilityPermission.where(id: permission_ids)
      
      # Remove permissions that are no longer selected
      @role.role_abilities.where.not(ability_permission: selected_permissions).destroy_all
      
      # Update or create role abilities with access type settings
      selected_permissions.each do |permission|
        # Determine access type for this specific permission
        # Default to 'global' for backward compatibility
        access_type = permission_access_type[permission.id.to_s] || 'global'
        
        # Convert access_type to owned/context attributes
        case access_type
        when 'owned'
          is_owned = true
          context_value = 'owned'
        else # 'global'
          is_owned = false
          context_value = 'global'
        end
        
        # Find existing role ability or create new one
        role_ability = @role.role_abilities.find_or_initialize_by(ability_permission: permission)
        role_ability.owned = is_owned
        role_ability.context = context_value
        
        # Handle ownership configuration for 'owned' access type
        if access_type == 'owned'
          # Set ownership source if provided
          if ownership_source[permission.id.to_s].present?
            role_ability.ownership_source = ownership_source[permission.id.to_s]
          else
            role_ability.ownership_source = nil
          end
          
          # Build ownership conditions JSON
          conditions = {}
          if ownership_foreign_key[permission.id.to_s].present?
            conditions["foreign_key"] = ownership_foreign_key[permission.id.to_s]
          end
          if ownership_user_key[permission.id.to_s].present?
            conditions["user_key"] = ownership_user_key[permission.id.to_s]
          end
          
          role_ability.ownership_conditions = conditions.to_json if conditions.any?
        end
        
        role_ability.save!
      end
    end
    
    def role_params
      params.require(:role).permit(:name, :description, :active, :priority)
    end
    
    def discover_application_models
      models = []
      
      # Get all ActiveRecord models from the application
      ActiveRecord::Base.descendants.each do |model|
        model_name = model.name
        
        # Skip if model should be excluded
        next if skip_model_by_name?(model_name)
        
        # Skip if table doesn't exist or should be excluded
        table_name = model.table_name
        next if table_name.blank? || skip_table?(table_name)
        
        models << {
          name: model_name,
          table_name: table_name,
          columns: model.column_names
        }
      end
      
      # Sort by name for consistency
      models.sort_by { |model| model[:name] }
    end
    
    def skip_model_by_name?(model_name)
      excluded_patterns = [
        /^HABTM_/,           # Has and belongs to many join tables
        /^ActiveRecord::/,    # ActiveRecord internal classes
        /^ActionText::/,      # ActionText models
        /^ActiveStorage::/,   # ActiveStorage models
        /^ActionMailbox::/,   # ActionMailbox models
        /^Cccux::/,          # CCCUX engine models (we'll handle these separately)
        /^ApplicationRecord$/, # Base application record
        /^ApplicationController$/, # Controllers
        /^ApplicationHelper$/,    # Helpers
        /^ApplicationMailer$/     # Mailers
      ]
      
      excluded_patterns.any? { |pattern| model_name.match?(pattern) }
    end
    
    def skip_table?(table_name)
      excluded_tables = [
        'schema_migrations',
        'ar_internal_metadata',
        'active_storage_blobs',
        'active_storage_attachments',
        'action_text_rich_texts',
        'action_mailbox_inbound_emails',
        'action_mailbox_routing_rules'
      ]
      
      excluded_tables.include?(table_name) || table_name.start_with?('active_storage_') || table_name.start_with?('action_text_')
    end
  end
end
module Cccux
  class RolesController < CccuxController
    # Ensure only Role Managers can access role management
    before_action :ensure_role_manager
    # Skip authorization for model_columns since it's just a helper endpoint
    skip_authorization_check only: [:model_columns]

    before_action :set_role, only: [:show, :edit, :update, :destroy]
    
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
        if @role.save
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update("new_role_form", ""),
              turbo_stream.append("roles_list", partial: "role", locals: { role: @role }),
              turbo_stream.update("flash", partial: "flash", locals: { notice: "Role was successfully created." })
            ]
          end
          format.html { redirect_to cccux.role_path(@role), notice: 'Role was successfully created.' }
        else
          format.turbo_stream do
            render turbo_stream: turbo_stream.update("new_role_form", 
              partial: "form", locals: { role: @role })
          end
          format.html { render :new, status: :unprocessable_entity }
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
          format.turbo_stream do
            render turbo_stream: turbo_stream.update("flash", 
              partial: "flash", locals: { alert: "Cannot delete role that has users assigned to it." })
          end
          format.html { redirect_to cccux.roles_path, alert: 'Cannot delete role that has users assigned to it.' }
        else
          @role.destroy
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove("role_#{@role.id}"),
              turbo_stream.update("flash", partial: "flash", locals: { notice: "Role was successfully deleted." })
            ]
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
    
    def set_role
      @role = Cccux::Role.find(params[:id])
    end
    
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
          context_value = 'global' # context doesn't matter when owned=true
        when 'contextual'
          is_owned = false
          context_value = 'scoped'
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
          
          if conditions.any?
            role_ability.ownership_conditions = conditions.to_json
          else
            role_ability.ownership_conditions = nil
          end
        else
          # Clear ownership configuration for non-owned access types
          role_ability.ownership_source = nil
          role_ability.ownership_conditions = nil
        end
        
        role_ability.save!
      end
    end
    
    def role_params
      params.require(:role).permit(:name, :description, :active, :priority)
    end

    def discover_application_models
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
            # Ignore
          end
        end
        # Always include CCCUX engine models for management (but not User since host app owns it)
        cccux_models = %w[Cccux::Role Cccux::AbilityPermission Cccux::UserRole Cccux::RoleAbility]
        models += cccux_models
      rescue => e
        Rails.logger.warn "Error discovering models: #{e.message}"
        Rails.logger.warn e.backtrace.join("\n")
      end
      models.uniq.sort
    end

    def skip_model_by_name?(model_name)
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
      excluded_patterns.any? { |pattern| model_name.match?(pattern) }
    end

    def skip_table?(table_name)
      excluded_tables = [
        'active_storage_blobs',
        'active_storage_attachments',
        'active_storage_variant_records',
        'action_text_rich_texts',
        'action_mailbox_inbound_emails',
        'versions'
      ]
      excluded_tables.include?(table_name) ||
      table_name.end_with?('_versions')
    end
  end
end
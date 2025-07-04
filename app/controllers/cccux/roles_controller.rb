module Cccux
  class RolesController < CccuxController
    # Ensure only Role Managers can access role management
    before_action :ensure_role_manager

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
    end
    
    def update
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
      permission_owned = params[:role][:permission_owned] || {}
      
      # Clear existing role abilities
      @role.role_abilities.destroy_all
      
      # Get selected permissions
      selected_permissions = Cccux::AbilityPermission.where(id: permission_ids)
      
      # Create role abilities with individual ownership settings
      selected_permissions.each do |permission|
        # Determine ownership setting for this specific permission
        # Default to false (all records) for CCCUX models, or based on form input
        is_owned = if permission.subject.start_with?('Cccux::')
          false # CCCUX models always have access to all records
        else
          permission_owned[permission.id.to_s] == 'true'
        end
        
        @role.role_abilities.create!(
          ability_permission: permission,
          owned: is_owned
        )
      end
    end
    
    def role_params
      params.require(:role).permit(:name, :description, :active, :priority)
    end
  end
end
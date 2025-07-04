module Cccux
  class RolesController < CccuxController
    # Ensure only Role Managers can access role management
    before_action :ensure_role_manager

    before_action :set_role, only: [:show, :edit, :update, :destroy]
    
    def index
      @roles = Cccux::Role.includes(:ability_permissions, :users)
                         .order(Arel.sql("CASE WHEN name = 'Role Manager' THEN 0 ELSE 1 END, name"))
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
      ownership_scopes = params[:role][:ownership_scope] || {}
      
      # Clear existing role abilities
      @role.role_abilities.destroy_all
      
      # Get selected permissions
      selected_permissions = Cccux::AbilityPermission.where(id: permission_ids)
      
      # Group permissions by subject to apply ownership scope
      permissions_by_subject = selected_permissions.group_by(&:subject)
      
      permissions_by_subject.each do |subject, permissions|
        # Determine ownership scope for this subject (default to 'all' for CCCUX models)
        scope = ownership_scopes[subject] || (subject.start_with?('Cccux::') ? 'all' : 'all')
        is_owned = (scope == 'owned')
        
        # Create role abilities with appropriate ownership scope
        permissions.each do |permission|
          @role.role_abilities.create!(
            ability_permission: permission,
            owned: is_owned
          )
        end
      end
    end
    
    def role_params
      params.require(:role).permit(:name, :description, :active, :priority)
    end
  end
end
module Cccux
  class RoleAbilitiesController < CccuxController
    before_action :set_role, only: [:index, :create, :destroy]
    before_action :set_role_ability, only: [:destroy]

    def index
      @role_abilities = @role.role_abilities.includes(:ability_permission)
      @available_permissions = Cccux::AbilityPermission.all.group_by(&:subject)
    end

    def create
      @role_ability = @role.role_abilities.build(role_ability_params)
      
      if @role_ability.save
        respond_to do |format|
          format.html { redirect_to cccux.role_path(@role), notice: 'Permission was successfully assigned to role.' }
          format.json { render json: @role_ability, status: :created }
        end
      else
        respond_to do |format|
          format.html { redirect_to cccux.role_path(@role), alert: "Failed to assign permission: #{@role_ability.errors.full_messages.join(', ')}" }
          format.json { render json: { errors: @role_ability.errors }, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      if @role_ability.destroy
        respond_to do |format|
          format.html { redirect_to cccux.role_path(@role), notice: 'Permission was successfully removed from role.' }
          format.json { head :no_content }
        end
      else
        respond_to do |format|
          format.html { redirect_to cccux.role_path(@role), alert: 'Failed to remove permission from role.' }
          format.json { render json: { errors: @role_ability.errors }, status: :unprocessable_entity }
        end
      end
    end

    private

    def set_role
      @role = Cccux::Role.find(params[:role_id])
    end

    def set_role_ability
      @role_ability = @role.role_abilities.find(params[:id])
    end

    def role_ability_params
      # Convert access_type to owned and context
      params_copy = params.require(:cccux_role_ability).permit(:ability_permission_id, :access_type, :owned, :context, :ownership_source, :ownership_conditions)
      
      if params_copy[:access_type].present?
        case params_copy[:access_type]
        when 'owned'
          params_copy[:owned] = true
          params_copy[:context] = 'owned'
        when 'global'
          params_copy[:owned] = false
          params_copy[:context] = 'global'
        end
        params_copy.delete(:access_type)
      end
      
      params_copy
    end
  end
end 
class Cccux::UsersController < Cccux::CccuxController
  before_action :set_user, only: [:show, :edit, :update, :destroy]
  
  def index
    @users = User.includes(:cccux_roles).order(:email)
    @roles = Cccux::Role.active.order(:name)
  end
  
  def show
    @user_roles = @user.cccux_roles.includes(:ability_permissions)
    @available_roles = Cccux::Role.active.where.not(id: @user.cccux_roles.pluck(:id))
  end
  
  def new
    @user = User.new
    @roles = Cccux::Role.active.order(:name)
  end
  
  def create
    @user = User.new(user_params)
    
    if @user.save
      # Assign selected roles
      if params[:user][:role_ids].present?
        params[:user][:role_ids].reject(&:blank?).each do |role_id|
          role = Cccux::Role.find(role_id)
          @user.assign_role(role)
        end
      end
      
      redirect_to cccux.user_path(@user), notice: 'User was successfully created.'
    else
      @roles = Cccux::Role.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @available_roles = Cccux::Role.active.order(:name)
    @user_role_ids = @user.cccux_roles.pluck(:id)
  end
  
  def update
    # Handle password updates - remove blank password fields
    update_params = user_params
    if update_params[:password].blank?
      update_params = update_params.except(:password, :password_confirmation)
    end
    
    if @user.update(update_params)
      # Update role assignments
      if params[:user][:role_ids]
        # Remove all current roles
        @user.cccux_user_roles.destroy_all
        
        # Add selected roles
        params[:user][:role_ids].reject(&:blank?).each do |role_id|
          role = Cccux::Role.find(role_id)
          @user.assign_role(role)
        end
      end
      
      redirect_to cccux.user_path(@user), notice: 'User was successfully updated.'
    else
      @available_roles = Cccux::Role.active.order(:name)
      @user_role_ids = @user.cccux_roles.pluck(:id)
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @user.destroy
    redirect_to cccux.users_path, notice: 'User was successfully deleted.'
  end
  
  # AJAX endpoint for role assignment
  def assign_role
    @user = User.find(params[:id])
    role = Cccux::Role.find(params[:role_id])
    
    if @user.assign_role(role)
      render json: { status: 'success', message: "#{role.name} role assigned to #{@user.email}" }
    else
      render json: { status: 'error', message: 'Failed to assign role' }
    end
  end
  
  # AJAX endpoint for role removal
  def remove_role
    @user = User.find(params[:id])
    role = Cccux::Role.find(params[:role_id])
    
    if @user.remove_role(role)
      render json: { status: 'success', message: "#{role.name} role removed from #{@user.email}" }
    else
      render json: { status: 'error', message: 'Failed to remove role' }
    end
  end
  
  private
  
  def set_user
    @user = User.find(params[:id])
  end
  
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end 
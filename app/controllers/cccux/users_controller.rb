module Cccux
  class UsersController < CccuxController
 
    before_action :set_user, only: [:show, :edit, :update, :destroy]

    def index
      @users = Cccux::User.includes(:roles).order(:email)
    end

    def show
      @user_roles = @user.roles
      @available_roles = Cccux::Role.where.not(id: @user.role_ids)
    end

    def new
      @user = Cccux::User.new
      @available_roles = Cccux::Role.all
    end

    def create
      @user = Cccux::User.new(user_params)
      
      if @user.save
        update_user_roles
        redirect_to cccux.user_path(@user), notice: 'User was successfully created.'
      else
        @available_roles = Cccux::Role.all
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @available_roles = Cccux::Role.all
    end

    def update
      if @user.update(user_params)
        update_user_roles
        redirect_to cccux.user_path(@user), notice: 'User was successfully updated.'
      else
        @available_roles = Cccux::Role.all
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @user.destroy
      redirect_to cccux.users_path, notice: 'User was successfully deleted.'
    end

    private

    def set_user
      @user = Cccux::User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email, :first_name, :last_name, :active, :notes)
    end

    def update_user_roles
      role_ids = params[:user][:role_ids] || []
      @user.roles = Cccux::Role.where(id: role_ids)
    end
  end
end
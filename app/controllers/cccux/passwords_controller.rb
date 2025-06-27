module Cccux
  class PasswordsController < Devise::PasswordsController
    layout 'cccux/application'
    
    protected
    
    def after_resetting_password_path_for(resource)
      cccux.root_path
    end
  end
end 
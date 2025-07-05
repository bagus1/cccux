module Cccux
  class AuthorizationController < ApplicationController
    # Provide CCCUX authorization without forcing a specific layout
    # This allows host app controllers to use their own layouts
    layout 'application'
    
    # Automatically load and authorize resources for all actions
    load_and_authorize_resource
  end
end 
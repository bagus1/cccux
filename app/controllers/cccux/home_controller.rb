# frozen_string_literal: true

module Cccux
  class HomeController < CccuxController
    def index
      # This controller can be used as a fallback root route
      # It will redirect to the host app's root or show a simple welcome page
      
      # Try to redirect to host app's root first
      if Rails.application.routes.recognize_path('/', method: :get) rescue false
        redirect_to '/'
        return
      end
      
      # If no host app root, show a simple welcome page
      render :index
    end
  end
end 
module Cccux
  class SimpleController < ApplicationController
    def index
      render plain: "CCCUX Engine is working! Time: #{Time.current}"
    end
  end
end 
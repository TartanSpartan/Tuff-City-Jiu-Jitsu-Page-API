class StaticController < ApplicationController
    def index
        render plain: "Hello from StaticController index action!"
    end 
end
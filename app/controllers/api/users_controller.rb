class Api::UsersController < ApplicationController

  def index
    @users = User.all
    render json: UserSerializer.from(@users), status: :ok
  end

end

class Api::UsersController < ApplicationController

  before_action :set_user, only: [:follow, :unfollow]

  def index
    @users = User.all
    render json: UserSerializer.from(@users), status: :ok
  end

  def follow
    if current_user.follow(@user)
      render json: UserSerializer.from(current_user), status: :ok
    else
      render json: { error: 'Failed to follow user' }, status: :unprocessable_entity
    end
  end

  def unfollow
    if current_user.unfollow(@user)
      render json: UserSerializer.from(current_user), status: :ok
    else
      render json: { error: 'Failed to unfollow user' }, status: :unprocessable_entity
    end
  end

  def set_user
    @user = User.find(params[:id])
  end

end

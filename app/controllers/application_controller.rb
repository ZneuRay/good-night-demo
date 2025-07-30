class ApplicationController < ActionController::API
  before_action :set_current_user

  private

  def set_current_user
    # For demo purposes, we assume the user ID is passed in the request headers
    # In a real application, you would use a more secure method like JWT or session-based
    user_id = request.headers['X-User-ID']

    # Fallback to first user for testing
    user_id = User.first.id if user_id.blank?

    # Uncomment the following lines if you want to enforce user ID presence
    # if user_id.blank?
    #   render json: { error: 'User ID header is required' }, status: :unauthorized
    #   return
    # end

    @current_user = User.find(user_id)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  def current_user
    @current_user
  end

  # Helper method for controllers that need to ensure user is authenticated
  def authenticate_user!
    render json: { error: 'Authentication required' }, status: :unauthorized unless current_user
  end
end

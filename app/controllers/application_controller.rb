class ApplicationController < ActionController::API
  before_action :set_current_user

  # Global error handling for common exceptions
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActionController::ParameterMissing, with: :parameter_missing

  private

  def set_current_user
    # For demo purposes, we assume the user ID is passed in the request headers
    # In a real application, you would use a more secure method like JWT or session-based
    user_id = request.headers['X-User-ID']

    # Fallback to first user for testing
    if user_id.blank?
      begin
        user_id = User.first&.id
      rescue ActiveRecord::StatementInvalid
        # Handle case where User table doesn't exist yet
        render json: { error: 'Database not initialized' }, status: :service_unavailable
        return
      end
    end

    # Uncomment the following lines if you want to enforce user ID presence
    # if user_id.blank?
    #   render json: { error: 'User ID header is required' }, status: :unauthorized
    #   return
    # end

    if user_id.blank?
      render json: { error: 'No users available and no User ID provided' }, status: :not_found
      return
    end

    @current_user = User.find(user_id)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
    Rails.logger.error "Database error in set_current_user: #{e.message}"
    render json: { error: 'Database connection error' }, status: :service_unavailable
  end

  def current_user
    @current_user
  end

  # Helper method for controllers that need to ensure user is authenticated
  def authenticate_user!
    render json: { error: 'Authentication required' }, status: :unauthorized unless current_user
  end

  # Global error handlers following API response format standards
  def record_not_found(exception)
    Rails.logger.warn "Record not found: #{exception.message}"

    model_name = extract_model_name(exception)
    error_message = "#{model_name} not found"

    render json: { error: error_message }, status: :not_found
  end

  def record_invalid(exception)
    Rails.logger.warn "Record invalid: #{exception.message}"

    render json: {
      error: "Validation failed",
      details: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def parameter_missing(exception)
    Rails.logger.warn "Parameter missing: #{exception.message}"

    render json: {
      error: "Required parameter missing",
      details: [exception.message]
    }, status: :bad_request
  end

  # Handle unexpected errors gracefully
  def handle_unexpected_error(exception)
    Rails.logger.error "Unexpected error: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    if Rails.env.development?
      render json: {
        error: "Internal server error",
        details: [exception.message],
        backtrace: exception.backtrace.first(10)
      }, status: :internal_server_error
    else
      render json: { error: "Internal server error" }, status: :internal_server_error
    end
  end

  private

  # Extract model name from ActiveRecord::RecordNotFound exception
  def extract_model_name(exception)
    # Extract model name from error message like "Couldn't find User with 'id'=999"
    match = exception.message.match(/Couldn't find (\w+)/)
    match ? match[1] : "Record"
  end
end

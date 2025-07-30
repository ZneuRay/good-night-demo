class Api::Users::SleepRecordsController < ApplicationController

  before_action :authenticate_user!

  def index
    @sleep_records = current_user.sleep_records.completed
    render json: SleepRecordsSerializer.from(@sleep_records), status: :ok
  end

  def clock_in
    if current_user.clock_in!
      render json: { message: 'Clocked in successfully' }, status: :ok
    else
      render json: { error: 'Failed to clock in' }, status: :unprocessable_entity
    end
  end

  def clock_out
    if current_user.clock_out!
      render json: { message: 'Clocked out successfully' }, status: :ok
    else
      render json: { error: 'Failed to clock out' }, status: :unprocessable_entity
    end
  end
end

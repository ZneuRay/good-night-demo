class Api::Users::SleepRecordsController < ApplicationController

  before_action :authenticate_user!

  def index
    @sleep_records = current_user.sleep_records.completed
    render json: SleepRecordsSerializer.from(@sleep_records), status: :ok
  end

  def clock_in
    service = Sleep::ClockInService.new(user: current_user)

    if service.call
      render json: {
        sleep_record: SleepRecordsSerializer.from(service.sleep_record),
        message: "Clocked in successfully"
      }, status: :created
    else
      render json: {
        error: "Clock in failed",
        details: service.errors
      }, status: :unprocessable_entity
    end
  end

  def clock_out
    service = Sleep::ClockOutService.new(user: current_user)

    if service.call
      render json: {
        sleep_record: SleepRecordsSerializer.from(service.sleep_record),
        message: "Clocked out successfully"
      }, status: :ok
    else
      render json: {
        error: "Clock out failed",
        details: service.errors
      }, status: :unprocessable_entity
    end
  end
end

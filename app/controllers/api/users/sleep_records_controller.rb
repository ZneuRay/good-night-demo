class Api::Users::SleepRecordsController < ApplicationController

  before_action :authenticate_user!

  def index
    @sleep_records = current_user.sleep_records
    render json: SleepRecordsSerializer.from(@sleep_records), status: :ok
  end

  def clock_in

  end

  def clock_out

  end
end

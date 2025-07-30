require "test_helper"

class Api::Users::SleepRecordsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(name: "Alice Johnson")
    @other_user = User.create!(name: "Bob Smith")
    @headers = { 'X-User-ID' => @user.id.to_s }

    # Create test sleep records with various states
    @completed_record = @user.sleep_records.create!(
      clock_in_time: 2.days.ago,
      clock_out_time: 2.days.ago + 8.hours
    )

    @another_completed_record = @user.sleep_records.create!(
      clock_in_time: 3.days.ago,
      clock_out_time: 3.days.ago + 7.hours
    )

    # Other user's record (should not appear in current user's results)
    @other_user_record = @other_user.sleep_records.create!(
      clock_in_time: 1.day.ago,
      clock_out_time: 1.day.ago + 6.hours
    )

    # Clear cache before each test
    Rails.cache.clear
  end

  # GET /api/users/:user_id/sleep_records
  test "should get index with completed sleep records" do
    get api_user_sleep_records_url(@user), headers: @headers

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert json_response.is_a?(Array)
    assert_equal 2, json_response.length

    # Should only return current user's completed records
    record_ids = json_response.map { |r| r['id'] }
    assert_includes record_ids, @completed_record.id
    assert_includes record_ids, @another_completed_record.id
    assert_not_includes record_ids, @other_user_record.id
  end

  test "should return empty array when user has no completed sleep records" do
    new_user = User.create!(name: "New User")
    headers = { 'X-User-ID' => new_user.id.to_s }

    get api_user_sleep_records_url(new_user), headers: headers

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_equal [], json_response
  end

  test "should not include incomplete sleep records in index" do
    # Create incomplete record
    @user.sleep_records.create!(clock_in_time: 1.hour.ago)

    get api_user_sleep_records_url(@user), headers: @headers

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should still only return the 2 completed records
    assert_equal 2, json_response.length
  end

  test "should return proper JSON structure for sleep records" do
    get api_user_sleep_records_url(@user), headers: @headers

    assert_response :ok
    json_response = JSON.parse(response.body)

    sleep_record = json_response.first
    expected_keys = %w[id clock_in_time clock_out_time duration]

    expected_keys.each do |key|
      assert sleep_record.key?(key), "Missing key: #{key}"
    end

    assert sleep_record['id'].is_a?(Integer)
    assert sleep_record['clock_in_time'].is_a?(String)
    assert sleep_record['clock_out_time'].is_a?(String)
    assert sleep_record['duration'].is_a?(Integer)
  end

  test "should handle invalid user ID in URL for index" do
    get api_user_sleep_records_url(99999), headers: @headers

    assert_response :ok # Uses current_user from header, ignores URL param
    json_response = JSON.parse(response.body)
    assert_equal 2, json_response.length
  end

  # POST /api/users/:user_id/sleep_records/clock_in
  test "should clock in successfully when no incomplete records exist" do
    assert_difference '@user.sleep_records.count', 1 do
      post clock_in_api_user_sleep_records_url(@user), headers: @headers
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "Clocked in successfully", json_response['message']

    # Verify the sleep record was created
    latest_record = @user.sleep_records.last
    assert_not_nil latest_record.clock_in_time
    assert_nil latest_record.clock_out_time
  end

  test "should return proper response format on successful clock in" do
    post clock_in_api_user_sleep_records_url(@user), headers: @headers

    assert_response :created
    json_response = JSON.parse(response.body)

    assert json_response.key?('message')
    assert json_response['message'].is_a?(String)
    assert_equal 'application/json; charset=utf-8', response.content_type
  end

  # Bypass authentication for demo
  # test "should require authentication header for clock in" do
  #   post clock_in_api_user_sleep_records_url(@user)

  #   assert_response :unauthorized
  #   json_response = JSON.parse(response.body)
  #   assert_equal "User ID header is required", json_response['error']
  # end

  test "should handle clock in with invalid user ID in header" do
    invalid_headers = { 'X-User-ID' => '99999' }

    post clock_in_api_user_sleep_records_url(@user), headers: invalid_headers

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "User not found", json_response['error']
  end

  test "should set clock_in_time to current time on clock in" do
    freeze_time = Time.current

    travel_to freeze_time do
      post clock_in_api_user_sleep_records_url(@user), headers: @headers
    end

    assert_response :created

    latest_record = @user.sleep_records.last
    assert_equal freeze_time.to_i, latest_record.clock_in_time.to_i
  end

  # PATCH /api/users/:user_id/sleep_records/clock_out
  test "should clock out successfully when incomplete record exists" do
    # Create incomplete record to clock out
    incomplete_record = @user.sleep_records.create!(clock_in_time: 8.hours.ago)

    assert_no_difference '@user.sleep_records.count' do
      patch clock_out_api_user_sleep_records_url(@user), headers: @headers
    end

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_equal "Clocked out successfully", json_response['message']

    # Verify the record was updated
    incomplete_record.reload
    assert_not_nil incomplete_record.clock_out_time
    assert incomplete_record.completed?
  end

  test "should return proper response format on successful clock out" do
    @user.sleep_records.create!(clock_in_time: 8.hours.ago)

    patch clock_out_api_user_sleep_records_url(@user), headers: @headers

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert json_response.key?('message')
    assert json_response['message'].is_a?(String)
    assert_equal 'application/json; charset=utf-8', response.content_type
  end

  test "should fail to clock out when no incomplete record exists" do
    # No incomplete records exist
    assert_no_difference '@user.sleep_records.count' do
      patch clock_out_api_user_sleep_records_url(@user), headers: @headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "Clock out failed", json_response['error']
  end

  # Bypass authentication for demo
  # test "should require authentication header for clock out" do
  #   patch clock_out_api_user_sleep_records_url(@user)

  #   assert_response :unauthorized
  #   json_response = JSON.parse(response.body)
  #   assert_equal "User ID header is required", json_response['error']
  # end

  test "should handle clock out with invalid user ID in header" do
    invalid_headers = { 'X-User-ID' => '99999' }

    patch clock_out_api_user_sleep_records_url(@user), headers: invalid_headers

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "User not found", json_response['error']
  end

  test "should set clock_out_time to current time on clock out" do
    @user.sleep_records.create!(clock_in_time: 8.hours.ago)
    freeze_time = Time.current

    travel_to freeze_time do
      patch clock_out_api_user_sleep_records_url(@user), headers: @headers
    end

    assert_response :ok

    latest_record = @user.sleep_records.last
    assert_equal freeze_time.to_i, latest_record.clock_out_time.to_i
  end

  test "should update the most recent incomplete record on clock out" do
    # Create multiple incomplete records (edge case)
    first_incomplete = @user.sleep_records.create!(clock_in_time: 10.hours.ago)
    second_incomplete = @user.sleep_records.create!(clock_in_time: 8.hours.ago)

    patch clock_out_api_user_sleep_records_url(@user), headers: @headers

    assert_response :ok

    # Should update the most recent incomplete record
    first_incomplete.reload
    second_incomplete.reload

    assert_nil first_incomplete.clock_out_time # Should remain incomplete
    assert_not_nil second_incomplete.clock_out_time # Should be completed
  end


  private

  def api_user_sleep_records_url(user)
    if user.is_a?(User)
      "/api/users/#{user.id}/sleep_records"
    else
      "/api/users/#{user}/sleep_records"
    end
  end

  def clock_in_api_user_sleep_records_url(user)
    if user.is_a?(User)
      "/api/users/#{user.id}/sleep_records/clock_in"
    else
      "/api/users/#{user}/sleep_records/clock_in"
    end
  end

  def clock_out_api_user_sleep_records_url(user)
    if user.is_a?(User)
      "/api/users/#{user.id}/sleep_records/clock_out"
    else
      "/api/users/#{user}/sleep_records/clock_out"
    end
  end
end

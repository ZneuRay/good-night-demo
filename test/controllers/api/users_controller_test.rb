require "test_helper"

class Api::UsersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(name: "Test User")
    @other_user = User.create!(name: "Other User")

    # Create some test data for serialization
    @user.sleep_records.create!(clock_in_time: 1.day.ago, clock_out_time: 1.day.ago + 8.hours)
    @user.follow(@other_user)
  end

  # GET /api/users
  test "should get index" do
    get api_users_url
    assert_response :ok
  end

  test "should return all users as JSON" do
    get api_users_url

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert json_response.is_a?(Array)
    assert_equal User.count, json_response.length
  end

  test "should return users with correct serialized attributes" do
    get api_users_url

    assert_response :ok
    json_response = JSON.parse(response.body)

    user_data = json_response.find { |u| u['id'] == @user.id }
    assert_not_nil user_data

    # Check serialized attributes
    assert_equal @user.id, user_data['id']
    assert_equal @user.name, user_data['name']
    assert_equal 1, user_data['sleep_records_count']
    assert_equal 1, user_data['following_count']
    assert_equal 0, user_data['followers_count']
  end

  test "should handle empty users collection" do
    User.destroy_all

    get api_users_url

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_equal [], json_response
  end

  test "should include followers count correctly" do
    @other_user.follow(@user) # other_user follows @user

    get api_users_url

    assert_response :ok
    json_response = JSON.parse(response.body)

    user_data = json_response.find { |u| u['id'] == @user.id }
    assert_equal 1, user_data['followers_count']
  end

  test "should return users ordered consistently" do
    # Create additional users
    user1 = User.create!(name: "User 1")
    user2 = User.create!(name: "User 2")

    get api_users_url

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should return all users including fixtures and created ones
    expected_count = User.count
    assert_equal expected_count, json_response.length

    # Each user should have required attributes
    json_response.each do |user_data|
      assert user_data.key?('id')
      assert user_data.key?('name')
      assert user_data.key?('sleep_records_count')
      assert user_data.key?('following_count')
      assert user_data.key?('followers_count')
    end
  end

  test "should handle users with no sleep records" do
    user_without_sleep = User.create!(name: "No Sleep User")

    get api_users_url

    assert_response :ok
    json_response = JSON.parse(response.body)

    user_data = json_response.find { |u| u['id'] == user_without_sleep.id }
    assert_equal 0, user_data['sleep_records_count']
    assert_equal 0, user_data['following_count']
    assert_equal 0, user_data['followers_count']
  end

  test "should handle users with multiple sleep records" do
    # Add more sleep records
    @user.sleep_records.create!(clock_in_time: 2.days.ago, clock_out_time: 2.days.ago + 7.hours)
    @user.sleep_records.create!(clock_in_time: 3.days.ago) # incomplete record

    get api_users_url

    assert_response :ok
    json_response = JSON.parse(response.body)

    user_data = json_response.find { |u| u['id'] == @user.id }
    assert_equal 3, user_data['sleep_records_count']
  end

  test "should handle complex social relationships" do
    user3 = User.create!(name: "User 3")
    user4 = User.create!(name: "User 4")

    # Create complex following relationships
    @user.follow(user3)
    @user.follow(user4)
    user3.follow(@user)
    user4.follow(@user)

    get api_users_url

    assert_response :ok
    json_response = JSON.parse(response.body)

    user_data = json_response.find { |u| u['id'] == @user.id }
    assert_equal 3, user_data['following_count'] # follows @other_user, user3, user4
    assert_equal 2, user_data['followers_count'] # followed by user3, user4
  end

  test "should include proper response headers" do
    get api_users_url

    assert_response :ok
    assert response.headers['Content-Type'].include?('application/json')
  end

  test "should return consistent JSON structure" do
    get api_users_url

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Verify JSON structure consistency
    expected_keys = %w[id name sleep_records_count following_count followers_count]

    json_response.each do |user_data|
      expected_keys.each do |key|
        assert user_data.key?(key), "Missing key: #{key} in user data"
      end

      # Verify data types
      assert user_data['id'].is_a?(Integer)
      assert user_data['name'].is_a?(String)
      assert user_data['sleep_records_count'].is_a?(Integer)
      assert user_data['following_count'].is_a?(Integer)
      assert user_data['followers_count'].is_a?(Integer)
    end
  end

  private

  def api_users_url
    '/api/users'
  end
end

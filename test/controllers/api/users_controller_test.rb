require "test_helper"

class Api::UsersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(name: "Alice Johnson")
    @target_user = User.create!(name: "Bob Smith")
    @another_user = User.create!(name: "Charlie Brown")
    @headers = { 'X-User-ID' => @user.id.to_s }

    # Create some test data for serialization
    @user.sleep_records.create!(clock_in_time: 1.day.ago, clock_out_time: 1.day.ago + 8.hours)
    @user.follow(@target_user)

    # Clear cache before each test
    Rails.cache.clear
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
    assert user_data.key?('following')
    assert user_data['following'].include?(@target_user.name)
  end

  test "should handle empty users collection" do
    User.destroy_all

    get api_users_url

    assert_response :not_found
  end

  test "should include followers count correctly" do
    @another_user.follow(@user) # another_user follows @user

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
      assert user_data.key?('following')
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
    assert_equal [], user_data['following']
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
    assert_equal 3, user_data['following_count'] # follows @target_user, user3, user4
    assert_equal 2, user_data['followers_count'] # followed by user3, user4

    # Check following names are included
    following_names = user_data['following']
    assert_includes following_names, @target_user.name
    assert_includes following_names, user3.name
    assert_includes following_names, user4.name
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
    expected_keys = %w[id name sleep_records_count following_count followers_count following]

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
      assert user_data['following'].is_a?(Array)
    end
  end

  # POST /api/users/:id/follow
  test "should follow user successfully" do
    unfollowed_user = User.create!(name: "Unfollowed User")

    assert_difference '@user.following.count', 1 do
      post follow_api_user_url(unfollowed_user), headers: @headers
    end

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should return updated current user data
    assert_equal @user.id, json_response['id']
    assert_equal 2, json_response['following_count'] # @target_user + unfollowed_user
    assert_includes json_response['following'], unfollowed_user.name
  end

  test "should prevent duplicate follows" do
    # @user already follows @target_user from setup

    assert_no_difference '@user.following.count' do
      post follow_api_user_url(@target_user), headers: @headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_equal "Failed to follow user", json_response['error']
  end

  test "should prevent self-follow" do
    assert_no_difference '@user.following.count' do
      post follow_api_user_url(@user), headers: @headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_equal "Failed to follow user", json_response['error']
  end

  test "should handle invalid target user ID on follow" do
    post follow_api_user_url(99999), headers: @headers

    assert_response :not_found
  end

  # Bypass authentication in demo mode
  # test "should require authentication header for follow" do
  #   post follow_api_user_url(@target_user)

  #   assert_response :unauthorized
  #   json_response = JSON.parse(response.body)

  #   assert_equal "User ID header is required", json_response['error']
  # end

  test "should invalidate following cache on successful follow" do
    unfollowed_user = User.create!(name: "Cache Test User")

    # Prime the cache
    @user.following_count

    post follow_api_user_url(unfollowed_user), headers: @headers

    assert_response :ok

    # Cache should be invalidated, count should reflect new follow
    assert_equal 2, @user.following_count
  end

  # DELETE /api/users/:id/unfollow
  test "should unfollow user successfully" do
    # @user follows @target_user from setup

    assert_difference '@user.following.count', -1 do
      delete unfollow_api_user_url(@target_user), headers: @headers
    end

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should return updated current user data
    assert_equal @user.id, json_response['id']
    assert_equal 0, json_response['following_count']
    assert_not_includes json_response['following'], @target_user.name
  end

  test "should handle unfollowing user not currently followed" do
    delete unfollow_api_user_url(@another_user), headers: @headers

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_equal "Failed to unfollow user", json_response['error']
  end

  test "should handle invalid target user ID on unfollow" do
    delete unfollow_api_user_url(99999), headers: @headers

    assert_response :not_found
  end

  # Bypass authentication in demo mode
  # test "should require authentication header for unfollow" do
  #   delete unfollow_api_user_url(@target_user)

  #   assert_response :unauthorized
  #   json_response = JSON.parse(response.body)

  #   assert_equal "User ID header is required", json_response['error']
  # end

  test "should invalidate following cache on successful unfollow" do
    # @user follows @target_user from setup

    # Prime the cache
    assert_equal 1, @user.following_count

    delete unfollow_api_user_url(@target_user), headers: @headers

    assert_response :ok

    # Cache should be invalidated, count should reflect unfollow
    assert_equal 0, @user.following_count
  end

  # Performance and concurrency tests
  test "should handle concurrent follow requests" do
    concurrent_target = User.create!(name: "Concurrent Target")
    threads = []
    results = []

    # Simulate concurrent follow requests
    5.times do
      threads << Thread.new do
        begin
          post follow_api_user_url(concurrent_target), headers: @headers
          results << response.status
        rescue => e
          results << 500
        end
      end
    end

    threads.each(&:join)

    # Only one should succeed (200), others should fail (422)
    success_count = results.count(200)
    assert_equal 1, success_count, "Expected exactly one successful follow"
    assert_equal 1, @user.followings.where(followed: concurrent_target).count
  end

  test "should handle rapid follow/unfollow sequence" do
    rapid_target = User.create!(name: "Rapid Target")

    # Rapid follow/unfollow sequence
    5.times do
      post follow_api_user_url(rapid_target), headers: @headers
      assert_response :ok

      delete unfollow_api_user_url(rapid_target), headers: @headers
      assert_response :ok
    end

    # Final state should be unfollowed
    assert_not @user.following?(rapid_target)
  end

  test "should maintain data consistency during multiple operations" do
    users_to_follow = 3.times.map { |i| User.create!(name: "Multi User #{i}") }

    # Follow multiple users
    users_to_follow.each do |user|
      post follow_api_user_url(user), headers: @headers
      assert_response :ok
    end

    # Verify final state
    get api_users_url
    json_response = JSON.parse(response.body)
    user_data = json_response.find { |u| u['id'] == @user.id }

    # Should have original follow + 3 new follows
    assert_equal 4, user_data['following_count']

    # Unfollow one
    delete unfollow_api_user_url(users_to_follow.first), headers: @headers
    assert_response :ok

    # Verify count decreased
    get api_users_url
    json_response = JSON.parse(response.body)
    user_data = json_response.find { |u| u['id'] == @user.id }
    assert_equal 3, user_data['following_count']
  end

  test "should handle follow requests with proper content type" do
    unfollowed_user = User.create!(name: "Content Type User")

    post follow_api_user_url(unfollowed_user),
         headers: @headers.merge('Content-Type' => 'application/json')

    assert_response :ok
    assert_equal 'application/json; charset=utf-8', response.content_type
  end

  test "should return complete user serialization after follow operations" do
    unfollowed_user = User.create!(name: "Serialization Test User")

    post follow_api_user_url(unfollowed_user), headers: @headers

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should include all expected serialized attributes
    expected_keys = %w[id name sleep_records_count following_count followers_count following]
    expected_keys.each do |key|
      assert json_response.key?(key), "Missing key: #{key} in follow response"
    end

    # Following list should include both users
    assert_includes json_response['following'], @target_user.name
    assert_includes json_response['following'], unfollowed_user.name
  end

  private

  def api_users_url
    '/api/users'
  end

  def follow_api_user_url(user)
    if user.is_a?(User)
      "/api/users/#{user.id}/follow"
    else
      "/api/users/#{user}/follow"
    end
  end

  def unfollow_api_user_url(user)
    if user.is_a?(User)
      "/api/users/#{user.id}/unfollow"
    else
      "/api/users/#{user}/unfollow"
    end
  end
end

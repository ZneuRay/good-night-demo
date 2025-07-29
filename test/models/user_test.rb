require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(name: "John Doe")
    @other_user = User.create!(name: "Jane Smith")
  end

  test "should have 5 users" do
    assert_equal 5, User.count
  end

  test "should be valid with valid attributes" do
    assert @user.valid?
  end

  test "should save user with valid attributes" do
    assert @user.save
    assert_not_nil @user.id
    assert_not_nil @user.created_at
    assert_not_nil @user.updated_at
    assert_equal 6, User.count
  end

  test "should have a name attribute" do
    assert_respond_to @user, :name
    assert_respond_to @user, :name=
  end

  test "should have timestamps" do
    assert_respond_to @user, :created_at
    assert_respond_to @user, :updated_at
  end

  test "name can be set and retrieved" do
    name = "Jane Smith"
    @user.name = name
    assert_equal name, @user.name
  end

  test "should create user with factory method" do
    user = User.create(name: "Factory User")
    assert user.persisted?
    assert_equal "Factory User", user.name
  end

  test "should update user attributes" do
    @user.save
    original_name = @user.name
    new_name = "Updated Name"

    @user.update(name: new_name)
    assert_equal new_name, @user.name
    assert_not_equal original_name, @user.name
  end

  test "should destroy user" do
    @user.save
    user_id = @user.id

    assert_difference 'User.count', -1 do
      @user.destroy
    end

    assert_raises(ActiveRecord::RecordNotFound) do
      User.find(user_id)
    end
  end

  test "should find user by name" do
    @user.save
    found_user = User.find_by(name: @user.name)
    assert_equal @user, found_user
  end

  test "timestamps should be set on creation" do
    time_before = Time.current
    user = User.create(name: "Test User")
    time_after = Time.current

    assert user.created_at >= time_before
    assert user.created_at <= time_after
    assert user.updated_at >= time_before
    assert user.updated_at <= time_after
  end

  test "updated_at should change on update" do
    @user.save
    original_updated_at = @user.updated_at

    # Sleep briefly to ensure timestamp difference
    sleep 0.01
    @user.update(name: "New Name")

    assert @user.updated_at > original_updated_at
  end

  test "should load fixtures correctly" do
    alice = users(:alice)
    bob = users(:bob)
    admin = users(:admin)

    assert_equal "Alice Johnson", alice.name
    assert_equal "Bob Smith", bob.name
    assert_equal "Admin User", admin.name
  end

  test "fixtures should be persisted" do
    alice = users(:alice)
    assert alice.persisted?
    assert_not_nil alice.id
  end

  # Tests for Followable concern
  test "should include followable concern" do
    assert @user.respond_to?(:follow)
    assert @user.respond_to?(:unfollow)
    assert @user.respond_to?(:following?)
    assert @user.respond_to?(:following_count)
    assert @user.respond_to?(:followers_count)
  end

  test "should have following associations" do
    @user.save!
    assert_respond_to @user, :followings
    assert_respond_to @user, :following
    assert_respond_to @user, :reverse_followings
    assert_respond_to @user, :followers
  end

  test "should follow another user successfully" do
    @user.save!

    result = @user.follow(@other_user)

    assert result
    assert @user.following?(@other_user)
    assert_equal 1, @user.following_count
    assert_includes @user.following, @other_user
  end

  test "should unfollow another user successfully" do
    @user.save!
    @user.follow(@other_user)

    result = @user.unfollow(@other_user)

    assert result
    assert_not @user.following?(@other_user)
    assert_equal 0, @user.following_count
    assert_not_includes @user.following, @other_user
  end

  test "should not follow the same user twice" do
    @user.save!
    @user.follow(@other_user)

    result = @user.follow(@other_user)

    assert_not result
    assert_equal 1, @user.following_count
  end

  test "should not follow self" do
    @user.save!

    result = @user.follow(@user)

    assert_not result
    assert_not @user.following?(@user)
    assert_equal 0, @user.following_count
  end

  test "should return false when unfollowing user not followed" do
    @user.save!

    result = @user.unfollow(@other_user)

    assert_not result
  end

  test "should count followers correctly" do
    @user.save!
    third_user = User.create!(name: "Third User")

    @other_user.follow(@user)
    third_user.follow(@user)

    assert_equal 2, @user.followers_count
    assert_includes @user.followers, @other_user
    assert_includes @user.followers, third_user
  end

  test "should destroy associated followings when user is deleted" do
    @user.save!
    @user.follow(@other_user)
    @other_user.follow(@user)

    assert_difference ['Following.count'], -2 do
      @user.destroy
    end
  end

  # Tests for SleepTracking concern
  test "should include sleep tracking concern" do
    assert @user.respond_to?(:clock_in!)
    assert @user.respond_to?(:clock_out!)
    assert @user.respond_to?(:last_incomplete_sleep_record)
    assert @user.respond_to?(:ordered_sleep_records)
    assert @user.respond_to?(:following_sleep_records_previous_week)
  end

  test "should have sleep records association" do
    @user.save!
    assert_respond_to @user, :sleep_records
    assert_equal 0, @user.sleep_records.count
  end

  test "should clock in successfully" do
    @user.save!

    sleep_record = @user.clock_in!

    assert_not_nil sleep_record
    assert sleep_record.persisted?
    assert_not_nil sleep_record.clock_in_time
    assert_nil sleep_record.clock_out_time
    assert_equal @user, sleep_record.user
    assert_equal 1, @user.sleep_records.count
  end

  test "should clock out successfully" do
    @user.save!
    sleep_record = @user.clock_in!

    updated_record = @user.clock_out!

    assert_not_nil updated_record
    assert_equal sleep_record.id, updated_record.id
    assert_not_nil updated_record.clock_out_time
    assert updated_record.completed?
    assert updated_record.clock_out_time > updated_record.clock_in_time
  end

  test "should return nil when clocking out without incomplete record" do
    @user.save!

    result = @user.clock_out!

    assert_nil result
  end

  test "should find last incomplete sleep record" do
    @user.save!
    completed_record = @user.sleep_records.create!(
      clock_in_time: 2.days.ago,
      clock_out_time: 1.day.ago
    )
    incomplete_record = @user.clock_in!

    last_incomplete = @user.last_incomplete_sleep_record

    assert_equal incomplete_record.id, last_incomplete.id
    assert_not_equal completed_record.id, last_incomplete.id
  end

  test "should return ordered sleep records" do
    @user.save!
    first_record = @user.sleep_records.create!(
      clock_in_time: 2.days.ago,
      created_at: 2.days.ago
    )
    second_record = @user.sleep_records.create!(
      clock_in_time: 1.day.ago,
      created_at: 1.day.ago
    )

    ordered_records = @user.ordered_sleep_records

    assert_equal first_record.id, ordered_records.last.id
    assert_equal second_record.id, ordered_records.first.id
  end

  test "should handle multiple clock ins correctly" do
    @user.save!

    first_record = @user.clock_in!
    second_record = @user.clock_in!

    assert_not_equal first_record.id, second_record.id
    assert_equal 2, @user.sleep_records.count
    assert_equal second_record.id, @user.last_incomplete_sleep_record.id
  end

  test "should clock out most recent incomplete record" do
    @user.save!
    first_record = @user.clock_in!
    second_record = @user.clock_in!

    updated_record = @user.clock_out!

    assert_equal second_record.id, updated_record.id
    assert_not_nil updated_record.clock_out_time

    # First record should still be incomplete
    first_record.reload
    assert_nil first_record.clock_out_time
  end

  test "should get following users sleep records from previous week" do
    @user.save!
    @user.follow(@other_user)

    # Create completed sleep record for followed user
    @other_user.sleep_records.create!(
      clock_in_time: 3.days.ago,
      clock_out_time: 3.days.ago + 8.hours,
      created_at: 3.days.ago
    )

    # Create old record (should not be included)
    @other_user.sleep_records.create!(
      clock_in_time: 2.weeks.ago,
      clock_out_time: 2.weeks.ago + 6.hours,
      created_at: 2.weeks.ago
    )

    following_records = @user.following_sleep_records_previous_week

    assert_equal 1, following_records.size
    assert_equal @other_user.id, following_records.first.user_id
  end

  test "should destroy associated sleep records when user is deleted" do
    @user.save!
    @user.clock_in!
    @user.clock_in!

    assert_difference ['SleepRecord.count'], -2 do
      @user.destroy
    end
  end

  # Tests for Cacheable concern
  test "should include cacheable concern" do
    assert @user.respond_to?(:cache_read)
    assert @user.respond_to?(:cache_write)
    assert @user.respond_to?(:cache_fetch)
    assert @user.respond_to?(:cache_delete)
  end

  test "should cache and retrieve values correctly" do
    @user.save!
    test_value = "cached_value"

    @user.cache_write("test_key", test_value)
    retrieved_value = @user.cache_read("test_key")

    assert_equal test_value, retrieved_value
  end

  test "should handle cache fetch with block" do
    @user.save!

    result = @user.cache_fetch("test_fetch") do
      "computed_value"
    end

    assert_equal "computed_value", result

    # Second call should return cached value
    cached_result = @user.cache_fetch("test_fetch") do
      "new_computed_value"
    end

    assert_equal "computed_value", cached_result
  end

  test "should delete cached values" do
    @user.save!
    @user.cache_write("test_delete", "value")

    @user.cache_delete("test_delete")
    retrieved_value = @user.cache_read("test_delete")

    assert_nil retrieved_value
  end
end

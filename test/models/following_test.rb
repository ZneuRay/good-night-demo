require "test_helper"

class FollowingTest < ActiveSupport::TestCase
  setup do
    @follower = users(:alice)
    @followed = users(:bob)
    @following = Following.new(follower: @follower, followed: @followed)
  end

  test "should be valid with valid attributes" do
    assert @following.valid?
  end

  test "should require follower" do
    @following.follower = nil
    assert_not @following.valid?
    assert_includes @following.errors[:follower], "must exist"
  end

  test "should require followed" do
    @following.followed = nil
    assert_not @following.valid?
    assert_includes @following.errors[:followed], "must exist"
  end

  test "should save successfully with valid attributes" do
    assert_difference 'Following.count', 1 do
      @following.save!
    end

    assert_not_nil @following.id
    assert_not_nil @following.created_at
    assert_not_nil @following.updated_at
    assert_equal @follower, @following.follower
    assert_equal @followed, @following.followed
  end

  test "should not allow duplicate follows" do
    @following.save!

    duplicate_follow = Following.new(follower: @follower, followed: @followed)
    assert_not duplicate_follow.valid?
    assert_includes duplicate_follow.errors[:follower_id], "already following this user"
  end

  test "should allow same user to be followed by different users" do
    other_follower = User.create!(name: "Other Follower")
    @following.save!

    other_follow = Following.new(follower: other_follower, followed: @followed)
    assert other_follow.valid?
    assert other_follow.save
  end

  test "should allow same user to follow different users" do
    other_followed = User.create!(name: "Other Followed")
    @following.save!

    other_follow = Following.new(follower: @follower, followed: other_followed)
    assert other_follow.valid?
    assert other_follow.save
  end

  test "should not allow self-follow" do
    self_follow = Following.new(follower: @follower, followed: @follower)
    assert_not self_follow.valid?
    assert_includes self_follow.errors[:followed], "cannot follow yourself"
  end

  test "should prevent self-follow with same user instance" do
    user = User.create!(name: "Self User")
    self_follow = Following.new(follower: user, followed: user)

    assert_not self_follow.valid?
    assert_includes self_follow.errors[:followed], "cannot follow yourself"
  end

  test "should handle validation error on duplicate follow attempt" do
    @following.save!

    assert_no_difference 'Following.count' do
      assert_raises ActiveRecord::RecordInvalid do
        Following.create!(follower: @follower, followed: @followed)
      end
    end
  end

  test "should destroy following relationship" do
    @following.save!

    assert_difference 'Following.count', -1 do
      @following.destroy!
    end
  end

  test "should belong to follower user" do
    @following.save!
    assert_equal @follower, @following.follower
    assert_respond_to @following, :follower
  end

  test "should belong to followed user" do
    @following.save!
    assert_equal @followed, @following.followed
    assert_respond_to @following, :followed
  end

  test "should have timestamps" do
    @following.save!
    assert_not_nil @following.created_at
    assert_not_nil @following.updated_at
    assert @following.created_at <= Time.current
    assert @following.updated_at <= Time.current
  end

  test "should handle edge case with nil user IDs" do
    following_with_nil = Following.new(follower_id: nil, followed_id: nil)
    assert_not following_with_nil.valid?
  end

  test "should handle edge case with same ID for follower and followed" do
    user_id = @follower.id
    following_with_same_id = Following.new(follower_id: user_id, followed_id: user_id)
    assert_not following_with_same_id.valid?
    assert_includes following_with_same_id.errors[:followed], "cannot follow yourself"
  end
end

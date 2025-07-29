require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(name: "John Doe")
  end

  test "should have 4 users" do
    assert User.count, 4
  end

  test "should be valid with valid attributes" do
    assert @user.valid?
  end

  test "should save user with valid attributes" do
    assert @user.save
    assert_not_nil @user.id
    assert_not_nil @user.created_at
    assert_not_nil @user.updated_at
    assert User.count, 5
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

  test "should allow nil name by default" do
    user = User.new(name: nil)
    assert user.valid?
  end

  test "should allow empty name by default" do
    user = User.new(name: "")
    assert user.valid?
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
end

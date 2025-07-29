require "test_helper"

class MySerializerTest < ActiveSupport::TestCase
  # Test serializer class for basic functionality
  class TestUserSerializer
    include MySerializer

    attribute :id
    attribute :name
    attribute :email
  end

  # Test serializer with block attributes
  class TestUserWithBlockSerializer
    include MySerializer

    attribute :id
    attribute :full_name do |user|
      "#{user.first_name} #{user.last_name}".strip
    end
    attribute :age_category do |user|
      user.age >= 18 ? "adult" : "minor"
    end
  end

  # Test serializer with nested serialization
  class TestPostSerializer
    include MySerializer

    attribute :id
    attribute :title
    attribute :author, TestUserSerializer
  end

  # Test serializer with array nested serialization
  class TestUserWithPostsSerializer
    include MySerializer

    attribute :id
    attribute :name
    attribute :posts, TestPostSerializer
  end

  # Mock objects for testing
  class MockUser
    attr_accessor :id, :name, :email, :first_name, :last_name, :age

    def initialize(attributes = {})
      attributes.each { |key, value| send("#{key}=", value) }
    end
  end

  class MockPost
    attr_accessor :id, :title, :author

    def initialize(attributes = {})
      attributes.each { |key, value| send("#{key}=", value) }
    end
  end

  def setup
    @user = MockUser.new(
      id: 1,
      name: "John Doe",
      email: "john@example.com",
      first_name: "John",
      last_name: "Doe",
      age: 25
    )

    @author = MockUser.new(
      id: 2,
      name: "Jane Smith",
      email: "jane@example.com"
    )

    @post = MockPost.new(
      id: 1,
      title: "Test Post",
      author: @author
    )

    @user_with_posts = MockUser.new(
      id: 3,
      name: "Author User",
      email: "author@example.com"
    )
    @user_with_posts.define_singleton_method(:posts) do
      [
        MockPost.new(id: 1, title: "First Post"),
        MockPost.new(id: 2, title: "Second Post")
      ]
    end
  end

  # Test basic serialization
  test "should serialize single object with basic attributes" do
    result = TestUserSerializer.from(@user)

    expected = {
      id: 1,
      name: "John Doe",
      email: "john@example.com"
    }

    assert_equal expected, result
  end

  test "should serialize array of objects" do
    users = [@user, @author]
    result = TestUserSerializer.from(users)

    assert_equal 2, result.length
    assert_equal @user.id, result.first[:id]
    assert_equal @author.id, result.last[:id]
    assert_equal @user.name, result.first[:name]
    assert_equal @author.name, result.last[:name]
  end

  test "should handle empty array" do
    result = TestUserSerializer.from([])

    assert_equal [], result
  end

  test "should handle nil object gracefully" do
    result = TestUserSerializer.from(nil)

    expected = { id: nil, name: nil, email: nil }
    assert_equal expected, result
  end

  # Test block attributes
  test "should execute block attributes correctly" do
    result = TestUserWithBlockSerializer.from(@user)

    expected = {
      id: 1,
      full_name: "John Doe",
      age_category: "adult"
    }

    assert_equal expected, result
  end

  test "should handle block attributes with minor age" do
    young_user = MockUser.new(
      id: 2,
      first_name: "Young",
      last_name: "User",
      age: 16
    )

    result = TestUserWithBlockSerializer.from(young_user)

    assert_equal "minor", result[:age_category]
    assert_equal "Young User", result[:full_name]
  end

  test "should handle block attributes with missing data" do
    incomplete_user = MockUser.new(id: 3, first_name: "Only", age: 20)

    result = TestUserWithBlockSerializer.from(incomplete_user)

    assert_equal "Only", result[:full_name]
    assert_equal "adult", result[:age_category]
  end

  # Test nested serialization
  test "should serialize nested objects with serializer" do
    result = TestPostSerializer.from(@post)

    expected = {
      id: 1,
      title: "Test Post",
      author: {
        id: 2,
        name: "Jane Smith",
        email: "jane@example.com"
      }
    }

    assert_equal expected, result
  end

  test "should handle nil nested objects" do
    post_without_author = MockPost.new(id: 2, title: "No Author Post", author: nil)
    result = TestPostSerializer.from(post_without_author)

    expected = {
      id: 2,
      title: "No Author Post",
      author: nil
    }

    assert_equal expected, result
  end

  test "should serialize arrays of nested objects" do
    result = TestUserWithPostsSerializer.from(@user_with_posts)

    expected = {
      id: 3,
      name: "Author User",
      posts: [
        { id: 1, title: "First Post", author: nil },
        { id: 2, title: "Second Post", author: nil }
      ]
    }

    assert_equal expected, result
  end

  # Test ActiveRecord::Relation compatibility
  test "should handle ActiveRecord::Relation" do
    # Mock ActiveRecord::Relation behavior
    mock_relation = [@user, @author]
    mock_relation.define_singleton_method(:is_a?) { |klass| klass == ActiveRecord::Relation }

    result = TestUserSerializer.from(mock_relation)

    assert_equal 2, result.length
    assert_equal @user.id, result.first[:id]
    assert_equal @author.id, result.last[:id]
  end

  # Test class method configurations
  test "should maintain separate attribute configurations per class" do
    user_attributes = TestUserSerializer.attributes_config.keys
    block_attributes = TestUserWithBlockSerializer.attributes_config.keys

    assert_includes user_attributes, :id
    assert_includes user_attributes, :name
    assert_includes user_attributes, :email

    assert_includes block_attributes, :id
    assert_includes block_attributes, :full_name
    assert_includes block_attributes, :age_category

    assert_not_includes user_attributes, :full_name
    assert_not_includes block_attributes, :name
  end

  test "should store correct configuration for each attribute type" do
    config = TestUserWithBlockSerializer.attributes_config

    # Basic attribute
    assert_nil config[:id][:serializer]
    assert_nil config[:id][:block]

    # Block attribute
    assert_nil config[:full_name][:serializer]
    assert_not_nil config[:full_name][:block]
    assert config[:full_name][:block].is_a?(Proc)

    # Nested serializer attribute in TestPostSerializer
    post_config = TestPostSerializer.attributes_config
    assert_equal TestUserSerializer, post_config[:author][:serializer]
    assert_nil post_config[:author][:block]
  end

  test "should handle serializer inheritance" do
    # Test that each serializer class has its own attributes_config
    TestUserSerializer.attribute :test_attr
    TestUserWithBlockSerializer.attribute :another_test_attr

    assert_includes TestUserSerializer.attributes_config.keys, :test_attr
    assert_not_includes TestUserWithBlockSerializer.attributes_config.keys, :test_attr
    assert_includes TestUserWithBlockSerializer.attributes_config.keys, :another_test_attr
    assert_not_includes TestUserSerializer.attributes_config.keys, :another_test_attr
  end

  # Test that serializer works with Rails models (integration test style)
  test "should work with actual Rails models" do
    # skip "Integration test - requires actual User model" unless defined?(User)

    # This would test with actual User model if available
    user = User.create!(name: "Test User")
    result = TestUserSerializer.from(user)
    assert result[:id].present?
  end
end

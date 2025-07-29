module Followable
  extend ActiveSupport::Concern

  included do
    # Following relationships - users this user follows
    has_many :followings, foreign_key: 'follower_id', dependent: :destroy
    has_many :following, through: :followings, source: :followed

    # Follower relationships - users who follow this user
    has_many :reverse_followings, class_name: 'Following', foreign_key: 'followed_id', dependent: :destroy
    has_many :followers, through: :reverse_followings, source: :follower
  end

  # Follow another user
  # Returns true if successful, false if already following or trying to follow self
  def follow(user)
    return false if following?(user) || user == self

    followings.create!(followed: user)
    invalidate_following_cache
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Unfollow a user
  # Returns true if successful, false if not following
  def unfollow(user)
    following_record = followings.find_by(followed: user)
    return false unless following_record

    following_record.destroy!
    invalidate_following_cache
    true
  end

  # Check if this user is following another user
  def following?(user)
    cached_following_ids.include?(user.id)
  end

  # Get count of users this user is following
  def following_count
    cached_following_ids.size
  end

  # Get count of users following this user
  def followers_count
    cache_key = "user:#{id}:followers_count"
    Rails.cache.fetch(cache_key, expires_in: 6.hours) do
      followers.count
    end
  end

  private

  # Cache following user IDs for performance
  def cached_following_ids
    cache_key = "user:#{id}:following_list"
    Rails.cache.fetch(cache_key, expires_in: 6.hours) do
      following.pluck(:id)
    end
  end

  # Invalidate following cache when relationships change
  def invalidate_following_cache
    Rails.cache.delete("user:#{id}:following_list")
    Rails.cache.delete("user:#{id}:followers_count")
  end
end

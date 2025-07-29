class User < ApplicationRecord

  has_many :sleep_records, dependent: :destroy

  # Following relationships - users this user follows
  has_many :followings, foreign_key: 'follower_id', dependent: :destroy
  has_many :following, through: :followings, source: :followed

  # Follower relationships - users who follow this user
  has_many :reverse_followings, class_name: 'Following', foreign_key: 'followed_id', dependent: :destroy
  has_many :followers, through: :reverse_followings, source: :follower

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

  private

  # Cache following user IDs for performance
  def cached_following_ids
    cache_key = "user:#{id}:following_list"

    Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      following.pluck(:id)
    end
  end

  # Invalidate following cache when relationships change
  def invalidate_following_cache
    cache_key = "user:#{id}:following_list"
    Rails.cache.delete(cache_key)
  end

  # Get the start of current week for cache key consistency
  def week_start_date
    Date.current.beginning_of_week.strftime('%Y-%m-%d')
  end

end

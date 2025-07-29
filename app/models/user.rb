class User < ApplicationRecord

  has_many :sleep_records, dependent: :destroy

  # Following relationships - users this user follows
  has_many :followings, foreign_key: 'follower_id', dependent: :destroy
  has_many :following, through: :followings, source: :followed

  # Follower relationships - users who follow this user
  has_many :reverse_followings, class_name: 'Following', foreign_key: 'followed_id', dependent: :destroy
  has_many :followers, through: :reverse_followings, source: :follower

  # Follow a user
  def follow(user)
    following << user unless following.include?(user)
  end

  # Unfollow a user
  def unfollow(user)
    following.delete(user)
  end

  # Check if following a user
  def following?(user)
    following.include?(user)
  end

end

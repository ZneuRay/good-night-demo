class UserSerializer
  include MySerializer

  attribute :id
  attribute :name
  attribute :sleep_records_count do |user|
    user.sleep_records.count
  end
  attribute :following_count
  attribute :followers_count
end

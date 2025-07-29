class User < ApplicationRecord

  include Followable

  has_many :sleep_records, dependent: :destroy



end

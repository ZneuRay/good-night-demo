class User < ApplicationRecord

  has_many :sleep_records, dependent: :destroy

end

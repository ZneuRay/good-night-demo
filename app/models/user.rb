class User < ApplicationRecord
  include Followable
  include SleepTracking

end

class SleepRecord < ApplicationRecord

  belongs_to :user

  validates :clock_in_time, presence: true
  validate :clock_out_after_clock_in, if: :clock_out_time?

  default_scope { order(created_at: :desc) }
  scope :completed, -> { where.not(clock_out_time: nil) }
  scope :incomplete, -> { where(clock_out_time: nil) }
  scope :previous_week, -> {
    where(created_at: 1.week.ago..Time.current)
  }

  def completed?
    clock_out_time.present?
  end

  def duration
    return nil unless completed?

    clock_out_time - clock_in_time
  end

  private

  def clock_out_after_clock_in
    return unless clock_out_time.present? && clock_in_time.present?

    if clock_out_time <= clock_in_time
      errors.add(:clock_out_time, "must be after clock in time")
    end
  end

end

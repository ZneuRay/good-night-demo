class SleepRecord < ApplicationRecord

  belongs_to :user

  validates :clock_in_time, presence: true
  validate :clock_out_after_clock_in, if: :clock_out_time?

  scope :completed, -> { where.not(clock_out_time: nil) }
  scope :incomplete, -> { where(clock_out_time: nil) }
  scope :previous_week, -> {
    where(created_at: 1.week.ago..Time.current)
  }
  scope :ordered_by_duration, -> {
    completed.order(Arel.sql("clock_out_time - clock_in_time DESC"))
  }
  scope :ordered_by_created_time, -> {
    order(created_at: :desc)
  }

  def completed?
    clock_out_time.present?
  end

  def duration
    return nil unless completed?

    (clock_out_time - clock_in_time).floor
  end

  private

  def clock_out_after_clock_in
    return unless clock_out_time.present? && clock_in_time.present?

    if clock_out_time <= clock_in_time
      errors.add(:clock_out_time, "must be after clock in time")
    end
  end

end

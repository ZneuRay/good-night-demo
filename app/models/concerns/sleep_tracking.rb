module SleepTracking
  extend ActiveSupport::Concern

  included do
    # Ensure Cacheable is included before SleepTracking
    include Cacheable unless included_modules.include?(Cacheable)

    has_many :sleep_records, dependent: :destroy
    scope :completed, -> { where.not(duration: 0) }
    scope :incomplete, -> { where(duration: 0) }
  end

  # Find the last incomplete sleep record for clock out functionality
  def last_incomplete_sleep_record
    sleep_records.incomplete.order(:created_at).last
  end

  # Get all sleep records ordered by creation time
  def ordered_sleep_records
    sleep_records.ordered_by_created_time
  end

  # Create a new sleep record and cache the ID for performance
  def clock_in!
    sleep_record = sleep_records.create!(clock_in_time: Time.current)
    cache_last_incomplete_sleep_record(sleep_record.id)
    sleep_record
  end

  # Update the last incomplete sleep record with clock out time
  def clock_out!
    record = find_cached_incomplete_sleep_record || last_incomplete_sleep_record
    return nil unless record

    record.update!(clock_out_time: Time.current)
    clear_incomplete_sleep_cache
    record
  end

  # Get following users' sleep records from previous week, sorted by duration
  def following_sleep_records_previous_week
    cache_fetch("following_sleep_records:week:#{week_start_date}", expires_in: 1.hour) do
      SleepRecord.joins(:user)
                 .where(user: following)
                 .previous_week
                 .completed
                 .includes(:user)
                 .order(Arel.sql('(clock_out_time - clock_in_time) DESC'))
    end
  end

  private

  # Cache the last incomplete sleep record ID for 24 hours
  def cache_last_incomplete_sleep_record(record_id)
    cache_write("last_incomplete_sleep:#{Date.current}", record_id, expires_in: 24.hours)
  end

  # Find incomplete sleep record from cache
  def find_cached_incomplete_sleep_record
    record_id = cache_read("last_incomplete_sleep:#{Date.current}")
    return nil unless record_id

    sleep_records.find_by(id: record_id, clock_out_time: nil)
  end

  # Clear the incomplete sleep record cache
  def clear_incomplete_sleep_cache
    cache_delete("last_incomplete_sleep:#{Date.current}")
  end

  # Get the start of current week for cache key consistency
  def week_start_date
    Date.current.beginning_of_week.strftime('%Y-%m-%d')
  end
end

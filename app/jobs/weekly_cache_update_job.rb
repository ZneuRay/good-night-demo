class WeeklyCacheUpdateJob < ApplicationJob
  queue_as :default

  def perform(user_id, record_data, week_key)
    # Get existing weekly records or initialize empty array
    weekly_records = Rails.cache.read(week_key) || []

    # Add new record (avoid duplicates)
    weekly_records.reject! { |r| r[:id] == record_data[:id] }
    weekly_records << record_data

    # Sort by duration descending
    weekly_records.sort_by! { |r| -r[:duration] }

    # Cache for 1 month with large cache support
    Rails.cache.write(week_key, weekly_records, expires_in: 1.month)

    Rails.logger.info "Updated weekly cache #{week_key} with #{weekly_records.length} records"
  end
end

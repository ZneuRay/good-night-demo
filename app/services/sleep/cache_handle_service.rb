module Sleep
  class CacheHandleService < ApplicationService
    attr_reader :user

    def initialize(user:)
      @user = user
    end

    # Check if user has any incomplete sleep records
    def has_incomplete_sleep_record?
      Rails.cache.fetch(incomplete_sleep_cache_key, expires_in: 24.hours) do
        user.sleep_records.incomplete.exists?
      end
    end

    # Find the most recent incomplete sleep record (highest ID)
    def find_latest_incomplete_record
      # Try cache first for performance
      cached_record = find_cached_incomplete_record
      return cached_record if cached_record

      # Fallback to database - find the latest incomplete record by ID
      record = user.sleep_records.incomplete.order(:id).last
      cache_incomplete_record(record) if record
      record
    end

    # Cache the latest incomplete sleep record
    def cache_incomplete_record(sleep_record)
      return unless sleep_record

      # Always cache the latest incomplete record (overwrites previous)
      Rails.cache.write(
        last_incomplete_cache_key,
        {
          id: sleep_record.id,
          clock_in_time: sleep_record.clock_in_time.iso8601,
          created_at: sleep_record.created_at.iso8601
        },
        expires_in: 24.hours
      )

      # Update existence flag
      Rails.cache.write(incomplete_sleep_cache_key, true, expires_in: 24.hours)

      Rails.logger.debug "Cached latest incomplete record #{sleep_record.id} for user #{user.id}"
    end

    # Update cache after clock out - check if more incomplete records exist
    def update_incomplete_cache_after_clock_out
      # Clear the current cached incomplete record
      Rails.cache.delete(last_incomplete_cache_key)

      # Check if there are still incomplete records and cache the latest one
      latest_incomplete = user.sleep_records.incomplete.order(:id).last

      if latest_incomplete
        cache_incomplete_record(latest_incomplete)
      else
        # No more incomplete records
        Rails.cache.write(incomplete_sleep_cache_key, false, expires_in: 24.hours)
      end
    end

    # Cache completed sleep record for weekly queries
    def cache_completed_record(sleep_record)
      return unless sleep_record.completed?

      week_key = week_cache_key(sleep_record.clock_in_time)

      # Use background job for cache updates to maintain API performance
      WeeklyCacheUpdateJob.perform_later(user.id, serialize_sleep_record(sleep_record), week_key)

      Rails.logger.info "Queued weekly cache update for completed record #{sleep_record.id}"
    end

    # Get following users' sleep records from cache for previous week
    def following_sleep_records_previous_week
      cache_key = following_weekly_cache_key

      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        collect_following_weekly_records
      end
    end

    private

    def find_cached_incomplete_record
      cached_data = Rails.cache.read(last_incomplete_cache_key)
      return nil unless cached_data

      # Verify the record still exists and is incomplete
      user.sleep_records.find_by(
        id: cached_data[:id],
        clock_out_time: nil
      )
    end

    def collect_following_weekly_records
      previous_week_start = Date.current.beginning_of_week - 1.week
      week_key_suffix = week_cache_key(previous_week_start).split(':').last

      all_records = []

      # Process followers in batches for performance
      user.following.find_in_batches(batch_size: 100) do |batch|
        batch.each do |followed_user|
          user_week_key = "user:#{followed_user.id}:sleep_records:#{week_key_suffix}"
          cached_records = Rails.cache.read(user_week_key) || []

          cached_records.each do |record|
            record[:user] = {
              id: followed_user.id,
              name: followed_user.name
            }
          end

          all_records.concat(cached_records)
        end
      end

      # Sort by duration descending as per requirements
      all_records.sort_by { |r| -r[:duration] }
    end

    def serialize_sleep_record(sleep_record)
      {
        id: sleep_record.id,
        clock_in_time: sleep_record.clock_in_time.iso8601,
        clock_out_time: sleep_record.clock_out_time.iso8601,
        duration: sleep_record.duration,
        created_at: sleep_record.created_at.iso8601
      }
    end

    def week_cache_key(date_time)
      week_start = date_time.to_date.beginning_of_week
      "user:#{user.id}:sleep_records:week:#{week_start.strftime('%Y-%m-%d')}"
    end

    def last_incomplete_cache_key
      "user:#{user.id}:last_incomplete_sleep:#{Date.current.strftime('%Y-%m-%d')}"
    end

    def incomplete_sleep_cache_key
      "user:#{user.id}:has_incomplete_sleep:#{Date.current.strftime('%Y-%m-%d')}"
    end

    def following_weekly_cache_key
      previous_week = Date.current.beginning_of_week - 1.week
      "user:#{user.id}:following_sleep_records:week:#{previous_week.strftime('%Y-%m-%d')}"
    end
  end
end

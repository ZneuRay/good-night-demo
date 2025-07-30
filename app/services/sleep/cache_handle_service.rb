module Sleep
  class CacheHandleService < ApplicationService
    attr_reader :user

    def initialize(user:)
      @user = user
    end

    # Cache the latest incomplete sleep record (overwrites previous)
    def cache_incomplete_record(sleep_record)
      return unless sleep_record

      Rails.cache.write(
        last_incomplete_cache_key,
        {
          id: sleep_record.id,
          clock_in_time: sleep_record.clock_in_time.iso8601,
          created_at: sleep_record.created_at.iso8601
        },
        expires_in: 24.hours
      )

      Rails.logger.debug "Cached latest incomplete record #{sleep_record.id} for user #{user.id}"
    end

    # Clear incomplete cache when a record is completed
    def clear_incomplete_cache_for_record(completed_record)
      cached_data = Rails.cache.read(last_incomplete_cache_key)

      # Only clear if the cached record is the one being completed
      if cached_data && cached_data[:id] == completed_record.id
        Rails.cache.delete(last_incomplete_cache_key)
        Rails.logger.debug "Cleared incomplete cache for completed record #{completed_record.id}"
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

    def collect_following_weekly_records
      previous_week_start = Date.current.beginning_of_week - 1.week
      week_key_suffix = week_cache_key(previous_week_start).split(':').last

      all_records = []

      # Process followers in batches for performance
      user.following.find_in_batches(batch_size: 100) do |batch|
        batch.each do |followed_user|
          user_week_key = "user:#{followed_user.id}:sleep_records:week:#{week_key_suffix}"
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

    def following_weekly_cache_key
      previous_week = Date.current.beginning_of_week - 1.week
      "user:#{user.id}:following_sleep_records:week:#{previous_week.strftime('%Y-%m-%d')}"
    end
  end
end

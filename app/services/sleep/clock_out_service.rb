module Sleep
  class ClockOutService < ApplicationService
    attr_reader :user, :sleep_record, :errors

    def initialize(user:)
      @user = user
      @errors = []
      @sleep_record = nil
    end

    def call
      find_latest_sleep_record
      return false unless @sleep_record

      validate_can_clock_out
      return false unless valid_for_clock_out?

      complete_sleep_record
    rescue ActiveRecord::RecordInvalid => e
      @errors = e.record.errors.full_messages
      false
    rescue StandardError => e
      Rails.logger.error "Clock out failed for user #{user.id}: #{e.message}"
      @errors << "Clock out failed due to system error"
      false
    end

    def success?
      @sleep_record&.completed?
    end

    private

    def find_latest_sleep_record
      # Find the most recent sleep record (regardless of completion status)
      @sleep_record = user.sleep_records.order(:id).last

      unless @sleep_record
        @errors << "No sleep session found to clock out"
      end
    end

    def validate_can_clock_out
      return unless @sleep_record

      if @sleep_record.clock_out_time.present?
        @errors << "Latest sleep session is already completed. Cannot clock out again."
        Rails.logger.warn "Attempted to clock out already completed record #{@sleep_record.id} for user #{user.id}"
      end
    end

    def valid_for_clock_out?
      @sleep_record&.clock_out_time.blank?
    end

    def complete_sleep_record
      clock_out_time = Time.current
      duration_seconds = (clock_out_time - @sleep_record.clock_in_time).to_i

      @sleep_record.update!(
        clock_out_time: clock_out_time,
        duration: duration_seconds
      )

      # Cache the completed record and clear incomplete cache
      cache_service.cache_completed_record(@sleep_record)
      cache_service.clear_incomplete_cache_for_record(@sleep_record)

      Rails.logger.info "Completed sleep record #{@sleep_record.id} for user #{user.id}, duration: #{duration_seconds}s"

      true
    end

    def cache_service
      @cache_service ||= Sleep::CacheHandleService.new(user: user)
    end
  end
end

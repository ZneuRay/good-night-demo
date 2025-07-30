module Sleep
  class ClockInService < ApplicationService
    attr_reader :user, :sleep_record, :errors

    def initialize(user:)
      @user = user
      @errors = []
      @sleep_record = nil
    end

    def call
      create_sleep_record
    rescue StandardError => e
      Rails.logger.error "Clock in failed for user #{user.id}: #{e.message}"
      @errors << "Clock in failed due to system error"
      false
    end

    def success?
      @sleep_record&.persisted?
    end

    private

    def create_sleep_record
      @sleep_record = user.sleep_records.build(
        clock_in_time: Time.current,
        duration: 0 # Initialize as incomplete
      )

      if @sleep_record.save
        # Cache this record as the latest incomplete record
        cache_service.cache_incomplete_record(@sleep_record)

        Rails.logger.info "Created new sleep record #{@sleep_record.id} for user #{user.id}"
        true
      else
        @errors = @sleep_record.errors.full_messages
        false
      end
    end

    def cache_service
      @cache_service ||= CacheHandleService.new(user: user)
    end
  end
end

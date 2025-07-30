module Sleep
  class FollowingService < ApplicationService
    attr_reader :user, :sleep_records, :errors

    def initialize(user:)
      @user = user
      @sleep_records = []
      @errors = []
    end

    def call
      fetch_following_sleep_records
    rescue StandardError => e
      Rails.logger.error "Following service failed for user #{user.id}: #{e.message}"
      @errors << "Failed to retrieve friends' sleep records"
      false
    end

    def success?
      @errors.empty? && @sleep_records.is_a?(Array)
    end

    private

    def fetch_following_sleep_records
      # Use the cache handle service to get following users' sleep records
      @sleep_records = cache_service.following_sleep_records_previous_week

      Rails.logger.info "Retrieved #{@sleep_records.length} sleep records from following users for user #{user.id}"

      true
    end

    def cache_service
      @cache_service ||= Sleep::CacheHandleService.new(user: user)
    end
  end
end

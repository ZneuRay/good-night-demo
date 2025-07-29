module Cacheable
  extend ActiveSupport::Concern

  # Instance method wrapper for AppCache with automatic context
  def cache_read(key)
    AppCache.read(key, context: self)
  end

  def cache_write(key, value, expires_in: nil)
    AppCache.write(key, value, context: self, expires_in: expires_in)
  end

  def cache_fetch(key, expires_in: nil, &block)
    AppCache.fetch(key, context: self, expires_in: expires_in, &block)
  end

  def cache_delete(key)
    AppCache.delete(key, context: self)
  end

  def cache_delete_matched(pattern)
    AppCache.delete_matched(pattern, context: self)
  end
end

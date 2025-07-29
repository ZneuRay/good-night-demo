class AppCache
  def self.read(key, context: nil)
    cache_key = generate_cache_key(key, context)
    Rails.cache.read(cache_key)
  end

  def self.write(key, value, context: nil, expires_in: nil)
    cache_key = generate_cache_key(key, context)
    Rails.cache.write(cache_key, value, expires_in: expires_in)
  end

  def self.fetch(key, context: nil, expires_in: nil, &block)
    cache_key = generate_cache_key(key, context)
    Rails.cache.fetch(cache_key, expires_in: expires_in, &block)
  end

  def self.delete(key, context: nil)
    cache_key = generate_cache_key(key, context)
    Rails.cache.delete(cache_key)
  end

  def self.delete_matched(pattern, context: nil)
    cache_pattern = generate_cache_key(pattern, context)
    Rails.cache.delete_matched(cache_pattern)
  end

  private

  def self.generate_cache_key(key, context)
    return key unless context

    model_name = context.class.name.underscore
    model_id = context.id
    "#{model_name}:#{model_id}:#{key}"
  end
end

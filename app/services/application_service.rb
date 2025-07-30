class ApplicationService
  # Base class for all application services
  # Provides common functionality and structure for service objects
  def self.call(*args)
    new(*args).call
  end

  def call
    raise NotImplementedError, "#{self.class} must implement the call method"
  end
end

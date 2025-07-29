Rails.application.configure do
  config.solid_queue.logger = Rails.logger
  config.solid_queue.connects_to = { database: { writing: :queue } }
end

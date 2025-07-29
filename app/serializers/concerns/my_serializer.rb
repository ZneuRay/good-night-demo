module MySerializer
  extend ActiveSupport::Concern

  class_methods do
    def from(data)
      case data
      when Array
        data.map { |item| new(item).serialize }
      when ActiveRecord::Relation
        data.map { |item| new(item).serialize }
      else
        new(data).serialize
      end
    end

    def attributes_config
      @attributes_config ||= {}
    end

    def attribute(name, serializer_class = nil, &block)
      attributes_config[name] = {
        serializer: serializer_class,
        block: block
      }
    end

  end

  def initialize(object)
    @object = object
  end

  def serialize
    result = {}

    self.class.attributes_config.each do |attr_name, config|
      result[attr_name] = serialize_attribute(attr_name, config)
    end

    result
  end

  private

  def serialize_attribute(attr_name, config)
    # Handle nil object gracefully
    return nil if @object.nil?

    if config[:block]
      # Execute the block if provided
      instance_exec(@object, &config[:block])
    elsif config[:serializer]
      # Use serializer if provided
      value = @object.send(attr_name)
      return nil unless value

      config[:serializer].from(value)
    else
      # Direct attribute access
      @object.respond_to?(attr_name) ? @object.send(attr_name) : nil
    end
  end
end

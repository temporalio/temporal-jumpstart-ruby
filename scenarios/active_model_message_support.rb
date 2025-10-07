require 'json'
require 'active_support/concern'
require 'active_model'

module Scenarios
  module Messages
    # Ruby JSON module support for Active Model classes.
    module ActiveModelJSONSupport
      extend ActiveSupport::Concern
      include ActiveModel::Serializers::JSON

      included do
        def as_json(*)
          super.merge(::JSON.create_id => self.class.name)
        end

        def to_json(*args)
          as_json.to_json(*args)
        end

        def self.json_create(object)
          object = object.dup
          object.delete(::JSON.create_id)
          new(**object.symbolize_keys)
        end
      end
    end
    # Helper so you can write `attribute :foo, typed(Foo)`
    def self.typed(klass) = Types::Model.new(klass)

  end
  # --- Generic typed attribute helpers ---

  module Types
    # Generic "model" type: builds `klass` from Hash / to_h; passes through instances.
    class Model < ActiveModel::Type::Value
      def initialize(klass)
        @klass = klass
      end

      def cast(value)
        return nil if value.nil?
        return value if value.is_a?(@klass)
        return @klass.new(value) if value.is_a?(Hash)
        return @klass.new(value.to_h) if value.respond_to?(:to_h)

        raise ArgumentError, "Can't cast #{value.inspect} to #{@klass}"
      end

      def serialize(value)
        return nil if value.nil?
        return value.as_json if value.respond_to?(:as_json)
        return value if value.is_a?(Hash) # already JSON-like
        raise ArgumentError, "Can't serialize #{value.inspect} (expected #{@klass} or Hash)"
      end

      # Sugar: `typed(MyData).array`
      def array
        ArrayOf.new(self)
      end
    end

    # Array wrapper for any element type (including another ActiveModel type)
    class ArrayOf < ActiveModel::Type::Value
      def initialize(elem_type)
        @elem_type = elem_type
      end

      def cast(value)
        return [] if value.nil?
        arr = value.is_a?(Array) ? value : [value]
        arr.map { |v| @elem_type.cast(v) }
      end

      def serialize(value)
        (value || []).map { |v| @elem_type.serialize(v) }
      end
    end
  end


end

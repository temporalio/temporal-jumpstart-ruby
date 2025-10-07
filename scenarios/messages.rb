# deliverable_orchestration/messages.rb
require "json"
require "active_support/concern"
require "active_model"

module Scenarios
  module Messages
    # ---------- JSON glue that plays nicely with Ruby 3 and our typed attributes ----------
    module ActiveModelJSONSupport
      extend ActiveSupport::Concern
      include ActiveModel::Serializers::JSON

      included do
        # Ensure Serializers::JSON knows what to dump:
        # ActiveModel::Attributes provides #attributes (a hash-like),
        # Serializers::JSON's super will call #serializable_hash under the hood.
        def as_json(*)
          # super should already include attributes; we add a type tag for json_create
          super.merge(::JSON.create_id => self.class.name)
        end

        def to_json(*args)
          as_json.to_json(*args)
        end
      end

      class_methods do
        # Robust json_create: accepts either kwargs or a single hash,
        # and tolerates unknown keys (they'll be ignored by ActiveModel::Attributes).
        def json_create(object)
          obj = object.dup
          obj.delete(::JSON.create_id)

          # Prefer kwargs if possible; fall back to positional hash.
          # Our BaseMessage initializer supports both anyway.
          if obj.respond_to?(:symbolize_keys)
            new(**obj.symbolize_keys) rescue new(obj)
          else
            new(obj)
          end
        end
      end
    end

    # ---------- Generic typed attribute helpers ----------
    module Types
      # Wraps any model class (inherit from BaseMessage) OR any builtin type symbol.
      # You can do: typed(MyMessage) OR typed(:string)
      class Model < ActiveModel::Type::Value
        def initialize(klass_or_type)
          @klass_or_type = klass_or_type
          @builtin_type = builtin_type_for(klass_or_type)
        end

        def cast(value)
          return nil if value.nil?

          # If wrapping a builtin type (e.g., :string / :integer), delegate
          return @builtin_type.cast(value) if @builtin_type

          klass = @klass_or_type
          return value if value.is_a?(klass)
          return klass.new(value) if value.is_a?(Hash)
          return klass.new(value.to_h) if value.respond_to?(:to_h)
          # Last-ditch: if it looks like JSON, try parse then new
          if value.is_a?(String)
            begin
              parsed = JSON.parse(value)
              return klass.new(parsed) if parsed.is_a?(Hash)
            rescue JSON::ParserError
              # fall through
            end
          end
          raise ArgumentError, "Can't cast #{value.inspect} to #{klass}"
        end

        def serialize(value)
          return nil if value.nil?

          # Builtin type?
          return @builtin_type.serialize(value) if @builtin_type

          # Model instance or hash-ish
          return value.as_json if value.respond_to?(:as_json)
          return value if value.is_a?(Hash)
          raise ArgumentError, "Can't serialize #{value.inspect} (expected #{@klass_or_type} or Hash)"
        end

        # sugar: typed(...).array
        def array
          ArrayOf.new(self)
        end

        private

        def builtin_type_for(klass_or_type)
          case klass_or_type
          when Symbol, String
            ActiveModel::Type.lookup(klass_or_type.to_sym)
          else
            nil
          end
        end
      end

      # Array wrapper for any element type (including Model or builtin types)
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

    # Nice DSL helpers
    def self.typed(klass_or_type) = Types::Model.new(klass_or_type)

    def self.array_of(type_or_model) = type_or_model.is_a?(Types::Model) ? Types::ArrayOf.new(type_or_model) : Types::ArrayOf.new(typed(type_or_model))

    # ---------- BaseMessage ----------
    class BaseMessage
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModelJSONSupport

      # Accept both a positional hash and keyword args on Ruby 3+
      def initialize(attributes = nil, **kw)
        attrs = attributes || {}
        attrs = attrs.to_h if attrs.respond_to?(:to_h)
        super(attrs.merge(kw))
      end
    end
  end
end

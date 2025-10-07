require "active_model"
require_relative 'messages'
module Scenarios
  module Messages
    # --- Base ---

    class BaseMessage
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModelJSONSupport # your existing JSON glue
    end

    # --- Your messages ---

    class MyData < BaseMessage
      attribute :value, :string
    end

    class StartScenarioRequest < BaseMessage
      attribute :sleep_seconds, :integer
    end

    class StartLongRunningRequest < BaseMessage
      attribute :sleep_seconds, :integer
      attribute :data,        Scenarios::Messages.typed(MyData)         # single nested model
      attribute :data_items,  Scenarios::Messages.typed(MyData).array   # array of nested models
    end
  end
end
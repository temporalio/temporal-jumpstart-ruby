# frozen_string_literal: true

require 'temporalio/workflow'
require_relative 'scenario_activities'
require_relative 'scenarios_messages'
module Scenarios
  class MyWorkflow < Temporalio::Workflow::Definition
    HOUR = 3600 # 1 hour measured in seconds
    DAY = 24 * HOUR
    YEAR = 365 * DAY
    def execute
      Temporalio::Workflow.execute_activity(
        ScenarioActivities::LongRunningActivity,
        Messages::StartLongRunningRequest.new(sleep_seconds: 30),
        start_to_close_timeout: 45,
        schedule_to_close_timeout: YEAR,
        heartbeat_timeout: 15
        # Wait for activity cancellation completion
        # cancellation_type: Temporalio::Workflow::ActivityCancellationType::WAIT_CANCELLATION_COMPLETED
      )
    rescue Temporalio::Error::ActivityError => e
      # This catches the cancel just for demonstration, you usually don't want to catch it
      if e.cause.is_a?(Temporalio::Error::CanceledError)
        Temporalio::Workflow.logger.info('Workflow cancelled along with its activity')
      end
      raise # Re-raise to properly cancel the workflow
    end
  end
end

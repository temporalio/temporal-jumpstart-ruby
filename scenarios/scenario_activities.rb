# frozen_string_literal: true

require 'temporalio/activity'

module Scenarios

  module ScenarioActivities
    class LongRunningActivityBackground < Temporalio::Activity::Definition
      def execute(input)
        ctx = Temporalio::Activity::Context.current
        token = ctx.info.task_token

        # Shared flag for cooperative shutdown of the heartbeat loop
        stop_heartbeater = false
        main_thread = Thread.current

        # Kick off background heartbeating using an async activity handle
        hb_thread = Thread.new do
          handle = @client.async_activity_handle(token) # <-- no reliance on "current" context
          until stop_heartbeater
            begin
              # Put whatever progress payload you want into details (optional)
              handle.heartbeat({ progress: Time.now.to_i })
              sleep HEARTBEAT_INTERVAL
            rescue Temporalio::Error::AsyncActivityCanceledError => e
              # Bubble cancellation into the main activity thread immediately
              main_thread.raise(Temporalio::Error::CanceledError.new)
            end
          end
        end

        begin
          # ---- Do your real work here (non-blocking relative to the heartbeats) ----
          do_some_long_running_operation(input)
          # -------------------------------------------------------------------------

          # Return your normal result
          "done"
        rescue Temporalio::Error::CanceledError
          # Let it bubble out so the Activity is reported as canceled to the Workflow
          raise
        ensure
          # Always stop and join the heartbeater
          stop_heartbeater = true
          hb_thread.join
        end
      end

      def do_some_long_running_operation(input)
        sleep(input.sleep_seconds)
        # check for progress of db record
      end
    end

    # Activity that demonstrates progress tracking with heartbeating and cancellation
    class LongRunningActivity < Temporalio::Activity::Definition
      def execute(args)
        context = Temporalio::Activity::Context.current
        context.logger.info("Starting activity #{context.info.activity_type} attempt #{context.info.attempt} with sleep at #{args.sleep_seconds}")
        if context.info.heartbeat_timeout > 0
          context.logger.info("Heartbeat specified!")
          begin
            # Allow for resuming from heartbeat details if available
            starting_point = context.info.heartbeat_details.first || 1

            context.logger.info("Starting hearbeating progress: #{starting_point}")

            (starting_point..100).each do |progress|
              # Sleep for the interval - checking cancellation after sleep
              sleep(args.sleep_seconds)

              context.logger.info("Progress: #{progress}")
              context.heartbeat(progress)
            end

            context.logger.info('Fake progress activity completed')
          rescue Temporalio::Error::CanceledError
            # This catches the cancel just for demonstration, you usually don't want to catch it
            context.logger.info('Handling cancellation')
            raise # Re-raise to properly cancel the activity
          end
        else
          context.logger.info("Skipping any kind of heartbeat...Sleeping for #{args.sleep_seconds} seconds")
          sleep(args.sleep_seconds)
        end
      end
    end
  end
end

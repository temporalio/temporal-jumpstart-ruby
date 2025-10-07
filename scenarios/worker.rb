# frozen_string_literal: true

require_relative 'scenario_activities'
require_relative 'my_workflow'
require 'logger'
require 'temporalio/client'
require 'temporalio/worker'
require 'temporalio/runtime'

# Temporalio::Runtime.default = Temporalio::Runtime.new(
#   telemetry: Temporalio::Runtime::TelemetryOptions.new(
#     metrics: Temporalio::Runtime::MetricsOptions.new(
#       metric_prefix: 'temporal.',
#       global_tags: { service: 'temporal-worker', env: ENV.fetch('DD_ENV', 'prod') },
#       opentelemetry: Temporalio::Runtime::OpenTelemetryMetricsOptions.new(
#         # gRPC (preferred):
#         url: 'http://datadog.infrastructure.svc.cluster.local:4317',
#         # or HTTP:
#         # http: true,
#         # url: 'http://datadog.infrastructure.svc.cluster.local:4318/v1/metrics',
#         # Datadog works best (and agentless requires) DELTA temporality:
#         metric_temporality: Temporalio::Runtime::OpenTelemetryMetricsOptions::MetricTemporality::DELTA
#       )
#     )
#   )
# )
# Create a Temporal client
client = Temporalio::Client.connect(
  'localhost:7233',
  'default',
  logger: Logger.new($stdout, level: Logger::INFO)
)

# Create worker with the activities and workflow
worker = Temporalio::Worker.new(
  client:,
  task_queue: 'scenarios',
  activities: [Scenarios::ScenarioActivities::LongRunningActivity, Scenarios::ScenarioActivities::LongRunningActivityBackground],
  workflows: [Scenarios::MyWorkflow]
)

# Run the worker until SIGINT
puts 'Starting worker WITHOUT support for SIGINT shutdown signals (ctrl+c to exit)'

# specifying the SIGINT here means the Worker will send a signal back to the service that any pending activities
# should be rescheduled...basically meaning when you Ctrl+C you aren't simulating a Worker crash
# (which might be SIGKILL or just a segfault)
# worker.run(shutdown_signals: ['SIGINT'])

# note we dont specify any os signals as hints to try to send the signal for temporal to do its darnest
worker.run
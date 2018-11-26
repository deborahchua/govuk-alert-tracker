require_relative 'lib/govuk_alert_tracker'

task default: %w[run_monthly_report]

task :run_monthly_report do
  GovukAlertTracker.new.run_report(1)
end

task :run_report, [:months] do |t, args|
  GovukAlertTracker.new.run_report(args[:months].to_i)
end

require './govuk-alert-tracker.rb'

task default: %w[run_monthly_report]

#heroku scheduler runs every day but we only want the report to be generated once a month
task :run_monthly_report do
  GovukAlertTracker.new.run_report(1)
end

task :run_report, [:months] do |t, args|
  GovukAlertTracker.new.run_report(args[:months].to_i)
end

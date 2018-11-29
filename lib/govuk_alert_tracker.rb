require 'active_support/core_ext/time'
require 'date'
require 'pry'

require_relative 'icinga'
require_relative 'spreadsheet_poster'

class GovukAlertTracker
  def run_report(months)
    script_start_time = Time.now

    dates = months_of_the_past(months, script_start_time.strftime("%m-%Y"))
    puts "Dates: #{dates}"

    dates.each { |date| run_month_report(date) }
    spreadsheet_poster.commit

    script_duration = Time.now - script_start_time
    puts "Script ran in #{Time.at(script_duration).utc.strftime("%H:%M:%S")}"
  end

private

  def run_month_report(date) # mm-yyyy
    start_date = epoch_date("01-#{date}")
    end_date = end_date(date)
    hosts_list.each do |host|
      puts "#{date} - #{host}"
      save_alerts(host, start_date, end_date)
    end
  end

  def save_alerts(host, start_date, end_date)
    alerts = icinga.alerts(host, start_date, end_date)
    alerts.each do |alert|
      parsed_host = alert.host
      parsed_alert = alert.message
      spreadsheet_poster.append(row: [
        parsed_host, alert.date, parsed_alert, 1, 1, parsed_alert
      ])
    end
  end

  def epoch_date(date)
    DateTime.parse(date).to_time.to_i
  end

  def end_date(date)
    month = date[0..1].to_i
    year = date[3..-1].to_i
    epoch_date("#{Time.days_in_month(month, year)}-#{date}")
  end

  def hosts_list
    # this list has to be updated manually - it's hard to get it from Icinga as there is no specific url for it
    File.readlines("./list_of_hosts.txt").map(&:strip)
  end

  def months_of_the_past(number_of_months, end_date)
    end_date = "01-#{end_date}"
    latest_month = DateTime.parse(end_date).prev_month
    dates = [ latest_month.strftime("%m-%Y")]
    number_of_months -= 1
    number_of_months.times do
      previous_month = latest_month.prev_month
      dates << previous_month.strftime("%m-%Y")
      latest_month = previous_month
      number_of_months -= 1
    end
    dates
  end

  def icinga
    @icinga ||= Icinga.new
  end

  def spreadsheet_poster
    @spreadsheet_poster ||= SpreadsheetPoster.new
  end
end

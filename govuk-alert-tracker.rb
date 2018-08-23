require 'nokogiri'
require 'faraday'
require 'pry'
require 'date'
require 'csv'

NUMBERS_OF_DAYS_IN_A_MONTH = {
  "01" => "31",
  "02" => "28",
  "03" => "31",
  "04" => "30",
  "05" => "31",
  "06" => "30",
  "07" => "31",
  "08" => "31",
  "09" => "30",
  "10" => "31",
  "11" => "30",
  "12" => "31",
}


def run_report(months)
  script_start_time = Time.now
  dates = months_of_the_past(months, script_start_time.strftime("%m-%Y"))
  file_name = generate_file_name("yearly", dates)
  create_csv(file_name)
  hosts_list.each do |host|
    counter_message(host)
  end
  monthly_reports = dates.each { |d| alert_report(d, file_name) }
  script_duration = Time.now - script_start_time
  p "script ran in #{Time.at(script_duration).utc.strftime("%H:%M:%S")}"
end

def alert_report(date, file_name) #mm-yyyy
  script_start_time = Time.now
  start_date = epoch_date("01-#{date}")
  end_date = end_date(date)
  list = {}
  hosts_list.each do |host|
    p "#{date} - #{host}"
    extract_alerts(host, start_date, end_date, file_name)
  end
  script_duration = Time.now - script_start_time
  p "script ran in #{Time.at(script_duration).utc.strftime("%H:%M:%S")} for #{date}"
end

def create_csv(file_name)
  CSV.open(file_name, "wb") do |csv|
    csv << ["host", "date", "alert"]
  end
end

def generate_file_name(time_period, dates)
  "#{time_period}-alerts-from-#{dates[-1]}-to-#{dates[0]}"
end

def extract_alerts(host, start_date, end_date, file_name)
  alerts = alerts_per_month(host, start_date, end_date)
  alerts.each do |alert|
    parsed_alert = strip_date_and_host(alert)
    parsed_host = strip_number_off_host_name(host)
    CSV.open(file_name, "a+") do |csv|
      csv << [parsed_host, alert[1..10], parsed_alert]
    end
  end
end

def strip_date_and_host(alert)
  alert.slice(/;.*/)[1..-1]
end

def strip_number_off_host_name(host)
  host.sub(/-\d/, '')
end

def counter_message(host)
  "#{hosts_list.index(host) + 1 }/#{hosts_list.count} - #{host}"
end

def epoch_date(date)
  DateTime.parse(date).to_time.to_i
end

def end_date(date)
  last_day_of_the_month = NUMBERS_OF_DAYS_IN_A_MONTH[date[0..1]] + "-"
  epoch_date(last_day_of_the_month + date)
end

def build_url(host, start_date, end_date)
  "https://alert.publishing.service.gov.uk/cgi-bin/icinga/history.cgi?ts_start=#{start_date}&ts_end=#{end_date}&host=#{host}.publishing.service.gov.uk&statetype=0&type=16&nosystem=on&limit=1000&start=1"
end

def hosts_list #this list has to be updated manually - it's hard to get it from Icinga as there is no specific url for it.
  array = []
  File.readlines("./list_of_hosts.txt"). each do |line|
    array << line.strip
  end
  array
end

def alerts_per_month(host, start_date, end_date)
  url = build_url(host, start_date, end_date)
  css = get_alerts(url)
  alerts = extract_from_css(css)
  alerts.compact
end

def get_alerts(url)
  page = Faraday.get(url).body
  html_doc = Nokogiri::HTML(page)
  html_doc.css("div[class='logEntries']")
end

def extract_from_css(css)
  result = []
  array = css.to_s.split(/<br clear="all">/)
  array.map do |line|
    result << line.slice!(/\[.*/) unless line.include?("SOFT")
  end
  result
end

def months_of_the_past(number_of_months, end_date)
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

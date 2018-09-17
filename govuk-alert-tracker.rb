require 'nokogiri'
require 'faraday'
require 'date'
require './spreadsheet_poster.rb'
require 'pry'

class GovukAlertTracker
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
    script_start_time = Time.new(2017,11,1)
    dates = months_of_the_past(months, script_start_time.strftime("%m-%Y"))
    p dates
    hosts_list.each do |host|
      counter_message(host)
    end
    @spreadsheet_poster = SpreadsheetPoster.new
    @values = []
    monthly_reports = dates.each { |date| alert_report(date) }
    @spreadsheet_poster.append_values(@values) #this publishes the last batch of alerts that doesn't usually make it to 100
    script_duration = Time.now - script_start_time
    p "script ran in #{Time.at(script_duration).utc.strftime("%H:%M:%S")}"
  end

private

  def alert_report(date) #mm-yyyy
    script_start_time = Time.now
    start_date = epoch_date("01-#{date}")
    end_date = end_date(date)
    list = {}
    hosts_list.each do |host|
      p "#{date} - #{host}"
      extract_alerts(host, start_date, end_date)
    end
    script_duration = Time.now - script_start_time
    p "script ran in #{Time.at(script_duration).utc.strftime("%H:%M:%S")} for #{date}"
  end


  def extract_alerts(host, start_date, end_date)
    alerts = alerts_per_month(host, start_date, end_date)
    alerts.each do |alert|
      parsed_host = strip_number_off_host_name(host)
      parsed_alert = strip_date_and_host(alert)
      post_to_spreadsheet(parsed_host, alert, parsed_alert)
    end
  end

  def post_to_spreadsheet(parsed_host, alert, parsed_alert)
    if @values.count < 100 #this is to make a batch request to the Google API to avoid rate limiting errors
      @values << [ parsed_host, alert[1..10], parsed_alert, 1, 1, parsed_alert ]
    else
      @spreadsheet_poster.append_values(@values)
      @values = []
    end
  end

  def strip_date_and_host(alert)
    alert.slice(/;.*?(;)/)[1..-2]
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
end

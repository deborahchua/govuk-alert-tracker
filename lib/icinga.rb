require 'faraday'
require 'nokogiri'
require 'csv'

Alert = Struct.new(:name, :host, :date, :message) do
  def machine_class
    host.split("-")[0..-2].join("-")
  end

  def eql?(other)
    machine_class == other.machine_class && date == other.date && message == other.message
  end

  def hash
    [name, machine_class, date, message].hash
  end
end

class Icinga
  def alerts(name, host, start_date, end_date)
    # warning=4, critical=16, unknown=8
    # alert_types = [4, 16, 8]
    url = build_url(host, start_date, end_date)
    css = get_log_entries(url)
    extract_from_css(css).map do |text|
      parse_alert(name, host, text)
    end
  end

  def hosts
    url = "https://alert.blue.production.govuk.digital/cgi-bin/icinga/status.cgi?host=all&style=hostdetail&hoststatustypes=2&limit=0&start=1&scroll=2"
    css = get_host_entries(url)
    hosts_list = []
    CSV.open("list_of_hosts.csv", "wb") do |csv|
      css.each do |host|
        host = host.text.split(" ")
        name = host[0].to_s
        ip = host[1].to_s.gsub("(","").gsub(")","").gsub(".","-")
        hosts_list << [name, ip]
        # csv << [name, ip]
        csv << [name, ip]
      end
    end
    # binding.pry
  end

private

  def parse_alert(name, host, text)
    date = text[1..10]
    message = text.slice(/;.*?(;)/)[1..-2]
    Alert.new(host.strip, date.strip, message.strip)
  end

  def build_url(host, start_date, end_date)
    "https://alert.blue.production.govuk.digital/cgi-bin/icinga/history.cgi" \
    "?ts_start=#{start_date}" \
    "&ts_end=#{end_date}" \
    "&host=ip-#{host}.eu-west-1.compute.internal" \
    "&statetype=2" \
    "&type=16" \
    "&noflapping=on" \
    "&nodowntime=on" \
    "&nosystem=on" \
    "&limit=0" \
    "&start=1"
  end

  def extract_from_css(css)
    lines = css.to_s.split(/<br clear="all">/)
    results = lines.map do |line|
      line.slice!(/\[.*/) unless line.include?("SOFT")
    end
    results.compact
  end

  def get_log_entries(url)
    puts "Fetching:", url
    page = Faraday.get(url).body
    html_doc = Nokogiri::HTML(page)
    html_doc.css("div[class='logEntries']")
  end

  def get_host_entries(url)
    puts "Fetching:", url
    page = Faraday.get(url).body
    html_doc = Nokogiri::HTML(page)
    html_doc.css("td[class='statusHOSTUP'] a")
  end
end

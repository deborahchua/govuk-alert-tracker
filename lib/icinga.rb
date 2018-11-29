require 'faraday'
require 'nokogiri'

Alert = Struct.new(:host, :date, :message)

class Icinga
  def alerts(host, start_date, end_date)
    url = build_url(host, start_date, end_date)
    css = get_log_entries(url)
    extract_from_css(css).map do |text|
      parse_alert(host, text)
    end
  end

private

  def parse_alert(host, text)
    date = text[1..10]
    message = text.slice(/;.*?(;)/)[1..-2]
    Alert.new(host, date, message)
  end

  def build_url(host, start_date, end_date)
    "https://alert.publishing.service.gov.uk/cgi-bin/icinga/history.cgi" \
    "?ts_start=#{start_date}" \
    "&ts_end=#{end_date}" \
    "&host=#{host}.publishing.service.gov.uk" \
    "&statetype=0" \
    "&type=16" \
    "&nosystem=on" \
    "&limit=1000" \
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
end

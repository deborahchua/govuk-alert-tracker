require 'google/apis/sheets_v4'
require 'googleauth'

class SpreadsheetPoster
  def initialize
    @sheets ||= Google::Apis::SheetsV4::SheetsService.new
    @sheets.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open('credentials.json'),
      scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS
    )
    @spreadsheet_id = "1lSs5Hbyiat3K8vLXTcttsnBWx9XBO5IC4q5kPQwz46k"
    @range = "Alerts per app over time!A2"

    @pending_rows = []
  end

  def append(row:)
    @pending_rows << row
    commit if @pending_rows.count >= 100
  end

  def commit
    puts "Comitting to spreadsheet..."
    save(@pending_rows)
    @pending_rows = []
  end

private

  def save(array)
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: array)
    @sheets.append_spreadsheet_value(@spreadsheet_id, @range, value_range, value_input_option: "RAW")
  end
end

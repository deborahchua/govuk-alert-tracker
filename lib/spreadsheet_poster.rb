require 'google/apis/sheets_v4'
require 'googleauth'
class SpreadsheetPoster
  def initialize
    @sheets ||= Google::Apis::SheetsV4::SheetsService.new
    # @sheets.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
    #   json_key_io: File.open('credentials.json'),
    #   scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS
    # )
    ENV["GOOGLE_ACCOUNT_TYPE"] = 'service_account'
    ENV["GOOGLE_CLIENT_EMAIL"] = 'govuk-alert-tracker@govuk-alert-tracker.iam.gserviceaccount.com'
    ENV["GOOGLE_PRIVATE_KEY"] = ""
    authorization = Google::Auth.get_application_default(Google::Apis::SheetsV4::AUTH_SPREADSHEETS)
    @sheets.authorization = authorization
    @spreadsheet_id = "15p__eJATWNQ11u98uGnNHte1PAfB0vJm5l3sdQcPUFg"
    @range = "Critical alerts per app over time!A2"
    @pending_rows = []
  end
  def append(row:)
    @pending_rows << row
    commit if @pending_rows.count >= 100
  end
  def commit
    puts "Comitting #{@pending_rows.count} to spreadsheet..."
    save(@pending_rows)
    @pending_rows = []
  end
private
  def save(array)
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: array)
    @sheets.append_spreadsheet_value(@spreadsheet_id, @range, value_range, value_input_option: "RAW")
  end
end

require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'date'
require 'fileutils'

OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
APPLICATION_NAME = "Nest Calendar Display".freeze
CREDENTIALS_PATH = "credentials.json".freeze
TOKEN_PATH = "token.yaml".freeze
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

class DateTime
  def start_of_day
    DateTime.new(self.year, self.month, self.day, 00, 00, 00, self.offset)
  end

  def end_of_day
    DateTime.new(self.year, self.month, self.day, 23, 59, 59, self.offset)
  end
end

class CalendarManager
  def initialize
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
  end

  def authorize
    client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
    token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
    authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
    user_id = "default"
    credentials = authorizer.get_credentials user_id
    if credentials.nil?
      url = authorizer.get_authorization_url base_url: OOB_URI
      puts "Open the following URL in the browser and enter the " \
           "resulting code after authorization:\n" + url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end

  def get_events(calendars: ["primary"], date: DateTime.now, one_day: true)
    events = []
    # if they don't ask for one day of events, return up to one year worth (max 10)
    time_end = one_day ? date.end_of_day.rfc3339 : (date.end_of_day + 365).rfc3339
    calendars.each do |calendar_id|
      response = @service.list_events(calendar_id,
                                     max_results:   10,
                                     single_events: true,
                                     order_by:      "startTime",
                                     time_min:      date.start_of_day.rfc3339,
                                     time_max:      time_end
                                     )
      response.items.each do |event|
        event_hash = {
          :name => event.summary,
          :start => event.start.date || event.start.date_time,
          :all_day => event.start.date_time ? false : true
        }
        events.push event_hash
      end
    end
  
    events.sort_by {|sort_hash| sort_hash[:start]}
  end
end


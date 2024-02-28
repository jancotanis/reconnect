require "wrapi"
require File.expand_path('weconnect/client', __dir__)
require File.expand_path('weconnect/version', __dir__)

module WeConnect
  extend WrAPI::Configuration
  extend WrAPI::RespondTo

  DEFAULT_UA = "Ruby WeConnect API client #{Tibber::VERSION}".freeze
  DEFAULT_ENDPOINT = 'https://api.weconnect.com/v1/'.freeze
  #
  # @return [Hudu::Client]
  def self.client(options = {})
    WeConnect::Client.new({ user_agent: DEFAULT_UA, endpoint: DEFAULT_ENDPOINT }.merge(options))
  end

  def self.reset
    super
    self.endpoint   = nil
    self.user_agent = DEFAULT_UA
    self.endpoint   = DEFAULT_ENDPOINT
  end
end

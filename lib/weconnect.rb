require "wrapi"
require File.expand_path('weconnect/client', __dir__)
require File.expand_path('weconnect/version', __dir__)

module WeConnect
  extend WrAPI::Configuration
  extend WrAPI::RespondTo

  #DEFAULT_UA = "Ruby WeConnect API client #{WeConnect::VERSION}".freeze
  DEFAULT_UA = 'WeConnect/3 CFNetwork/1331.0.7 Darwin/21.4.0'

  CARIAD_URL = 'https://emea.bff.cariad.digital'
  DEFAULT_ENDPOINT = 'https://emea.bff.cariad.digital/login/v1/idk/openid-configuration'.freeze
  #
  # @return [WeConnect::Client]
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

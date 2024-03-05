require "wrapi"
require File.expand_path('weconnect/client', __dir__)
require File.expand_path('weconnect/pagination', __dir__)
require File.expand_path('weconnect/version', __dir__)

module WeConnect
  extend WrAPI::Configuration
  extend WrAPI::RespondTo

  DEFAULT_UA = "WeConnect/3 CFNetwork/1331.0.7 Darwin/21.4.0 Ruby WeConnect Client #{WeConnect::VERSION}".freeze
  DEFAULT_ENDPOINT = 'https://emea.bff.cariad.digital/login/v1/idk/openid-configuration'.freeze
  #
  # @return [WeConnect::Client]
  def self.client(options = {})
    WeConnect::Client.new({ user_agent: DEFAULT_UA, endpoint: DEFAULT_ENDPOINT, pagination_class: RequestPagination::DefaultPager }.merge(options))
  end

  def self.reset
    super
    self.user_agent = DEFAULT_UA
    self.endpoint   = DEFAULT_ENDPOINT
    self.pagination_class = RequestPagination::DefaultPager
  end
end

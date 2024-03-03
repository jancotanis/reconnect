require 'faraday'
require 'faraday/follow_redirects'
require 'faraday-cookie_jar'

module WeConnect
  # Create connection including authorization parameters with default Accept format and User-Agent
  # By default
  # - Bearer authorization is access_token is not nil override with @setup_authorization
  # - Headers setup for client-id and client-secret when client_id and client_secret are not nil @setup_headers
  # @private
  module Connection
    private

    def connection
      raise ConfigurationError, "Option for endpoint is not defined" unless endpoint

      options = setup_options
      @connection ||= Faraday::Connection.new(options) do |connection|
#        connection.use Faraday::FollowRedirects::Middleware
        connection.use :cookie_jar

        connection.use Faraday::Response::RaiseError
        connection.adapter Faraday.default_adapter
        setup_authorization(connection)
        setup_headers(connection)
        connection.response :json, content_type: /\bjson$/
        connection.use Faraday::Request::UrlEncoded

        setup_logger_filtering(connection, logger) if logger
      end
    end

  end
end

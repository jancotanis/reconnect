require File.expand_path('api', __dir__)
require File.expand_path('const', __dir__)
require File.expand_path('error', __dir__)

module WeConnect
  # Wrapper for the WeConnect REST API
  #
  # @see no docs, reversed engineered
  class Client < API
    attr_accessor :openid_config

    def initialize(options = {})
      super(options)

      @openid_config = openid_configuration
    end

  private
    def openid_configuration
      get(self.endpoint)
    end
  end
end

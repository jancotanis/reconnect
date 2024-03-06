require 'uri'
require 'json'

module WeConnect
  # Defines HTTP request methods
  # required attributes format
  module RequestPagination

    # Defaut pages assumes all data retrieved in a single go.
    class DefaultPager < WrAPI::RequestPagination::DefaultPager

      def self.data(body)
        if body['data']
          body['data']
        else
          body
        end
      end
    end

  end
end

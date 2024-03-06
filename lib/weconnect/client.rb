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

    def vehicles(params={})
      self.get('/vehicle/v1/vehicles',params)
    end
    def vehicle_capability(vin,capability,param={})
      self.get("/vehicle/v1/vehicles/#{vin}/#{capability}")
    end
    def vehicle_status(vin, jobs='all')
      self.get("/vehicle/v1/vehicles/#{vin}/selectivestatus?jobs=#{jobs}")
    end

    def parking(vin)
      self.get("https://emea.bff.cariad.digital/vehicle/v1/vehicles/#{vin}/parkingposition")
    end

    def trips(vin,trip_type=TripType::SHORT_TERM,period)
      #/shortterm/last
      #/longterm/last
      sef.get('/vehicle/v1/trips/#{vin}/#{trip_type.downcase}/last',params)
    end

    def images(vin)
      self.get("/media/v2/vehicle-images/{self.vin.value}?resolution=2x")
    end



  private
    def openid_configuration
      get(self.endpoint)
    end
  end
end

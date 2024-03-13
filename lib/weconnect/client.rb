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
      self.get(vehicle_api,params)
    end
    def vehicle_status(vin, jobs=['all'])
      jobs = jobs.join(',') if jobs.is_a? Array
      self.get(vehicle_api(vin,"/selectivestatus?jobs=#{jobs}"))
    end

    def parking(vin)
      self.get(vehicle_api(vin,'/parkingposition'))
    end

    def trips(vin,trip_type=TripType::SHORT_TERM,period)
      sef.get('/vehicle/v1/trips/#{vin}/#{trip_type.downcase}/last',params)
    end

    def images(vin)
      self.get("/media/v2/vehicle-images/{self.vin.value}?resolution=2x")
    end

    def control(vin, operation, value)
      self.post(vehicle_api(vin,"/#{operation}/#{value}"))
    end
    def control_charging(vin, value)
      if ControlOperation.allowed_values.includes? value
        control(vin,'charging',value)
      end
    end
  private
    def openid_configuration
      get(self.endpoint)
    end

    PATH = "/vehicle/v1/vehicles".freeze
    def vehicle_api(vin=nil,path=nil)
      if vin
        File.join PATH, vin, path
       else
        PATH
       end
    end
  end
end

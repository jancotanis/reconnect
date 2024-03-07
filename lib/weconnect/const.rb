class String
  def underscore
    gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end
module WeConnect
  class Enum
      def self.enum(array, proc=:to_s)
        array.each do |c|
          const_set c.underscore.upcase,c.send(proc)
        end
      end
  end
  class Role < Enum
    enum %w[PRIMARY_USER SECONDARY_USER GUEST_USER CDIS_UNKNOWN_USER UNKNOWN]
  end

  class EnrollmentStatus < Enum
    enum %w[STARTED NOT_STARTED COMPLETED GDC_MISSING INACTIVE UNKNOWN]
  end
  class UserRoleStatus < Enum
    enum %w[ENABLED DISABLED_HMI DISABLED_SPIN DISABLED_PU_SPIN_RESET CDIS_UNKNOWN_USER UNKNOWN]
  end
  class Status
    UNKNOWN = 0

    DEACTIVATED = 1001
    INITIALLY_DISABLED = 1003
    DISABLED_BY_USER = 1004
    OFFLINE_MODE = 1005
    WORKSHOP_MODE = 1006
    MISSING_OPERATION = 1007
    MISSING_SERVICE = 1008
    PLAY_PROTECTION = 1009
    POWER_BUDGET_REACHED = 1010
    DEEP_SLEEP = 1011
    LOCATION_DATA_DISABLED = 1013

    LICENSE_INACTIVE = 2001
    LICENSE_EXPIRED = 2002
    MISSING_LICENSE = 2003

    USER_NOT_VERIFIED = 3001
    TERMS_AND_CONDITIONS_NOT_ACCEPTED = 3002
    INSUFFICIENT_RIGHTS = 3003
    CONSENT_MISSING = 3004
    LIMITED_FEATURE = 3005
    AUTH_APP_CERT_ERROR = 3006

    STATUS_UNSUPPORTED = 4001

    KNOWN_STATUS = self.constants.inject([]){|result,const| result << self.const_get(const)}
    def self.known_status? status
      KNOWN_STATUS.include? status
    end
  end

  class Badge < Enum
    enum %w[charging connected cooling heating locked parking unlocked ventilating warning]
  end

  class DevicePlatform < Enum
    enum %w[MBB MBB_ODP MBB_OFFLINE WCAR UNKNOWN]
  end

  class BrandCode
    N = 'N'
    V = 'V'
    UNKNOWN = 'unknown brand code'
  end
  class JobDomain < Enum
    enum %w[
      access activeventilation automation auxiliaryheating
      userCapabilities charging chargingProfiles batteryChargingCare
      climatisation climatisationTimers departureTimers
      fuelStatus vehicleLights lvBattery readiness
      vehicleHealthInspection vehicleHealthWarnings oilLevel
      measurements batterySupport
    ], :underscore
    JOB_DOMAINS = self.constants.inject([]){|result,const| result << self.const_get(const)}
  end
  class AllDomains < JobDomain
    enum %w[
      all allCapable parking trips
    ], :underscore
  end

  class TripType < Enum
    enum %w[shortTerm longTerm cyclic]
    UNKNOWN = 'unkown trip type'
  end

  class PlugConnectionState < Enum
    enum %w[connected disconnected invalid unsupported]
    UNKNOWN = 'unknown unlock plug state'
  end
     
  class PlugLockState < Enum
    enum %w[locked unlocked invalid unsupported]
    UNKNOWN = 'unknown unlock plug state'
  end

  class ExternalPower < Enum
    enum %w[ready active unavailable invalid unsupported]
    UNKNOWN = 'unknown external power'
  end

  class LedColor < Enum
    enum %w[nune green red]
    UNKNOWN = 'unknown plug led color'
  end
end

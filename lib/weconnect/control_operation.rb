require File.expand_path('const', __dir__)

module WeConnect
  module Control
    # all possible operations
    class Operation < Enum
      enum %w[start stop settings lock unlock flash, honkandflash, timers mode profiles unknown]
    end

    class ControlOperation < Enum
      enum %w[start stop none settings unknown]
     
      def self.allowed_values
        [START, STOP]
      end
    end

    class AccessControlOperation < Enum
      enum %w[lock unlock none unknown]
    end

    class HonkAndFlashControlOperation < Enum
      enum %w[flash honkandflash none unknown]
    end
  end
end

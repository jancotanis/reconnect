module WeConnect

  # Generic error to be able to rescue all WeConnect errors
  class WeConnectError < StandardError; end

  # configuration returns error
  class IncompatibleAPIError < WeConnectError; end

  # configuration returns error
  class ConfigurationError < WeConnectError; end

  # Issue authenticting
  class AuthenticationError < WeConnectError; end

end

require 'uri'
require 'yaml'
require 'nokogiri'
require File.expand_path('error', __dir__)

module WeConnect
  # Deals with authentication flow and stores it within global configuration
  module Authentication
    TOKENS = %w(state id_token access_token code)
    TOKEN_URL   = 'https://emea.bff.cariad.digital/user-login/login/v1'.freeze
    REFRESH_URL = 'https://emea.bff.cariad.digital/user-login/refresh/v1'.freeze

    # Authorize to the WeConnect portal
    def login(options = {})
      raise ConfigurationError, "username/password not set" unless username && password
      # only bearer token needed
      car = CarConnectInfo.new

      @tokens = WebLogin.new(self,car).login
      api_process_token(@tokens)
      reauth_connection(self.access_token)
      self.access_token
    end
    def auth_tokens
      @tokens
    end
    def api_process_token(tokens)
      self.access_token  = tokens['access_token']
      self.token_type    = tokens['token_type']
      self.refresh_token = tokens['refresh_token']
      self.token_expires = tokens['expires_at'] if tokens['expires_at']
    end

    def refresh_token
      raise Error.new 'not implemented'
    end

#  private
    class CarConnectInfo
    attr_reader :type, :country, :xrequest, :xclient_id, :client_id, :scope, :response_type, :redirect, :refresh_url
    	def initialize
    		@type = "Id";
    		@country = "DE";
    		@xrequest = "com.volkswagen.weconnect";
    		@xclientId = "";
        @client_id = "a24fba63-34b3-4d43-b181-942111e6bda8@apps_vw-dilab_com";

    		@scope = "openid profile badge cars dealers vin";
    		@response_type = "code id_token token";
        @redirect = "weconnect://authenticated";
        @refresh_url='https://identity.vwgroup.io/oidc/v1/token'
    	end
    end
    class WebLogin
      def initialize(connection,car_info)
        @connection = connection
        @car_info = car_info
      end
      def login
        @connection.format = 'x-www-form-urlencoded'
        page = login_page_step
        form = PasswordFormParser.new(page.body)
        page = email_page_step(form)
        idk = IDKParser.new(page.body)
        page = password_page_step(idk)

        raise IncompatibleAPIError.new( "#{@car_info.redirect} redirect not found" )
      rescue WeconnectAuthenticated => authenticated
        # weconnect://authenticatied#... extpected

        @tokens = query_parameters(URI.parse(authenticated.redirect).fragment)
        # fetch final tokens from login
        @tokens = fetch_tokens(@tokens)
      end
    private
      def login_page_step
        params = {
          nonce: nonce(),
          redirect_uri: @car_info.redirect
        }
        r = @connection.get('https://emea.bff.cariad.digital/user-login/v1/authorize',params,true)
        @login_url = r.env.url
        r
      end

      def email_page_step(form)
        fields = form.fields
        fields['email'] = @connection.username
        # update to login form
        @login_url = URI.join(@login_url, form.action)
        r = @connection.post(@login_url.to_s,fields,true) do |request|
              request.headers=request.headers.merge({
                'x-requested-with': @car_info.xrequest,
                'upgrade-insecure-requests': "1"
              })
        end
      end
      def password_page_step(idk)
        params = {
          :email => @connection.username,
          :password => @connection.password,
          idk.idk['csrf_parameterName'] => idk.idk['csrf_token'],
          :hmac => idk.template_model['hmac'],
          'relayState' => idk.template_model['relayState']
        }

        rpw = @connection.post(idk.post_action_uri(@login_url),params,true) do |request|
              request.headers=request.headers.merge({
                'x-requested-with': @car_info.xrequest,
                'upgrade-insecure-requests': "1"
              })
        end
        # should not come here, exception raised by auth redirect
        if rpw.env.url.query['login.error']
          params  = query_parameters(rpw.env.url.query)
          description = {
            'login.errors.password_invalid': 'Password is invalid',
            'login.error.throttled': 'Login throttled, probably too many wrong logins. You have to wait some minutes until a new login attempt is possible'
          }
          error = params['error']
          error = description[error] if description[error]
          raise AuthenticationError.new( "Login error #{error}" )
        end
      end

      def fetch_tokens(tokens)
        # check if all keys exist
        if TOKENS.all? { |s| tokens.key? s }
          params = {
            'state': tokens['state'],
            'id_token': tokens['id_token'],
            'redirect_uri': @car_info.redirect,
            'region': 'emea',
            'access_token': tokens['access_token'],
            'authorizationCode': tokens['code'],
          }

          @connection.format = :json
          @connection.reauth_connection(tokens['id_token'])
          # complete set tokens
          token_response = @connection.post(TOKEN_URL, params)
          # translate token names to _token suffix
          token_response = translate_tokens(token_response.body, %w(accessToken idToken refreshToken))
          token_response = parse_token_response(token_response)
          token_response
        else
          raise IncompatibleAPIError.new( 'Expected tokens: #{TOKENS}, but found: #{tokens}' )
        end
      end

      def translate_tokens(tokens, keys)
        keys.each do |name|
          if tokens[name]
            tokens[name.gsub('Token', '_token')] = tokens.delete(name)
          end
        end
        tokens
      end
      # oauthlib/oauth2/rfc6749/parameters.py
      def parse_token_response(tokens)
puts "\n\nEXPIRE #{tokens['expires_in']}\n\n"
        tokens['expires_at'] = Time.new() + tokens['expires_in'] if tokens['expires_in']
        # validate
        raise AuthenticationError.new(tokens['error']) if tokens['error']
        #raise AuthenticationError.new('Missing access token error') if tokens['access_token']

        tokens
      end

      def query_parameters(query_fragment)
        parameters = query_fragment.split('&').inject({}) do |result,param|
          k,v = param.split('=');
          result.merge({k => v })
        end
      end

      def nonce
       rand(10 ** 30).to_s.rjust(30,'0')
      end

    end

    class PasswordFormParser
      attr_reader :action, :method, :fields
      def initialize(html)
        doc = Nokogiri::HTML( html )
        # 1 loginform username
        form = doc/'form[name="emailPasswordForm"]'
        if form
          @action = form.attribute('action').to_s
          @method = form.attribute('method').to_s
          # get hidden fields

          @fields = {}
          (form/'input').each do |input|
            @fields[input.attribute('name').to_s] = input.attribute('value').to_s
          end
        else
          raise IncompatibleAPIError.new( 'emailPasswordForm not found' )
        end
      end
    end

    class IDKParser
      attr_reader :idk, :template_model, :post_action, :identifier, :error
      def initialize(html)
        doc = Nokogiri::HTML( html )
        # get script with IDK
        scripts = doc./'script:contains("_IDK")'
        # extract json part by greedy match till last '}'
        m = scripts.text.gsub("\n",'').gsub(/([\w]+):/, '"\1":').match('({.*})')
        @idk = {}
        if m.size > 1
          # load with yam due to single quotes
          @idk = YAML.load(m[1])
          raise IncompatibleAPIError.new( "_IDK.templateModel not found #{@idk}" ) unless @idk['templateModel']
        else
          raise IncompatibleAPIError.new( "_IDK not found" )
        end
        # r = self.__get_url(upr.scheme+'://'+upr.netloc+form_url.replace(idk['templateModel']['identifierUrl'],idk['templateModel']['postAction']), post=post)
        @template_model = @idk['templateModel']
        @post_action = @template_model['postAction']
        @identifier = @template_model['identifierUrl']
        @error = @template_model['error']
      end

      def post_action_uri(base_uri)
        base_uri.to_s.gsub(@identifier,@post_action)
      end
    end
  end
end

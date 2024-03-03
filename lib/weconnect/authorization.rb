require 'uri'
require 'cgi'
require 'nokogiri'
require File.expand_path('error', __dir__)

module WeConnect
  # Deals with authentication flow and stores it within global configuration
  module Authentication

    # Authorize to the WeConnect portal
    def login(options = {})
      raise ConfigurationError, "username/password not set" unless username && password
      # only bearer token needed
      WebLogin.new(self,CarConnectInfo.new).login
    end
#  private
    class CarConnectInfo
    attr_reader :type, :country, :xrequest, :xclient_id, :client_id, :scope, :response_type, :redirect, :xappversion, :xappname
    	def initialize
    		@type = "Id";
    		@country = "DE";
    		@xrequest = "com.volkswagen.weconnect";
    		@xclientId = "";
        @client_id = "a24fba63-34b3-4d43-b181-942111e6bda8@apps_vw-dilab_com";

    		@scope = "openid profile badge cars dealers vin";
    		@response_type = "code id_token token";
        @redirect = "weconnect://authenticated";
        @refresh_url='https://identity.vwgroup.io/oidc/v1/token',

    		@xappversion = "";
    		@xappname = "";

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
      rescue RedirectAuthenticated => authenticated
        # weconnect://authenticatied#... extpected
        tokens = CGI.parse(URI.parse(authenticated.redirect).fragment)
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
        r = eat(r)
      end
      def password_page_step(idk)
        params = {
          :email => @connection.username,
          :password => @connection.password,
          idk.idk['csrf_parameterName'] => idk.idk['csrf_token'],
          :hmac => idk.template_model['hmac'],
          'relayState' => idk.template_model['relayState']
        }


        puts "*** form action #{@login_url} action= #{idk.post_action} => #{idk.post_action_uri(@login_url)}"
        rpw = @connection.post(idk.post_action_uri(@login_url),params,true) do |request|

              request.headers=request.headers.merge({
    #            "Content-Type": "application/x-www-form-urlencoded",
    #            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
                'x-requested-with': @car_info.xrequest,
                'upgrade-insecure-requests': "1"
              })
        end
        rpw = eat(rpw)
      end
      def eat(response)
        while response.status >=300 && response.status < 400 do
          url = response['location']
          # add host if not present
          unless url['https:']
            break if url[@car_info.redirect]
            originates = response.env.url
            url = originates.scheme + "://" + originates.host + url
          end
puts "* eat: "+url
          response = @connection.get(url, nil, true) do |request|
            request.headers['x-requested-with'] = @car_info.xrequest
          end
        end
        response
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
        @error =   @template_model['error']
      end

      def post_action_uri(base_uri)
        base_uri.to_s.gsub(@identifier,@post_action)
      end
    end
  end
end

$LOAD_PATH.unshift File.expand_path("../wrapi/lib", __dir__)

require 'securerandom'
require 'digest'
require 'base64'

require 'uri'
require 'json'
require 'nokogiri'
require './lib/weconnect.rb'
require 'logger'
require 'yaml'
require 'dotenv'

Dotenv.load

def token_hex(len)
  o = [('0'..'9'),('A'..'F')].map(&:to_a).flatten
  (1..len).map{o[rand(o.length)]}.join
end
def trace_id
  trace = token_hex(32)
  trace[0..7] + '-' + trace[8..11] + '-' + trace[12..15] + '-' + trace[16..19] + '-' + trace[20..trace.length]
end

class CarConnectInfo
attr_reader :type, :country, :xrequest, :xclient_id, :client_id, :scope, :response_type, :redirect, :xappversion, :xappname
	def initialize
		@type = "Id";
		@country = "DE";
		@xrequest = "com.volkswagen.weconnect";
#    @xrequest = "de.volkswagen.carnet.eu.eremote"
		@xclientId = "";
    @client_id = "a24fba63-34b3-4d43-b181-942111e6bda8@apps_vw-dilab_com";

		@scope = "openid profile badge cars dealers vin";
		@response_type = "code id_token token";
    @redirect = "weconnect://authenticated";
    @refresh_url='https://identity.vwgroup.io/oidc/v1/token',

		@xappversion = "";
		@xappname = "";

	end
 def nonce
	#SecureRandom.base64
  rand(10 ** 30).to_s.rjust(30,'0')
 end
 #base64URLEncode
 def urlsafe_base64(base64_str)
   base64_str.tr("+/", "-_").tr("=", "")
 end
 def random_string(len)
  o = [('a'..'z'), ('A'..'Z'),('0'..'9')].map(&:to_a).flatten << '-'
  (1..len).map{o[rand(o.length)]}.join
 end
 def code_challenge
  code_verifier = Base64.encode64(random_string)
  # -> "U2VuZCByZWluZm9yY2VtZW50cw==\n"
  urlsafe_base64(Digest::SHA256.base64digest(code_verifier))
 end

	def login_url(connection = nil)
    if !@_login_url
      params = {
        nonce: nonce(),
        redirect_uri: @redirect
      }

      r = connection.get('https://emea.bff.cariad.digital/user-login/v1/authorize',params,true) do |request|
        request.headers['user-agent'] = 'WeConnect/3 CFNetwork/1331.0.7 Darwin/21.4.0'
#        request.headers['weconnect-trace-id'] = trace_id
      end

#      @_login_url = r.env.url

      if r.status == 303 #redirect
        @_login_url = r['location']
      else
        raise Error.new 'redirect expected ' + r.to_s
      end
    else
      @_login_url
    end
	end
end


def eat( connection, response, id3 )
  while response.status >=300 && response.status < 400 do
    url = response['location']
    unless url['https:']
      break if url[id3.redirect]
      originates = response.env.url
      url = originates.scheme + "://" + originates.host + url
    end
puts "* eat: "+url
    response = connection.get(url, nil, true) do |request|
#      request.headers['user-agent']= 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/74.0.3729.185 Mobile Safari/537.36'
      request.headers['x-requested-with'] = id3.xrequest
    end
  end
  response
end



File.delete('snippets1.log') if File.exist?('snippets1.log')
logger=Logger.new('snippets1.log')

id3 = CarConnectInfo.new
c = WeConnect.client({ logger: logger, username: ENV['WECONNECT_USERNAME'], password: ENV['WECONNECT_PASSWORD']})

_params = {
    client_id: id3.client_id,
    redirect_uri: id3.redirect,
    response_type: id3.response_type,
    scope: id3.scope,
    nonce: id3.nonce(),
    state: SecureRandom.uuid
    }


  # 2
  url = id3.login_url(c)
  r = nil
  loop do
    r = c.get(url, {}, true) do |request|
#      request.headers['user-agent']= 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/74.0.3729.185 Mobile Safari/537.36'
      request.headers['x-requested-with'] = id3.xrequest
    end
    break unless r.status >=300 && r.status < 400
    url = r['location']
  end


if r.status >= 200
=begin
  doc = Nokogiri::HTML( r.body )
  # 1 loginform username
  form = doc/'form[name="emailPasswordForm"]'
  action = form.attribute('action').to_s
  method = form.attribute('method').to_s
puts "form action #{method} #{action}"
  fields = {}
  (form/'input').each do |input|
    fields[input.attribute('name').to_s] = input.attribute('value').to_s
  end
=end
  form = WeConnect::Authentication::PasswordFormParser.new(r.body)
  fields = form.fields
  fields['email'] = c.username
  uri = URI.join(id3.login_url(c), form.action)
logger.info("** posting url=#{uri} + action #{form.action}")

  e = nil

  begin
    c.format = 'x-www-form-urlencoded'
    rpw = c.post(uri.to_s,fields,true) do |request|
          request.headers=request.headers.merge({
#            'user-agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/74.0.3729.185 Mobile Safari/537.36',
#            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
            'x-requested-with': id3.xrequest,
            'upgrade-insecure-requests': "1"
          })
    end
    r = eat(c, rpw, id3)
=begin
    doc = Nokogiri::HTML( r.body )
    # get script with IDK
    scripts = doc./'script:contains("_IDK")'
    # extract json part by greedy match till last '}'
    m = scripts.text.gsub("\n",'').gsub(/([\w]+):/, '"\1":').match('({.*})')
    idk = {}
    if m.size > 1
      # load with yam due to single quotes
      idk = YAML.load(m[1])
      raise "Incompatible api/idk #{idk}" unless idk['templateModel']
    else
      raise 'Incompatible api'
    end
    # r = self.__get_url(upr.scheme+'://'+upr.netloc+form_url.replace(idk['templateModel']['identifierUrl'],idk['templateModel']['postAction']), post=post)
    template_model = idk['templateModel']

    post_action = template_model['postAction']
    identifier = template_model['identifierUrl']

    error =   template_model['error']
=end
    idk = WeConnect::Authentication::IDKParser.new(r.body)
    params = {
      :email => c.username,
      :password => c.password,
      idk.idk['csrf_parameterName'] => idk.idk['csrf_token'],
      :hmac => idk.template_model['hmac'],
      'relayState' => idk.template_model['relayState']
    }
puts "*** form action #{uri} action= #{idk.post_action} => #{idk.post_action_uri(uri.to_s)}"
    c.format = 'x-www-form-urlencoded'
    rpw = c.post(idk.post_action_uri(uri.to_s),params,true) do |request|
#      rpw = c.post(uri.to_s.gsub(identifier,post_action),params,true) do |request|
          request.headers=request.headers.merge({
#            "Content-Type": "application/x-www-form-urlencoded",
#            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
            'x-requested-with': id3.xrequest,
            'upgrade-insecure-requests': "1"
          })
    end
    rpw = eat(c, rpw, id3)
    puts "yippe hi heeee #{rpw['location']}" if rpw['location']
puts "where here..."
#  rescue => e
#    puts e.inspect
  end


end

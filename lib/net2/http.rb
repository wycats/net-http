#
# = net/http.rb
#
# Copyright (c) 1999-2007 Yukihiro Matsumoto
# Copyright (c) 1999-2007 Minero Aoki
# Copyright (c) 2001 GOTOU Yuuzou
#
# Written and maintained by Minero Aoki <aamine@loveruby.net>.
# HTTPS support added by GOTOU Yuuzou <gotoyuzo@notwork.org>.
#
# This file is derived from "http-access.rb".
#
# Documented by Minero Aoki; converted to RDoc by William Webber.
#
# This program is free software. You can re-distribute and/or
# modify this program under the same terms of ruby itself ---
# Ruby Distribution License or GNU General Public License.
#
# See Net::HTTP for an overview and examples.
#

require 'net2/protocol'
autoload :OpenSSL, 'openssl'
require 'uri'
autoload :SecureRandom, 'securerandom'

if RUBY_VERSION < "1.9"
  require "net2/backports"
end

module URI
  class Generic
    unless URI::Generic.allocate.respond_to?(:hostname)
      def hostname
        v = self.host
        /\A\[(.*)\]\z/ =~ v ? $1 : v
      end
    end
  end
end

module Net2   #:nodoc:

  # :stopdoc:
  class HTTPBadResponse < StandardError; end
  class HTTPHeaderSyntaxError < StandardError; end
  # :startdoc:

  # == An HTTP client API for Ruby.
  #
  # Net::HTTP provides a rich library which can be used to build HTTP
  # user-agents.  For more details about HTTP see
  # [RFC2616](http://www.ietf.org/rfc/rfc2616.txt)
  #
  # Net::HTTP is designed to work closely with URI.  URI::HTTP#host,
  # URI::HTTP#port and URI::HTTP#request_uri are designed to work with
  # Net::HTTP.
  #
  # If you are only performing a few GET requests you should try OpenURI.
  #
  # == Simple Examples
  #
  # All examples assume you have loaded Net::HTTP with:
  #
  #   require 'net/http'
  #
  # This will also require 'uri' so you don't need to require it separately.
  #
  # The Net::HTTP methods in the following section do not persist
  # connections.  They are not recommended if you are performing many HTTP
  # requests.
  #
  # === GET
  #
  #   Net::HTTP.get('example.com', '/index.html') # => String
  #
  # === GET by URI
  #
  #   uri = URI('http://example.com/index.html?count=10')
  #   Net::HTTP.get(uri) # => String
  #
  # === GET with Dynamic Parameters
  #
  #   uri = URI('http://example.com/index.html')
  #   params = { :limit => 10, :page => 3 }
  #   uri.query = URI.encode_www_form(params)
  #
  #   res = Net::HTTP.get_response(uri)
  #   puts res.body if res.is_a?(Net::HTTPSuccess)
  #
  # === POST
  #
  #   uri = URI('http://www.example.com/search.cgi')
  #   res = Net::HTTP.post_form(uri, 'q' => 'ruby', 'max' => '50')
  #   puts res.body
  #
  # === POST with Multiple Values
  #
  #   uri = URI('http://www.example.com/search.cgi')
  #   res = Net::HTTP.post_form(uri, 'q' => ['ruby', 'perl'], 'max' => '50')
  #   puts res.body
  #
  # == How to use Net::HTTP
  #
  # The following example code can be used as the basis of a HTTP user-agent
  # which can perform a variety of request types using persistent
  # connections.
  #
  #   uri = URI('http://example.com/some_path?query=string')
  #
  #   Net::HTTP.start(uri.host, uri.port) do |http|
  #     request = Net::HTTP::Get.new uri.request_uri
  #
  #     response = http.request request # Net::HTTPResponse object
  #   end
  #
  # Net::HTTP::start immediately creates a connection to an HTTP server which
  # is kept open for the duration of the block.  The connection will remain
  # open for multiple requests in the block if the server indicates it
  # supports persistent connections.
  #
  # The request types Net::HTTP supports are listed below in the section "HTTP
  # Request Classes".
  #
  # If you wish to re-use a connection across multiple HTTP requests without
  # automatically closing it you can use ::new instead of ::start.  #request
  # will automatically open a connection to the server if one is not currently
  # open.  You can manually close the connection with #close.
  #
  # === Response Data
  #
  #   uri = URI('http://example.com/index.html')
  #   res = Net::HTTP.get_response(uri)
  #
  #   # Headers
  #   res['Set-Cookie']            # => String
  #   res.get_fields('set-cookie') # => Array
  #   res.to_hash['set-cookie']    # => Array
  #   puts "Headers: #{res.to_hash.inspect}"
  #
  #   # Status
  #   puts res.code       # => '200'
  #   puts res.message    # => 'OK'
  #   puts res.class.name # => 'HTTPOK'
  #
  #   # Body
  #   puts res.body if res.response_body_permitted?
  #
  # === Following Redirection
  #
  # Each Net::HTTPResponse object belongs to a class for its response code.
  #
  # For example, all 2XX responses are instances of a Net::HTTPSuccess
  # subclass, a 3XX response is an instance of a Net::HTTPRedirection
  # subclass and a 200 response is an instance of the Net::HTTPOK class.  For
  # details of response classes, see the section "HTTP Response Classes"
  # below.
  #
  # Using a case statement you can handle various types of responses properly:
  #
  #   def fetch(uri_str, limit = 10)
  #     # You should choose a better exception.
  #     raise ArgumentError, 'too many HTTP redirects' if limit == 0
  #
  #     response = Net::HTTP.get_response(URI(uri_str))
  #
  #     case response
  #     when Net::HTTPSuccess then
  #       response
  #     when Net::HTTPRedirection then
  #       location = response['location']
  #       warn "redirected to #{location}"
  #       fetch(location, limit - 1)
  #     else
  #       response.value
  #     end
  #   end
  #
  #   print fetch('http://www.ruby-lang.org')
  #
  # === POST
  #
  # A POST can be made using the Net::HTTP::Post request class.  This example
  # creates a urlencoded POST body:
  #
  #   uri = URI('http://www.example.com/todo.cgi')
  #   req = Net::HTTP::Post.new(uri.path)
  #   req.set_form_data('from' => '2005-01-01', 'to' => '2005-03-31')
  #
  #   res = Net::HTTP.start(uri.hostname, uri.port) do |http|
  #     http.request(req)
  #   end
  #
  #   case res
  #   when Net::HTTPSuccess, Net::HTTPRedirection
  #     # OK
  #   else
  #     res.value
  #   end
  #
  # At this time Net::HTTP does not support multipart/form-data.  To send
  # multipart/form-data use Net::HTTPRequest#body= and
  # Net::HTTPRequest#content_type=:
  #
  #   req = Net::HTTP::Post.new(uri.path)
  #   req.body = multipart_data
  #   req.content_type = 'multipart/form-data'
  #
  # Other requests that can contain a body such as PUT can be created in the
  # same way using the corresponding request class (Net::HTTP::Put).
  #
  # === Setting Headers
  #
  # The following example performs a conditional GET using the
  # If-Modified-Since header.  If the files has not been modified since the
  # time in the header a Not Modified response will be returned.  See RFC 2616
  # section 9.3 for further details.
  #
  #   uri = URI('http://example.com/cached_response')
  #   file = File.stat 'cached_response'
  #
  #   req = Net::HTTP::Get.new(uri.request_uri)
  #   req['If-Modified-Since'] = file.mtime.rfc2822
  #
  #   res = Net::HTTP.start(uri.hostname, uri.port) {|http|
  #     http.request(req)
  #   }
  #
  #   open 'cached_response', 'w' do |io|
  #     io.write res.body
  #   end if res.is_a?(Net::HTTPSuccess)
  #
  # === Basic Authentication
  #
  # Basic authentication is performed according to
  # [RFC2617](http://www.ietf.org/rfc/rfc2617.txt)
  #
  #   uri = URI('http://example.com/index.html?key=value')
  #
  #   req = Net::HTTP::Get.new(uri.request_uri)
  #   req.basic_auth 'user', 'pass'
  #
  #   res = Net::HTTP.start(uri.hostname, uri.port) {|http|
  #     http.request(req)
  #   }
  #   puts res.body
  #
  # === Streaming Response Bodies
  #
  # By default Net::HTTP reads an entire response into memory.  If you are
  # handling large files or wish to implement a progress bar you can instead
  # stream the body directly to an IO.
  #
  #   uri = URI('http://example.com/large_file')
  #
  #   Net::HTTP.start(uri.host, uri.port) do |http|
  #     request = Net::HTTP::Get.new uri.request_uri
  #
  #     http.request request do |response|
  #       open 'large_file', 'w' do |io|
  #         response.read_body do |chunk|
  #           io.write chunk
  #         end
  #       end
  #     end
  #   end
  #
  # === HTTPS
  #
  # HTTPS is enabled for an HTTP connection by Net::HTTP#use_ssl=.
  #
  #   uri = URI('https://secure.example.com/some_path?query=string')
  #
  #   Net::HTTP.start(uri.host, uri.port,
  #     :use_ssl => uri.scheme == 'https').start do |http|
  #     request = Net::HTTP::Get.new uri.request_uri
  #
  #     response = http.request request # Net::HTTPResponse object
  #   end
  #
  # In previous versions of ruby you would need to require 'net/https' to use
  # HTTPS.  This is no longer true.
  #
  # === Proxies
  #
  # Net::HTTP::Proxy has the same methods as Net::HTTP but its instances always
  # connect via the proxy instead of directly to the given host.
  #
  #   proxy_addr = 'your.proxy.host'
  #   proxy_port = 8080
  #
  #   Net::HTTP::Proxy(proxy_addr, proxy_port).start('www.example.com') {|http|
  #     # always connect to your.proxy.addr:8080
  #   }
  #
  # Net::HTTP::Proxy returns a Net::HTTP instance when proxy_addr is nil so
  # there is no need for conditional code.
  #
  # See Net::HTTP::Proxy for further details and examples such as proxies that
  # require a username and password.
  #
  # == HTTP Request Classes
  #
  # Here is the HTTP request class hierarchy.
  #
  # * Net::HTTPRequest
  #   * Net::HTTP::Get
  #   * Net::HTTP::Head
  #   * Net::HTTP::Post
  #   * Net::HTTP::Put
  #   * Net::HTTP::Proppatch
  #   * Net::HTTP::Lock
  #   * Net::HTTP::Unlock
  #   * Net::HTTP::Options
  #   * Net::HTTP::Propfind
  #   * Net::HTTP::Delete
  #   * Net::HTTP::Move
  #   * Net::HTTP::Copy
  #   * Net::HTTP::Mkcol
  #   * Net::HTTP::Trace
  #
  # == HTTP Response Classes
  #
  # Here is HTTP response class hierarchy.  All classes are defined in Net
  # module and are subclasses of Net::HTTPResponse.
  #
  # HTTPUnknownResponse:: For unhandled HTTP extenensions
  # HTTPInformation::                    1xx
  #   HTTPContinue::                        100
  #   HTTPSwitchProtocol::                  101
  # HTTPSuccess::                        2xx
  #   HTTPOK::                              200
  #   HTTPCreated::                         201
  #   HTTPAccepted::                        202
  #   HTTPNonAuthoritativeInformation::     203
  #   HTTPNoContent::                       204
  #   HTTPResetContent::                    205
  #   HTTPPartialContent::                  206
  # HTTPRedirection::                    3xx
  #   HTTPMultipleChoice::                  300
  #   HTTPMovedPermanently::                301
  #   HTTPFound::                           302
  #   HTTPSeeOther::                        303
  #   HTTPNotModified::                     304
  #   HTTPUseProxy::                        305
  #   HTTPTemporaryRedirect::               307
  # HTTPClientError::                    4xx
  #   HTTPBadRequest::                      400
  #   HTTPUnauthorized::                    401
  #   HTTPPaymentRequired::                 402
  #   HTTPForbidden::                       403
  #   HTTPNotFound::                        404
  #   HTTPMethodNotAllowed::                405
  #   HTTPNotAcceptable::                   406
  #   HTTPProxyAuthenticationRequired::     407
  #   HTTPRequestTimeOut::                  408
  #   HTTPConflict::                        409
  #   HTTPGone::                            410
  #   HTTPLengthRequired::                  411
  #   HTTPPreconditionFailed::              412
  #   HTTPRequestEntityTooLarge::           413
  #   HTTPRequestURITooLong::               414
  #   HTTPUnsupportedMediaType::            415
  #   HTTPRequestedRangeNotSatisfiable::    416
  #   HTTPExpectationFailed::               417
  # HTTPServerError::                    5xx
  #   HTTPInternalServerError::             500
  #   HTTPNotImplemented::                  501
  #   HTTPBadGateway::                      502
  #   HTTPServiceUnavailable::              503
  #   HTTPGatewayTimeOut::                  504
  #   HTTPVersionNotSupported::             505
  #
  # There is also the Net::HTTPBadResponse exception which is raised when
  # there is a protocol error.
  #
  class HTTP < Protocol

    # :stopdoc:
    Revision = %q$Revision$.split[1]
    HTTPVersion = '1.1'
    begin
      require 'zlib'
      require 'stringio'  #for our purposes (unpacking gzip) lump these together
      HAVE_ZLIB=true
    rescue LoadError
      HAVE_ZLIB=false
    end
    # :startdoc:

    # Turns on net/http 1.2 (ruby 1.8) features.
    # Defaults to ON in ruby 1.8 or later.
    def HTTP.version_1_2
      true
    end

    # Returns true if net/http is in version 1.2 mode.
    # Defaults to true.
    def HTTP.version_1_2?
      true
    end

    # :nodoc:
    def HTTP.version_1_1?
      false
    end

    class << self
      alias is_version_1_1? version_1_1?   #:nodoc:
      alias is_version_1_2? version_1_2?   #:nodoc:
    end

    #
    # short cut methods
    #

    #
    # Gets the body text from the target and outputs it to $stdout.  The
    # target can either be specified as
    # (+uri+), or as (+host+, +path+, +port+ = 80); so:
    #
    #    Net::HTTP.get_print URI('http://www.example.com/index.html')
    #
    # or:
    #
    #    Net::HTTP.get_print 'www.example.com', '/index.html'
    #
    def self.get_print(uri_or_host, path = nil, port = nil)
      get_response(uri_or_host, path, port) do |res|
        res.read_body do |chunk|
          $stdout.print chunk
        end
        res.close
      end
      nil
    end

    # Sends a GET request to the target and returns the HTTP response
    # as a string.  The target can either be specified as
    # (+uri+), or as (+host+, +path+, +port+ = 80); so:
    #
    #    print Net::HTTP.get(URI('http://www.example.com/index.html'))
    #
    # or:
    #
    #    print Net::HTTP.get('www.example.com', '/index.html')
    #
    def self.get(uri_or_host, path = nil, port = nil)
      get_response(uri_or_host, path, port) do |response|
        return response.body
      end
    end

    # Sends a GET request to the target and returns the HTTP response
    # as a Net::HTTPResponse object.  The target can either be specified as
    # (+uri+), or as (+host+, +path+, +port+ = 80); so:
    #
    #    res = Net::HTTP.get_response(URI('http://www.example.com/index.html'))
    #    print res.body
    #
    # or:
    #
    #    res = Net::HTTP.get_response('www.example.com', '/index.html')
    #    print res.body
    #
    def self.get_response(uri_or_host, path = nil, port = nil, &block)
      if uri_or_host.respond_to?(:hostname)
        host = uri_or_host.hostname
        port = uri_or_host.port
        path = uri_or_host.request_uri
      elsif path
        host = uri_or_host
      else
        uri = URI.parse(uri_or_host)
        return get_response(uri, &block)
      end

      http = new(host, port || HTTP.default_port).start
      http.request_get(path, &block)
    end

    # Posts HTML form data to the specified URI object.
    # The form data must be provided as a Hash mapping from String to String.
    # Example:
    #
    #   { "cmd" => "search", "q" => "ruby", "max" => "50" }
    #
    # This method also does Basic Authentication iff +url+.user exists.
    # But userinfo for authentication is deprecated (RFC3986).
    # So this feature will be removed.
    #
    # Example:
    #
    #   require 'net/http'
    #   require 'uri'
    #
    #   HTTP.post_form URI('http://www.example.com/search.cgi'),
    #                  { "q" => "ruby", "max" => "50" }
    #
    def self.post_form(url, params)
      req = Post.new(url.path)
      req.form_data = params
      req.basic_auth url.user, url.password if url.user
      new(url.host, url.port).start do |http|
        response = http.request(req)

        # we're using the block form, so make sure to read the
        # body before the socket is closed.
        response.close
        response
      end
    end

    #
    # HTTP session management
    #

    # The default port to use for HTTP requests; defaults to 80.
    def self.default_port
      http_default_port()
    end

    # The default port to use for HTTP requests; defaults to 80.
    def self.http_default_port
      80
    end

    # The default port to use for HTTPS requests; defaults to 443.
    def self.https_default_port
      443
    end

    def self.socket_type   #:nodoc: obsolete
      BufferedIO
    end

    # call-seq:
    #   HTTP.start(address, port, p_addr, p_port, p_user, p_pass, &block)
    #   HTTP.start(address, port=nil, p_addr=nil, p_port=nil, p_user=nil, p_pass=nil, opt, &block)
    #
    # Creates a new Net::HTTP object, then additionally opens the TCP
    # connection and HTTP session.
    #
    # Argments are following:
    # _address_ :: hostname or IP address of the server
    # _port_    :: port of the server
    # _p_addr_  :: address of proxy
    # _p_port_  :: port of proxy
    # _p_user_  :: user of proxy
    # _p_pass_  :: pass of proxy
    # _opt_     :: optional hash
    #
    # _opt_ sets following values by its accessor.
    # The keys are ca_file, ca_path, cert, cert_store, ciphers,
    # close_on_empty_response, key, open_timeout, read_timeout, ssl_timeout,
    # ssl_version, use_ssl, verify_callback, verify_depth and verify_mode.
    # If you set :use_ssl as true, you can use https and default value of
    # verify_mode is set as OpenSSL::SSL::VERIFY_PEER.
    #
    # If the optional block is given, the newly
    # created Net::HTTP object is passed to it and closed when the
    # block finishes.  In this case, the return value of this method
    # is the return value of the block.  If no block is given, the
    # return value of this method is the newly created Net::HTTP object
    # itself, and the caller is responsible for closing it upon completion
    # using the finish() method.
    def self.start(address, *arg, &block) # :yield: +http+
      arg.pop if opt = Hash.try_convert(arg[-1])
      port, p_addr, p_port, p_user, p_pass = *arg
      port = https_default_port if !port && opt && opt[:use_ssl]
      http = new(address, port, p_addr, p_port, p_user, p_pass)

      if opt
        opt = {:verify_mode => OpenSSL::SSL::VERIFY_PEER}.update(opt) if opt[:use_ssl]
        http.methods.grep(/\A(\w+)=\z/) do |meth|
          key = $1.to_sym
          opt.key?(key) or next
          http.__send__(meth, opt[key])
        end
      end

      http.start(&block)
    end

    class << self
      alias newobj new
    end

    # Creates a new Net::HTTP object without opening a TCP connection or
    # HTTP session.
    # The +address+ should be a DNS hostname or IP address.
    # If +p_addr+ is given, creates a Net::HTTP object with proxy support.
    def self.new(address, port = nil, p_addr = nil, p_port = nil, p_user = nil, p_pass = nil)
      Proxy(p_addr, p_port, p_user, p_pass).newobj(address, port)
    end

    # Creates a new Net::HTTP object for the specified server address,
    # without opening the TCP connection or initializing the HTTP session.
    # The +address+ should be a DNS hostname or IP address.
    def initialize(address, port = nil)
      @address = address
      @port    = (port || HTTP.default_port)
      @curr_http_version = HTTPVersion
      @no_keepalive_server = false
      @close_on_empty_response = false
      @socket  = nil
      @started = false
      @open_timeout = nil
      @read_timeout = 60
      @debug_output = nil
      @use_ssl = false
      @ssl_context = nil
      @enable_post_connection_check = true
      @compression = nil
      @sspi_enabled = false
      if defined?(SSL_ATTRIBUTES)
        SSL_ATTRIBUTES.each do |name|
          instance_variable_set "@#{name}", nil
        end
      end
    end

    def inspect
      "#<#{self.class} #{@address}:#{@port} open=#{started?}>"
    end

    # *WARNING* This method opens a serious security hole.
    # Never use this method in production code.
    #
    # Sets an output stream for debugging.
    #
    #   http = Net::HTTP.new
    #   http.set_debug_output $stderr
    #   http.start { .... }
    #
    def set_debug_output(output)
      warn 'Net::HTTP#set_debug_output called after HTTP started' if started?
      @debug_output = output
    end

    # The DNS host name or IP address to connect to.
    attr_reader :address

    # The port number to connect to.
    attr_reader :port

    # Number of seconds to wait for the connection to open.
    # If the HTTP object cannot open a connection in this many seconds,
    # it raises a TimeoutError exception.
    attr_accessor :open_timeout

    # Number of seconds to wait for one block to be read (via one read(2)
    # call). If the HTTP object cannot read data in this many seconds,
    # it raises a TimeoutError exception.
    attr_reader :read_timeout

    # Setter for the read_timeout attribute.
    def read_timeout=(sec)
      @socket.read_timeout = sec if @socket
      @read_timeout = sec
    end

    # Returns true if the HTTP session has been started.
    def started?
      @started
    end

    alias active? started?   #:nodoc: obsolete

    attr_accessor :close_on_empty_response

    # Returns true if SSL/TLS is being used with HTTP.
    def use_ssl?
      @use_ssl
    end

    # Turn on/off SSL.
    # This flag must be set before starting session.
    # If you change use_ssl value after session started,
    # a Net::HTTP object raises IOError.
    def use_ssl=(flag)
      flag = (flag ? true : false)
      if started? and @use_ssl != flag
        raise IOError, "use_ssl value changed, but session already started"
      end
      @use_ssl = flag
    end

    SSL_ATTRIBUTES = %w(
      ssl_version key cert ca_file ca_path cert_store ciphers
      verify_mode verify_callback verify_depth ssl_timeout
    )

    # Sets path of a CA certification file in PEM format.
    #
    # The file can contain several CA certificates.
    attr_accessor :ca_file

    # Sets path of a CA certification directory containing certifications in
    # PEM format.
    attr_accessor :ca_path

    # Sets an OpenSSL::X509::Certificate object as client certificate.
    # (This method is appeared in Michal Rokos's OpenSSL extension).
    attr_accessor :cert

    # Sets the X509::Store to verify peer certificate.
    attr_accessor :cert_store

    # Sets the available ciphers.  See OpenSSL::SSL::SSLContext#ciphers=
    attr_accessor :ciphers

    # Sets an OpenSSL::PKey::RSA or OpenSSL::PKey::DSA object.
    # (This method is appeared in Michal Rokos's OpenSSL extension.)
    attr_accessor :key

    # Sets the SSL timeout seconds.
    attr_accessor :ssl_timeout

    # Sets the SSL version.  See OpenSSL::SSL::SSLContext#ssl_version=
    attr_accessor :ssl_version

    # Sets the verify callback for the server certification verification.
    attr_accessor :verify_callback

    # Sets the maximum depth for the certificate chain verification.
    attr_accessor :verify_depth

    # Sets the flags for server the certification verification at beginning of
    # SSL/TLS session.
    #
    # OpenSSL::SSL::VERIFY_NONE or OpenSSL::SSL::VERIFY_PEER are acceptable.
    attr_accessor :verify_mode

    # Returns the X.509 certificates the server presented.
    def peer_cert
      if not use_ssl? or not @socket
        return nil
      end
      @socket.io.peer_cert
    end

    # Opens a TCP connection and HTTP session.
    #
    # When this method is called with a block, it passes the Net::HTTP
    # object to the block, and closes the TCP connection and HTTP session
    # after the block has been executed.
    #
    # When called with a block, it returns the return value of the
    # block; otherwise, it returns self.
    #
    def start  # :yield: http
      raise IOError, 'HTTP session already opened' if @started
      if block_given?
        begin
          do_start
          return yield(self)
        ensure
          do_finish
        end
      end
      do_start
      self
    end

    def do_start
      connect
      @started = true
    end
    private :do_start

    def connect
      D "opening connection to #{conn_address()}..."
      s = timeout(@open_timeout) { TCPSocket.open(conn_address(), conn_port()) }
      D "opened"
      if use_ssl?
        ssl_parameters = Hash.new
        iv_list = instance_variables
        iv_list = iv_list.map { |name| name.to_sym } unless iv_list.first.is_a?(Symbol)

        SSL_ATTRIBUTES.each do |name|
          ivname = "@#{name}".intern
          if iv_list.include?(ivname) and
             value = instance_variable_get(ivname)
            ssl_parameters[name] = value
          end
        end
        @ssl_context = OpenSSL::SSL::SSLContext.new
        @ssl_context.set_params(ssl_parameters)
        s = OpenSSL::SSL::SSLSocket.new(s, @ssl_context)
        s.sync_close = true
      end
      @socket = BufferedIO.new(s)
      @socket.read_timeout = @read_timeout
      @socket.debug_output = @debug_output
      if use_ssl?
        begin
          if proxy?
            @socket.writeline sprintf('CONNECT %s:%s HTTP/%s',
                                      @address, @port, HTTPVersion)
            @socket.writeline "Host: #{@address}:#{@port}"
            if proxy_user
              credential = ["#{proxy_user}:#{proxy_pass}"].pack('m')
              credential.delete!("\r\n")
              @socket.writeline "Proxy-Authorization: Basic #{credential}"
            end
            @socket.writeline ''
            HTTPResponse.read_new(@socket).value
          end
          timeout(@open_timeout) { s.connect }
          if @ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE
            s.post_connection_check(@address)
          end
        rescue => exception
          D "Conn close because of connect error #{exception}"
          @socket.close if @socket and not @socket.closed?
          raise exception
        end
      end
      on_connect
    end
    private :connect

    def on_connect
    end
    private :on_connect

    # Finishes the HTTP session and closes the TCP connection.
    # Raises IOError if the session has not been started.
    def finish
      raise IOError, 'HTTP session not yet started' unless started?
      do_finish
    end

    def do_finish
      @started = false
      @socket.close if @socket and not @socket.closed?
      @socket = nil
    end
    private :do_finish

    #
    # proxy
    #

    public

    # no proxy
    @is_proxy_class = false
    @proxy_addr = nil
    @proxy_port = nil
    @proxy_user = nil
    @proxy_pass = nil

    # Creates an HTTP proxy class which behaves like Net::HTTP, but
    # performs all access via the specified proxy.
    #
    # The arguments are the DNS name or IP address of the proxy host,
    # the port to use to access the proxy, and a username and password
    # if authorization is required to use the proxy.
    #
    # You can replace any use of the Net::HTTP class with use of the
    # proxy class created.
    #
    # If +p_addr+ is nil, this method returns self (a Net::HTTP object).
    #
    #   # Example
    #   proxy_class = Net::HTTP::Proxy('proxy.example.com', 8080)
    #
    #   proxy_class.start('www.ruby-lang.org') {|http|
    #     # connecting proxy.foo.org:8080
    #   }
    #
    # You may use them to work with authorization-enabled proxies:
    #
    #   proxy_host = 'your.proxy.example'
    #   proxy_port = 8080
    #   proxy_user = 'user'
    #   proxy_pass = 'pass'
    #
    #   proxy = Net::HTTP::Proxy(proxy_host, proxy_port, proxy_user, proxy_pass)
    #   proxy.start('www.example.com') { |http|
    #     # always connect to your.proxy.example:8080 using specified username
    #     # and password
    #   }
    #
    # Note that net/http does not use the HTTP_PROXY environment variable.
    # If you want to use a proxy, you must set it explicitly.
    #
    def self.Proxy(p_addr, p_port = nil, p_user = nil, p_pass = nil)
      return self unless p_addr

      delta = ProxyDelta
      proxyclass = Class.new(self)

      proxyclass.module_eval do
        include delta
        # with proxy
        @is_proxy_class = true
        @proxy_address = p_addr
        @proxy_port    = p_port || default_port()
        @proxy_user    = p_user
        @proxy_pass    = p_pass
      end

      proxyclass
    end

    class << HTTP
      # returns true if self is a class which was created by HTTP::Proxy.
      def proxy_class?
        @is_proxy_class
      end

      attr_reader :proxy_address
      attr_reader :proxy_port
      attr_reader :proxy_user
      attr_reader :proxy_pass
    end

    # True if self is a HTTP proxy class.
    def proxy?
      self.class.proxy_class?
    end

    # Address of proxy host. If self does not use a proxy, nil.
    def proxy_address
      self.class.proxy_address
    end

    # Port number of proxy host. If self does not use a proxy, nil.
    def proxy_port
      self.class.proxy_port
    end

    # User name for accessing proxy. If self does not use a proxy, nil.
    def proxy_user
      self.class.proxy_user
    end

    # User password for accessing proxy. If self does not use a proxy, nil.
    def proxy_pass
      self.class.proxy_pass
    end

    alias proxyaddr proxy_address   #:nodoc: obsolete
    alias proxyport proxy_port      #:nodoc: obsolete

    private

    # without proxy

    def conn_address
      address()
    end

    def conn_port
      port()
    end

    def edit_path(path)
      path
    end

    module ProxyDelta   #:nodoc: internal use only
      private

      def conn_address
        proxy_address()
      end

      def conn_port
        proxy_port()
      end

      def edit_path(path)
        use_ssl? ? path : "http://#{addr_port()}#{path}"
      end
    end

    #
    # HTTP operations
    #

    public

    # Gets data from +path+ on the connected-to host.
    # +initheader+ must be a Hash like { 'Accept' => '*/*', ... },
    # and it defaults to an empty hash.
    # If +initheader+ doesn't have the key 'accept-encoding', then
    # a value of "gzip;q=1.0,deflate;q=0.6,identity;q=0.3" is used,
    # so that gzip compression is used in preference to deflate
    # compression, which is used in preference to no compression.
    # Ruby doesn't have libraries to support the compress (Lempel-Ziv)
    # compression, so that is not supported.  The intent of this is
    # to reduce bandwidth by default.   If this routine sets up
    # compression, then it does the decompression also, removing
    # the header as well to prevent confusion.  Otherwise
    # it leaves the body as it found it.
    #
    # This method returns a Net::HTTPResponse object.
    #
    # If called with a block, yields each fragment of the
    # entity body in turn as a string as it is read from
    # the socket.  Note that in this case, the returned response
    # object will *not* contain a (meaningful) body.
    #
    # +dest+ argument is obsolete.
    # It still works but you must not use it.
    #
    # This method never raises an exception.
    #
    #     response = http.get('/index.html')
    #
    #     # using block
    #     File.open('result.txt', 'w') {|f|
    #       http.get('/~foo/') do |str|
    #         f.write str
    #       end
    #     }
    #
    def get(path, initheader = {}, dest = nil, &block) # :yield: +body_segment+
      response = nil

      request(Get.new(path, initheader)) do |r|
        response = r
        r.read_body(dest, &block)
        r.close
      end

      response
    end

    # Gets only the header from +path+ on the connected-to host.
    # +header+ is a Hash like { 'Accept' => '*/*', ... }.
    #
    # This method returns a Net::HTTPResponse object.
    #
    # This method never raises an exception.
    #
    #     response = nil
    #     Net::HTTP.start('some.www.server', 80) {|http|
    #       response = http.head('/index.html')
    #     }
    #     p response['content-type']
    #
    def head(path, initheader = nil)
      request(Head.new(path, initheader))
    end

    # Posts +data+ (must be a String) to +path+. +header+ must be a Hash
    # like { 'Accept' => '*/*', ... }.
    #
    # This method returns a Net::HTTPResponse object.
    #
    # If called with a block, yields each fragment of the
    # entity body in turn as a string as it is read from
    # the socket.  Note that in this case, the returned response
    # object will *not* contain a (meaningful) body.
    #
    # +dest+ argument is obsolete.
    # It still works but you must not use it.
    #
    # This method never raises exception.
    #
    #     response = http.post('/cgi-bin/search.rb', 'query=foo')
    #
    #     # using block
    #     File.open('result.txt', 'w') {|f|
    #       http.post('/cgi-bin/search.rb', 'query=foo') do |str|
    #         f.write str
    #       end
    #     }
    #
    # You should set Content-Type: header field for POST.
    # If no Content-Type: field given, this method uses
    # "application/x-www-form-urlencoded" by default.
    #
    def post(path, data, initheader = nil, dest = nil, &block) # :yield: +body_segment+
      send_entity(path, data, initheader, dest, Post, &block)
    end

    # Sends a PATCH request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def patch(path, data, initheader = nil, dest = nil, &block) # :yield: +body_segment+
      send_entity(path, data, initheader, dest, Patch, &block)
    end

    def put(path, data, initheader = nil)   #:nodoc:
      request(Put.new(path, initheader), data)
    end

    # Sends a PROPPATCH request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def proppatch(path, body, initheader = nil)
      request(Proppatch.new(path, initheader), body)
    end

    # Sends a LOCK request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def lock(path, body, initheader = nil)
      request(Lock.new(path, initheader), body)
    end

    # Sends a UNLOCK request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def unlock(path, body, initheader = nil)
      request(Unlock.new(path, initheader), body)
    end

    # Sends a OPTIONS request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def options(path, initheader = nil)
      request(Options.new(path, initheader))
    end

    # Sends a PROPFIND request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def propfind(path, body = nil, initheader = {'Depth' => '0'})
      request(Propfind.new(path, initheader), body)
    end

    # Sends a DELETE request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def delete(path, initheader = {'Depth' => 'Infinity'})
      request(Delete.new(path, initheader))
    end

    # Sends a MOVE request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def move(path, initheader = nil)
      request(Move.new(path, initheader))
    end

    # Sends a COPY request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def copy(path, initheader = nil)
      request(Copy.new(path, initheader))
    end

    # Sends a MKCOL request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def mkcol(path, body = nil, initheader = nil)
      request(Mkcol.new(path, initheader), body)
    end

    # Sends a TRACE request to the +path+ and gets a response,
    # as an HTTPResponse object.
    def trace(path, initheader = nil)
      request(Trace.new(path, initheader))
    end

    # Sends a GET request to the +path+.
    # Returns the response as a Net::HTTPResponse object.
    #
    # When called with a block, passes an HTTPResponse object to the block.
    # The body of the response will not have been read yet;
    # the block can process it using HTTPResponse#read_body,
    # if desired.
    #
    # Returns the response.
    #
    # This method never raises Net::* exceptions.
    #
    #     response = http.request_get('/index.html')
    #     # The entity body is already read in this case.
    #     p response['content-type']
    #     puts response.body
    #
    #     # Using a block
    #     http.request_get('/index.html') {|response|
    #       p response['content-type']
    #       response.read_body do |str|   # read body now
    #         print str
    #       end
    #     }
    #
    def request_get(path, initheader = nil, &block) # :yield: +response+
      request(Get.new(path, initheader), &block)
    end

    # Sends a HEAD request to the +path+ and returns the response
    # as a Net::HTTPResponse object.
    #
    # Returns the response.
    #
    # This method never raises Net::* exceptions.
    #
    #     response = http.request_head('/index.html')
    #     p response['content-type']
    #
    def request_head(path, initheader = nil, &block)
      request(Head.new(path, initheader), &block)
    end

    # Sends a POST request to the +path+.
    #
    # Returns the response as a Net::HTTPResponse object.
    #
    # When called with a block, the block is passed an HTTPResponse
    # object.  The body of that response will not have been read yet;
    # the block can process it using HTTPResponse#read_body, if desired.
    #
    # Returns the response.
    #
    # This method never raises Net::* exceptions.
    #
    #     # example
    #     response = http.request_post('/cgi-bin/nice.rb', 'datadatadata...')
    #     p response.status
    #     puts response.body          # body is already read in this case
    #
    #     # using block
    #     http.request_post('/cgi-bin/nice.rb', 'datadatadata...') {|response|
    #       p response.status
    #       p response['content-type']
    #       response.read_body do |str|   # read body now
    #         print str
    #       end
    #     }
    #
    def request_post(path, data, initheader = nil, &block) # :yield: +response+
      request Post.new(path, initheader), data, &block
    end

    def request_put(path, data, initheader = nil, &block)   #:nodoc:
      request Put.new(path, initheader), data, &block
    end

    alias get2   request_get    #:nodoc: obsolete
    alias head2  request_head   #:nodoc: obsolete
    alias post2  request_post   #:nodoc: obsolete
    alias put2   request_put    #:nodoc: obsolete


    # Sends an HTTP request to the HTTP server.
    # Also sends a DATA string if +data+ is given.
    #
    # Returns a Net::HTTPResponse object.
    #
    # This method never raises Net::* exceptions.
    #
    #    response = http.send_request('GET', '/index.html')
    #    puts response.body
    #
    def send_request(name, path, data = nil, header = nil)
      r = HTTPGenericRequest.new(name,(data ? true : false),true,path,header)
      request r, data
    end

    # Sends an HTTPRequest object +req+ to the HTTP server.
    #
    # If +req+ is a Net::HTTP::Post or Net::HTTP::Put request containing
    # data, the data is also sent. Providing data for a Net::HTTP::Head or
    # Net::HTTP::Get request results in an ArgumentError.
    #
    # Returns an HTTPResponse object.
    #
    # When called with a block, passes an HTTPResponse object to the block.
    # The body of the response will not have been read yet;
    # the block can process it using HTTPResponse#read_body,
    # if desired.
    #
    # This method never raises Net::* exceptions.
    #
    def request(req, body = nil, &block)  # :yield: +response+
      # If a request is made, and the connection hasn't been started,
      # wrap the request in a start block, which will create a new
      # connection and read the body so that it can close the socket.
      #
      # If you want to make several requests reusing the same
      # connection, use Net::HTTP.start:
      #
      #     Net::HTTP.start(host, port) do |http|
      #       http.get("/path") do |chunk|
      #
      #       end
      #
      #       http.get("/another_path") do |chunk|
      #
      #       end
      #     end
      unless started?
        start {
          req['connection'] ||= 'close'
          return request(req, body, &block)
        }
      end
      if proxy_user()
        req.proxy_basic_auth proxy_user(), proxy_pass() unless use_ssl?
      end
      req.set_body_internal body
      res = transport_request(req, &block)
      if sspi_auth?(res)
        sspi_auth(req)
        res = transport_request(req, &block)
      end
      res
    end

    private

    # Executes a request which uses a representation
    # and returns its body.
    def send_entity(path, data, initheader, dest, type, &block)
      res = nil
      request(type.new(path, initheader), data) {|r|
        r.read_body dest, &block
        r.close
        res = r
      }
      res
    end

    def transport_request(req)
      begin_transport req

      req.exec @socket, @curr_http_version, edit_path(req.path)
      begin
        res = HTTPResponse.read_new(@socket)
      end while res.kind_of?(HTTPContinue)

      res.request = req

      if block_given?
        yield res
        res.close
      end
      end_transport req, res, block_given?
      @current_response = res
      res
    rescue => exception
      D "Conn close because of error #{exception}"
      @socket.close if @socket and not @socket.closed?
      raise exception
    end

    def begin_transport(req)
      if @socket.closed?
        connect
      else
        # Make sure that the current response is closed. A response would
        # be open if the request was made without a block, and the client
        # never read the body. In this situation, we need to read the
        # expected body in order to continue to use the same connection.
        @current_response.close if @current_response
      end

      # If close_on_empty_response is set, and the response is not
      # allowed to have a body (i.e. HEAD requests), turn off keepalive
      if not req.response_body_permitted? and @close_on_empty_response
        req['connection'] ||= 'close'
      end

      req['host'] ||= addr_port
    end

    def end_transport(req, res, block_form)
      @curr_http_version = res.http_version
      if @socket.closed?
        D 'Conn socket closed'
      elsif @close_on_empty_response && !res.body
        D 'Conn close'
        @socket.close
      elsif keep_alive?(req, res)
        D 'Conn keep-alive'
      elsif block_form
        D 'Conn close'
        @socket.close
      end
    end

    def keep_alive?(req, res)
      return false if req.connection_close?
      if @curr_http_version <= '1.0'
        res.connection_keep_alive?
      else   # HTTP/1.1 or later
        not res.connection_close?
      end
    end

    def sspi_auth?(res)
      return false unless @sspi_enabled
      if res.kind_of?(HTTPProxyAuthenticationRequired) and
          proxy? and res["Proxy-Authenticate"].include?("Negotiate")
        begin
          require 'win32/sspi'
          true
        rescue LoadError
          false
        end
      else
        false
      end
    end

    def sspi_auth(req)
      n = Win32::SSPI::NegotiateAuth.new
      req["Proxy-Authorization"] = "Negotiate #{n.get_initial_token}"
      # Some versions of ISA will close the connection if this isn't present.
      req["Connection"] = "Keep-Alive"
      req["Proxy-Connection"] = "Keep-Alive"
      res = transport_request(req)
      authphrase = res["Proxy-Authenticate"]  or return res
      req["Proxy-Authorization"] = "Negotiate #{n.complete_authentication(authphrase)}"
    rescue => err
      raise HTTPAuthenticationError.new('HTTP authentication failed', err)
    end

    #
    # utils
    #

    private

    def addr_port
      if use_ssl?
        address + (port == HTTP.https_default_port ? '' : ":#{port()}")
      else
        address + (port == HTTP.http_default_port ? '' : ":#{port()}")
      end
    end

    def D(msg)
      return unless @debug_output
      @debug_output << msg
      @debug_output << "\n"
    end

  end

  HTTPSession = HTTP

  require "net2/http/header"
  require "net2/http/generic_request"
  require "net2/http/request"

  ###
  ### Response
  ###

  # HTTP response class.
  #
  # This class wraps together the response header and the response body (the
  # entity requested).
  #
  # It mixes in the HTTPHeader module, which provides access to response
  # header values both via hash-like methods and via individual readers.
  #
  # Note that each possible HTTP response code defines its own
  # HTTPResponse subclass.  These are listed below.
  #
  # All classes are
  # defined under the Net module. Indentation indicates inheritance.
  #
  #   xxx        HTTPResponse
  #
  #     1xx        HTTPInformation
  #       100        HTTPContinue
  #       101        HTTPSwitchProtocol
  #
  #     2xx        HTTPSuccess
  #       200        HTTPOK
  #       201        HTTPCreated
  #       202        HTTPAccepted
  #       203        HTTPNonAuthoritativeInformation
  #       204        HTTPNoContent
  #       205        HTTPResetContent
  #       206        HTTPPartialContent
  #
  #     3xx        HTTPRedirection
  #       300        HTTPMultipleChoice
  #       301        HTTPMovedPermanently
  #       302        HTTPFound
  #       303        HTTPSeeOther
  #       304        HTTPNotModified
  #       305        HTTPUseProxy
  #       307        HTTPTemporaryRedirect
  #
  #     4xx        HTTPClientError
  #       400        HTTPBadRequest
  #       401        HTTPUnauthorized
  #       402        HTTPPaymentRequired
  #       403        HTTPForbidden
  #       404        HTTPNotFound
  #       405        HTTPMethodNotAllowed
  #       406        HTTPNotAcceptable
  #       407        HTTPProxyAuthenticationRequired
  #       408        HTTPRequestTimeOut
  #       409        HTTPConflict
  #       410        HTTPGone
  #       411        HTTPLengthRequired
  #       412        HTTPPreconditionFailed
  #       413        HTTPRequestEntityTooLarge
  #       414        HTTPRequestURITooLong
  #       415        HTTPUnsupportedMediaType
  #       416        HTTPRequestedRangeNotSatisfiable
  #       417        HTTPExpectationFailed
  #
  #     5xx        HTTPServerError
  #       500        HTTPInternalServerError
  #       501        HTTPNotImplemented
  #       502        HTTPBadGateway
  #       503        HTTPServiceUnavailable
  #       504        HTTPGatewayTimeOut
  #       505        HTTPVersionNotSupported
  #
  #     xxx        HTTPUnknownResponse
  #
  class HTTP
    class Response
      CODE_CLASS_TO_OBJ = {}
      CODE_TO_OBJ = {}

      # true if the response has a body.
      def self.body_permitted?
        self::HAS_BODY
      end

      def self.exception_type   # :nodoc: internal use only
        self::EXCEPTION_TYPE
      end
    end   # reopened after
  end

  HTTPResponse = HTTP::Response

  require "net2/http/statuses"
  require "net2/http/response"

  # :enddoc:

  #--
  # for backward compatibility
  class HTTP
    ProxyMod = ProxyDelta
  end
  module NetPrivate
    HTTPRequest = ::Net2::HTTPRequest
  end

  HTTPInformationCode = HTTPInformation
  HTTPSuccessCode     = HTTPSuccess
  HTTPRedirectionCode = HTTPRedirection
  HTTPRetriableCode   = HTTPRedirection
  HTTPClientErrorCode = HTTPClientError
  HTTPFatalErrorCode  = HTTPClientError
  HTTPServerErrorCode = HTTPServerError
  HTTPResponceReceiver = HTTPResponse

end   # module Net


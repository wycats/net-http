module Net2
  class HTTP
    # HTTP exception class.
    # You cannot use HTTPExceptions directly; instead, you must use
    # its subclasses.
    module Exceptions
      def initialize(msg, res)   #:nodoc:
        super msg
        @response = res
      end
      attr_reader :response
      alias data response    #:nodoc: obsolete
    end

    class Error < ProtocolError
      include Exceptions
    end

    class RetriableError < ProtoRetriableError
      include Exceptions
    end

    class ServerException < ProtoServerError
      # We cannot use the name "HTTPServerError", it is the name of the response.
      include Exceptions
    end

    class FatalError < ProtoFatalError
      include Exceptions
    end
  end

  class HTTP
    class Response
      def self.subclass(*names)
        options = names.last.is_a?(Hash) ? names.pop : {}

        names.each do |name|
          klass = HTTP.const_set name, Class.new(self)
          klass.const_set :HAS_BODY, options.key?(:body) ? options[:body] : self::HAS_BODY
          klass.const_set :EXCEPTION_TYPE, options[:error] || self::EXCEPTION_TYPE

          # for backwards compatibility with Net::HTTP
          Net2.const_set "HTTP#{name}", klass
        end
      end
    end

    Response.subclass     :Information,               :body => false, :error => Error
    Response.subclass     :UnknownResponse, :Success, :body => true, :error => Error
    Response.subclass     :Redirection,               :body => true, :error => RetriableError
    Response.subclass     :ClientError,               :body => true, :error => ServerException
    Response.subclass     :ServerError,               :body => true, :error => FatalError

    #                      100        101
    Information.subclass  :Continue, :SwitchProtocol

    #                      200  201       202        203                           206
    Success.subclass      :OK, :Created, :Accepted, :NonAuthoritativeInformation, :PartialContent

    #                      204         205
    Success.subclass      :NoContent, :ResetContent,  :body => false

    #                      300              301                302     303        307
    Redirection.subclass  :MultipleChoice, :MovedPermanently, :Found, :SeeOther, :TemporaryRedirect

    # 306 unused

    #                      # 304         305
    Redirection.subclass  :NotModified, :UseProxy,    :body => false

    MovedTemporarily = Found

    #                      400          401            402               403         404
    ClientError.subclass  :BadRequest, :Unauthorized, :PaymentRequired, :Forbidden, :NotFound,

    #                      405                406             407
                          :MethodNotAllowed, :NotAcceptable, :ProxyAuthenticationRequired,

    #                      408              409        410    411              412
                          :RequestTimeOut, :Conflict, :Gone, :LengthRequired, :PreconditionFailed,

    #                      413                     414                 415
                          :RequestEntityTooLarge, :RequestURITooLong, :UnsupportedMediaType,

    #                      416                            417
                          :RequestedRangeNotSatisfiable, :ExpectationFailed

    RequestURITooLarge = RequestURITooLong

    #                      500                   501              502          503
    ServerError.subclass  :InternalServerError, :NotImplemented, :BadGateway, :ServiceUnavailable,

    #                      504              505
                          :GatewayTimeOut, :VersionNotSupported
  end

  # :startdoc:

  HTTPExceptions = HTTP::Exceptions
  HTTPError = HTTP::Error
  HTTPRetriableError = HTTP::RetriableError
  HTTPServerException = HTTP::ServerException
  HTTPFatalError = HTTP::FatalError
end

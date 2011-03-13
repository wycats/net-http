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
      def self.subclass(name, code, options = {})
        klass = HTTP.const_set name, Class.new(self)
        klass.const_set :HAS_BODY, options.key?(:body) ? options[:body] : self::HAS_BODY
        klass.const_set :EXCEPTION_TYPE, options[:error] || self::EXCEPTION_TYPE

        if code < 100
          CODE_CLASS_TO_OBJ[code.to_s] = klass
        else
          CODE_TO_OBJ[code.to_s] = klass
        end

        # for backwards compatibility with Net::HTTP
        Net2.const_set "HTTP#{name}", klass
      end
    end

    Response.subclass     :Information,     1,    :body => false, :error => Error
    Response.subclass     :Success,         3,    :body => true,  :error => Error
    Response.subclass     :Redirection,     4,    :body => true,  :error => RetriableError
    Response.subclass     :ClientError,     5,    :body => true,  :error => ServerException
    Response.subclass     :ServerError,     6,    :body => true,  :error => FatalError

    Response.subclass     :UnknownResponse, nil,  :body => true,  :error => Error

    Information.subclass  :Continue,                    100
    Information.subclass  :SwitchProtocol,              101

    Success.subclass      :OK,                          200
    Success.subclass      :Created,                     201
    Success.subclass      :Accepted,                    202
    Success.subclass      :NonAuthoritativeInformation, 203
    Success.subclass      :NoContent,                   204, :body => false
    Success.subclass      :ResetContent,                205, :body => false
    Success.subclass      :PartialContent,              206

    Redirection.subclass  :MultipleChoice,              300
    Redirection.subclass  :MovedPermanently,            301
    Redirection.subclass  :Found,                       302
    Redirection.subclass  :SeeOther,                    303
    Redirection.subclass  :NotModified,                 304, :body => false
    Redirection.subclass  :UseProxy,                    305, :body => false
    # 306 unused
    Redirection.subclass  :TemporaryRedirect,           307

    MovedTemporarily = Found

    ClientError.subclass :BadRequest,                   400
    ClientError.subclass :Unauthorized,                 401
    ClientError.subclass :PaymentRequired,              402
    ClientError.subclass :Forbidden,                    403
    ClientError.subclass :NotFound,                     404
    ClientError.subclass :MethodNotAllowed,             405
    ClientError.subclass :NotAcceptable,                406
    ClientError.subclass :ProxyAuthenticationRequired,  407
    ClientError.subclass :RequestTimeOut,               408
    ClientError.subclass :Conflict,                     409
    ClientError.subclass :Gone,                         410
    ClientError.subclass :LengthRequired,               411
    ClientError.subclass :PreconditionFailed,           412
    ClientError.subclass :RequestEntityTooLarge,        413
    ClientError.subclass :RequestURITooLong,            414
    ClientError.subclass :UnsupportedMediaType,         415
    ClientError.subclass :RequestedRangeNotSatisfiable, 416
    ClientError.subclass :ExpectationFailed,            417

    RequestURITooLarge = RequestURITooLong

    ServerError.subclass :InternalServerError,          500
    ServerError.subclass :NotImplemented,               501
    ServerError.subclass :BadGateway,                   502
    ServerError.subclass :ServiceUnavailable,           503
    ServerError.subclass :GatewayTimeOut,               504
    ServerError.subclass :VersionNotSupported,          505
  end

  # :startdoc:

  HTTPExceptions = HTTP::Exceptions
  HTTPError = HTTP::Error
  HTTPRetriableError = HTTP::RetriableError
  HTTPServerException = HTTP::ServerException
  HTTPFatalError = HTTP::FatalError
end

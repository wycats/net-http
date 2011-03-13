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
          klass.const_set :HAS_BODY, options.key?(:body) ? options[:body] : self::BODY
          klass.const_set :EXCEPTION_TYPE, options[:error] || self::EXCEPTION_TYPE
        end
      end
    end

    Response.subclass :Information,               :body => false, :error => Error
    Response.subclass :UnknownResponse, :Success, :body => true, :error => Error
    Response.subclass :Redirection,               :body => true, :error => RetriableError
    Response.subclass :ClientError,               :body => true, :error => ServerException
    Response.subclass :ServerError,               :body => true, :error => FatalError


    class Continue < Information           # 100
      HAS_BODY = false
    end
    class SwitchProtocol < Information                # 101
      HAS_BODY = false
    end

    class OK < Success; end                               # 200
    class Created < Success; end                          # 201
    class Accepted < Success; end                         # 202
    class NonAuthoritativeInformation < Success; end      # 203

    class NoContent < Success                             # 204
      HAS_BODY = false
    end

    class ResetContent < Success                          # 205
      HAS_BODY = false
    end

    class PartialContent < Success; end                   # 206

    class MultipleChoice < Redirection; end               # 300
    class MovedPermanently < Redirection; end             # 301
    class Found < Redirection; end                        # 302

    MovedTemporarily = Found

    class SeeOther < Redirection; end                     # 303

    class NotModified < Redirection                       # 304
      HAS_BODY = false
    end

    class UseProxy < Redirection                          # 305
      HAS_BODY = false
    end

                                                          # 306 unused

    class TemporaryRedirect < Redirection; end            # 307

    class BadRequest < ClientError; end                   # 400
    class Unauthorized < ClientError; end                 # 401
    class PaymentRequired < ClientError; end              # 402
    class Forbidden < ClientError; end                    # 403
    class NotFound < ClientError; end                     # 404
    class MethodNotAllowed < ClientError; end             # 405
    class NotAcceptable < ClientError; end                # 406
    class ProxyAuthenticationRequired < ClientError; end  # 407
    class RequestTimeOut < ClientError; end               # 408
    class Conflict < ClientError; end                     # 409
    class Gone < ClientError; end                         # 410
    class LengthRequired < ClientError; end               # 411
    class PreconditionFailed < ClientError; end           # 412
    class RequestEntityTooLarge < ClientError; end        # 413
    class RequestURITooLong < ClientError; end            # 414

    RequestURITooLarge = RequestURITooLong

    class UnsupportedMediaType < ClientError; end         # 415
    class RequestedRangeNotSatisfiable < ClientError; end # 416
    class ExpectationFailed < ClientError; end            # 417

    class InternalServerError < ServerError; end          # 500
    class NotImplemented < ServerError; end               # 501
    class BadGateway < ServerError; end                   # 502
    class ServiceUnavailable < ServerError; end           # 503
    class GatewayTimeOut < ServerError; end               # 504
    class VersionNotSupported < ServerError; end          # 505
  end

  # :startdoc:

  HTTPExceptions = HTTP::Exceptions
  HTTPError = HTTP::Error
  HTTPRetriableError = HTTP::RetriableError
  HTTPServerException = HTTP::ServerException
  HTTPFatalError = HTTP::FatalError

  # :stopdoc:

  HTTPUnknownResponse = HTTP::UnknownResponse
  HTTPInformation = HTTP::Information
  HTTPSuccess = HTTP::Success
  HTTPRedirection = HTTP::Redirection
  HTTPClientError = HTTP::ClientError
  HTTPServerError = HTTP::ServerError

  HTTPContinue = HTTP::Continue
  HTTPSwitchProtocol = HTTP::SwitchProtocol
  HTTPOK = HTTP::OK
  HTTPCreated = HTTP::Created
  HTTPAccepted = HTTP::Accepted
  HTTPNonAuthoritativeInformation = HTTP::NonAuthoritativeInformation
  HTTPNoContent = HTTP::NoContent
  HTTPResetContent = HTTP::ResetContent
  HTTPPartialContent = HTTP::PartialContent
  HTTPMultipleChoice = HTTP::MultipleChoice
  HTTPMovedPermanently = HTTP::MovedPermanently
  HTTPFound = HTTP::Found

  HTTPMovedTemporarily = HTTPFound

  HTTPSeeOther = HTTP::SeeOther
  HTTPNotModified = HTTP::NotModified
  HTTPUseProxy = HTTP::UseProxy
  HTTPTemporaryRedirect = HTTP::TemporaryRedirect
  HTTPBadRequest = HTTP::BadRequest
  HTTPUnauthorized = HTTP::Unauthorized
  HTTPPaymentRequired = HTTP::PaymentRequired
  HTTPForbidden = HTTP::Forbidden
  HTTPNotFound = HTTP::NotFound
  HTTPMethodNotAllowed = HTTP::MethodNotAllowed
  HTTPNotAcceptable = HTTP::NotAcceptable
  HTTPProxyAuthenticationRequired = HTTP::ProxyAuthenticationRequired
  HTTPRequestTimeOut = HTTP::RequestTimeOut
  HTTPConflict = HTTP::Conflict
  HTTPGone = HTTP::Gone
  HTTPLengthRequired = HTTP::LengthRequired
  HTTPPreconditionFailed = HTTP::PreconditionFailed
  HTTPRequestEntityTooLarge = HTTP::RequestEntityTooLarge
  HTTPRequestURITooLong = HTTP::RequestURITooLong
  HTTPRequestURITooLarge = HTTPRequestURITooLong
  HTTPUnsupportedMediaType = HTTP::UnsupportedMediaType
  HTTPRequestedRangeNotSatisfiable = HTTP::RequestedRangeNotSatisfiable
  HTTPExpectationFailed = HTTP::ExpectationFailed
  HTTPInternalServerError = HTTP::InternalServerError
  HTTPNotImplemented = HTTP::NotImplemented
  HTTPBadGateway = HTTP::BadGateway
  HTTPServiceUnavailable = HTTP::ServiceUnavailable
  HTTPGatewayTimeOut = HTTP::GatewayTimeOut
  HTTPVersionNotSupported = HTTP::VersionNotSupported

end

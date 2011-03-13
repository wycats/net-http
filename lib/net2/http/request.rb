module Net2
  class HTTP
    #
    # HTTP request class.
    # This class wraps together the request header and the request path.
    # You cannot use this class directly. Instead, you should use one of its
    # subclasses: Net::HTTP::Get, Net::HTTP::Post, Net::HTTP::Head.
    #
    class Request < GenericRequest

      # Creates HTTP request object.
      def initialize(path, initheader = nil)
        super self.class::METHOD,
              self.class::REQUEST_HAS_BODY,
              self.class::RESPONSE_HAS_BODY,
              path, initheader
      end
    end


    #
    # HTTP/1.1 methods --- RFC2616
    #

    # See Net::HTTPGenericRequest for attributes and methods.
    # See Net::HTTP for usage examples.
    class Get < Request
      METHOD = 'GET'
      REQUEST_HAS_BODY  = false
      RESPONSE_HAS_BODY = true
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    # See Net::HTTP for usage examples.
    class Head < Request
      METHOD = 'HEAD'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    # See Net::HTTP for usage examples.
    class Post < Request
      METHOD = 'POST'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    # See Net::HTTP for usage examples.
    class Put < Request
      METHOD = 'PUT'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    # See Net::HTTP for usage examples.
    class Delete < Request
      METHOD = 'DELETE'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    class Options < Request
      METHOD = 'OPTIONS'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = false
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    class Trace < Request
      METHOD = 'TRACE'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    #
    # PATCH method --- RFC5789
    #

    # See Net::HTTPGenericRequest for attributes and methods.
    class Patch < Request
      METHOD = 'PATCH'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    #
    # WebDAV methods --- RFC2518
    #

    # See Net::HTTPGenericRequest for attributes and methods.
    class Propfind < Request
      METHOD = 'PROPFIND'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    class Proppatch < Request
      METHOD = 'PROPPATCH'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    class Mkcol < Request
      METHOD = 'MKCOL'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    class Copy < Request
      METHOD = 'COPY'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    class Move < Request
      METHOD = 'MOVE'
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    class Lock < Request
      METHOD = 'LOCK'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end

    # See Net::HTTPGenericRequest for attributes and methods.
    class Unlock < Request
      METHOD = 'UNLOCK'
      REQUEST_HAS_BODY = true
      RESPONSE_HAS_BODY = true
    end
  end

  HTTPRequest = HTTP::Request
end

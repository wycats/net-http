module Net2
  class HTTP
    # TODO: Deal with keepalive using the same socket but not sharing a reader
    class Reader
      BUFSIZE = 1024

      def initialize(socket, endpoint)
        @socket         = socket
        @endpoint       = endpoint
      end

      def read(bufsize, timeout=60)
        while true
          read_to_endpoint(bufsize)

          break if eof?
          wait timeout
        end

        @endpoint
      end

      def read_nonblock(len)
        saw_content = read_to_endpoint(len)

        unless saw_content
          raise EOFError if eof?
          raise Errno::EWOULDBLOCK
        end

        @endpoint
      ensure
        @endpoint = ""
      end

      def wait(timeout=nil)
        io = @socket.to_io

        if io.is_a?(OpenSSL::SSL::SSLSocket)
          return if IO.select nil, [io], nil, timeout
        else
          return if IO.select [io], nil, nil, 1
        end

        raise Timeout::Error
      end
    end

    class BodyReader < Reader
      def initialize(socket, endpoint, content_length)
        super(socket, endpoint)

        @content_length = content_length
        @read           = 0
        @eof            = false
      end

      def read(timeout=2)
        super @content_length, timeout
      end

      def read_to_endpoint(len=@content_length)
        if @content_length && len
          remain = @content_length - @read

          raise EOFError if remain.zero?
          len = remain if len > remain
        else
          len = BUFSIZE
        end

        begin
          output = @socket.read_nonblock(len)
          @endpoint << output
          @read += output.size
        rescue Errno::EWOULDBLOCK, Errno::EAGAIN, OpenSSL::SSL::SSLError
          return false
        rescue EOFError
          @eof = true
        end
      end

      def eof?
        return true if @eof
        @content_length - @read == 0 if @content_length
      end
    end

    class ChunkedBodyReader < Reader
      def initialize(socket, endpoint="")
        super(socket, endpoint)

        @raw_buffer      = ""
        @out_buffer      = ""

        @chunk_size      = nil
        @state           = :process_size

        @handled_trailer = false
      end

      def read_to_endpoint(len=nil)
        fill_buffer

        send @state

        return false if len && @out_buffer.empty?

        if !len
          @endpoint << @out_buffer
          @out_buffer = ""
        elsif @out_buffer.size > len
          @endpoint << @out_buffer.slice!(0, len)
        else
          @endpoint << @out_buffer
          @out_buffer = ""
        end

        return true
      end

      def read(timeout=60)
        super BUFSIZE, timeout
      end

      def eof?
        @eof && @out_buffer.empty?
      end

    private
      def fill_buffer
        @raw_buffer << @socket.read_nonblock(BUFSIZE)
        return true
      rescue Errno::EWOULDBLOCK, EOFError
        return false
      end

      def process_size
        idx = @raw_buffer.index("\r\n")
        return unless idx

        size_str = @raw_buffer.slice!(0, idx)
        @raw_buffer.slice!(0, 2)

        if size_str == "0"
          @state = :process_trailer
          process_trailer
          return
        end

        @size = size_str.to_i(16)

        @state = :process_chunk
        process_chunk
      end

      # TODO: Make this handle chunk metadata
      def process_chunk
        if @raw_buffer.size > @size
          @out_buffer << @raw_buffer.slice!(0, @size)
          @state = :process_size
          process_size
        else
          @size -= @raw_buffer.size
          @out_buffer << @raw_buffer
          @raw_buffer = ""
        end
      end

      # TODO: Make this handle trailers
      def process_trailer
        idx = @raw_buffer.index("\r\n")
        return unless idx

        @raw_buffer.slice!(0, idx + 2)

        @state = :process_eof if idx == 0
        process_eof
      end

      def process_eof
        raise EOFError if eof?
        @eof = true
      end
    end
  end
end


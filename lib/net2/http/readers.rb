module Net2
  class HTTP
    class BodyReader
      def initialize(socket, endpoint, content_length)
        @socket         = socket
        @endpoint       = endpoint
        @content_length = content_length

        @read = 0
      end

      def read_to_endpoint(len=@content_length)
        remain = @content_length - @read

        raise EOFError if remain.zero?
        len = remain if len > remain

        begin
          output = @socket.read_nonblock(len)
          @endpoint << output
          @read += output.size
        rescue Errno::EWOULDBLOCK, Errno::EAGAIN, OpenSSL::SSL::SSLError
        end
      end

      def wait(timeout=nil)
        if @io.is_a?(OpenSSL::SSL::SSLSocket)
          return if IO.select nil, [@io], nil, timeout
        else
          return if IO.select [@io], nil, nil, timeout
        end

        raise Timeout::Error
      end
    end

    class ChunkedBodyReader
      BUFSIZE = 1024

      def initialize(socket, endpoint="")
        @socket          = socket
        @endpoint        = endpoint
        @raw_buffer      = ""
        @out_buffer      = ""

        @chunk_size      = nil
        @state           = :process_size

        @handled_trailer = false
      end

      def read_to_endpoint(len=nil)
        fill_buffer

        send @state

        if !len
          @endpoint << @out_buffer
          @out_buffer = ""
        elsif @out_buffer.size > len
          @endpoint << @out_buffer.slice!(0, len)
        else
          @endpoint << @out_buffer
          @out_buffer = ""
        end
      end

      def read(timeout=60)
        while true
          @endpoint << read_to_endpoint(1024)
          break if eof?
          wait timeout
        end

        @endpoint
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
        raise EOFError if eof?
        @eof = true
      end

      def eof?
        @eof && @out_buffer.empty? && @raw_buffer.empty?
      end

    private
      def fill_buffer
        @raw_buffer << @socket.read_nonblock(BUFSIZE)
        return true
      rescue Errno::EWOULDBLOCK, EOFError
        return false
      end

      def wait(timeout=nil)
        if @io.is_a?(OpenSSL::SSL::SSLSocket)
          return if IO.select nil, [@socket], nil, timeout
        else
          return if IO.select [@socket], nil, nil, timeout
        end

        raise Timeout::Error
      end
    end
  end
end


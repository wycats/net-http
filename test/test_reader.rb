require "test/unit"
require "utils"
require "net2/http/readers"

module Net2
  class TestBodyReader < Test::Unit::TestCase
    def setup
      @body = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

      @read, @write = IO.pipe
      @buf = ""
      @reader = Net2::HTTP::BodyReader.new(@read, @buf, @body.bytesize)
    end

    def teardown
      @read.close
      @write.close
    end

    def test_simple_read
      @write.write @body
      @reader.read_to_endpoint
      assert_equal @body, @buf
    end

    def test_read_chunks
      @write.write @body
      @reader.read_to_endpoint 50
      assert_equal @body.slice(0,50), @buf
    end

    def test_read_over
      @write.write @body
      @reader.read_to_endpoint 50
      assert_equal @body.slice(0,50), @buf

      @reader.read_to_endpoint @body.size
      assert_equal @body, @buf

      assert_raises EOFError do
        @reader.read_to_endpoint 10
      end
    end

    def test_blocking
      @write.write @body.slice(0,50)
      @reader.read_to_endpoint 100
      assert_equal @body.slice(0,50), @buf

      @reader.read_to_endpoint 100
      assert_equal @body.slice(0,50), @buf

      @write.write @body.slice(50..-1)
      @reader.read_to_endpoint
      assert_equal @body, @buf

      assert_raises EOFError do
        @reader.read_to_endpoint 10
      end
    end

    class TestBuffer
      def initialize(queue)
        @queue  = queue
        @string = ""
      end

      def <<(str)
        @string << str
        @queue.push :continue
      end

      def to_str
        @string
      end
    end

    def test_read_entire_body
      read_queue = Queue.new
      write_queue = Queue.new

      Thread.new do
        @write.write @body.slice(0,50)

        read_queue.push :continue
        write_queue.pop

        @write.write @body[50..-2]

        write_queue.pop

        @write.write @body[-1..-1]
      end

      read_queue.pop

      buffer = TestBuffer.new(write_queue)
      @reader = Net2::HTTP::BodyReader.new(@read, buffer, @body.bytesize)
      out = @reader.read

      assert_equal @body, out.to_str
    end

    def test_read_nonblock
      @reader = Net2::HTTP::BodyReader.new(@read, "", @body.bytesize)

      @write.write @body.slice(0,50)

      buf = ""
      buf << @reader.read_nonblock(20)
      buf << @reader.read_nonblock(35)

      assert_raises Errno::EWOULDBLOCK do
        @reader.read_nonblock(10)
      end

      @write.write @body[50..-2]

      buf << @reader.read_nonblock(1000)

      assert_raises Errno::EWOULDBLOCK do
        @reader.read_nonblock(10)
      end

      @write.write @body[-1..-1]

      buf << @reader.read_nonblock(100)

      assert_raises EOFError do
        @reader.read_nonblock(10)
      end

      assert_raises EOFError do
        @reader.read_nonblock(10)
      end

      assert_equal @body, buf
    end
  end

  class TestChunkedBodyReader < Test::Unit::TestCase
    def setup
      @body = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

      @read, @write = IO.pipe
      @buf = ""
      @reader = Net2::HTTP::ChunkedBodyReader.new(@read, @buf)
    end

    def teardown
      @read.close
      @write.close
    end

    def test_simple_read
      @write.write "#{@body.size.to_s(16)}\r\n#{@body}\r\n0\r\n"
      @reader.read_to_endpoint
      assert_equal @body, @buf
    end

    def test_read_chunks
      @write.write "#{@body.size.to_s(16)}\r\n#{@body}\r\n0\r\n"
      @reader.read_to_endpoint 50
      assert_equal @body.slice(0,50), @buf
    end

    def test_read_over
      @write.write "#{@body.size.to_s(16)}\r\n#{@body}\r\n0\r\n"
      @reader.read_to_endpoint 50
      assert_equal @body.slice(0,50), @buf

      @reader.read_to_endpoint @body.size
      assert_equal @body, @buf

      assert_raises EOFError do
        @reader.read_to_endpoint 10
      end
    end

    def test_blocking
      size = @body.size.to_s(16)
      body = "#{size}\r\n#{@body}\r\n0\r\n"

      @write.write body.slice(0,50 + size.size + 2)
      @reader.read_to_endpoint 100
      assert_equal @body.slice(0,50), @buf

      @reader.read_to_endpoint 100
      assert_equal @body.slice(0,50), @buf

      @write.write body.slice((50 + size.size + 2)..-1)
      @reader.read_to_endpoint
      assert_equal @body, @buf

      assert_raises EOFError do
        @reader.read_to_endpoint 10
      end
    end

    def test_multi_chunks
      @write.write 50.to_s(16)
      @write.write "\r\n"
      @write.write @body.slice(0,50)

      @reader.read_to_endpoint 100
      assert_equal @body.slice(0,50), @buf

      @write.write "\r\n"
      rest = @body[50..-1]
      @write.write rest.size.to_s(16)
      @write.write "\r\n"
      @write.write rest

      @reader.read_to_endpoint
      assert_equal @body, @buf

      @write.write "\r\n0\r\n"
      @reader.read_to_endpoint
      assert_equal @body, @buf

      assert_raises EOFError do
        @reader.read_to_endpoint
      end
    end

    def test_read_nonblock
      @write.write 50.to_s(16)
      @write.write "\r\n"
      @write.write @body.slice(0,50)

      buf  = @reader.read_nonblock(20)
      buf << @reader.read_nonblock(35)

      assert_raises Errno::EWOULDBLOCK do
        @reader.read_nonblock 10
      end

      @write.write "\r\n"
      rest = @body[50..-1]
      @write.write rest.size.to_s(16)
      @write.write "\r\n"
      @write.write rest

      buf << @reader.read_nonblock(1000)

      assert_raises Errno::EWOULDBLOCK do
        @reader.read_nonblock 10
      end

      @write.write "\r\n0\r\n"

      assert_raises EOFError do
        @reader.read_nonblock(100)
      end

      assert_equal @body, buf

      assert_raises EOFError do
        @reader.read_nonblock(100)
      end
    end

    class TestBuffer
      def initialize(queue)
        @write_queue  = queue
        @string = ""
      end

      def <<(str)
        @string << str
        @write_queue.push :continue
      end

      def to_str
        @string
      end
    end

    def test_read_entire_body
      write_queue = Queue.new
      read_queue = Queue.new

      Thread.new do
        @write.write 50.to_s(16)
        @write.write "\r\n"
        @write.write @body.slice(0,50)

        read_queue.push :continue
        write_queue.pop

        @write.write "\r\n"
        rest = @body[50..-1]
        @write.write rest.size.to_s(16)
        @write.write "\r\n"
        @write.write rest

        write_queue.pop

        @write.write "\r\n0\r\n"

      end

      read_queue.pop

      buffer = TestBuffer.new(write_queue)
      @reader = Net2::HTTP::ChunkedBodyReader.new(@read, buffer)
      out = @reader.read

      assert_equal @body, out.to_str
    end
  end
end


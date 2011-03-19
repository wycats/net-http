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
  end
end


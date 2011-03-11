require 'test/unit'
require 'stringio'

require 'utils'

module Net
  class TestBufferedIO < Test::Unit::TestCase
    def test_eof?
      s = StringIO.new
      assert s.eof?
      bio = BufferedIO.new(s)
      assert_equal s, bio.io
      assert_equal s.eof?, bio.eof?
    end
  end
end

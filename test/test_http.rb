# $Id$

require 'test/unit'
require 'stringio'
require 'utils'
require 'http_test_base'

class TestNetHTTP_v1_2 < Test::Unit::TestCase
  CONFIG = {
    'host' => '127.0.0.1',
    'port' => 10081,
    'proxy_host' => nil,
    'proxy_port' => nil,
  }

  include TestNetHTTPUtils
  include TestNetHTTP_version_1_1_methods
  include TestNetHTTP_version_1_2_methods

  def new
    Net2::HTTP.version_1_2
    super
  end
end

class TestNetHTTP_v1_2_chunked < Test::Unit::TestCase
  CONFIG = {
    'host' => '127.0.0.1',
    'port' => 10081,
    'proxy_host' => nil,
    'proxy_port' => nil,
    'chunked' => true,
  }

  include TestNetHTTPUtils
  include TestNetHTTP_version_1_1_methods
  include TestNetHTTP_version_1_2_methods

  def new
    Net::HTTP.version_1_2
    super
  end

  def test_chunked_break
    i = 0
    assert_nothing_raised("[ruby-core:29229]") {
      start {|http|
        http.request_get('/') {|res|
          res.read_body {|chunk|
            break
          }
        }
      }
    }
  end
end


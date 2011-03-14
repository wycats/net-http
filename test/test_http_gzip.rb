require "utils"
require "http_test_base"

class TestNetHTTP_v1_2_gzip < Test::Unit::TestCase
  CONFIG = {
    'host' => '127.0.0.1',
    'port' => 10081,
    'proxy_host' => nil,
    'proxy_port' => nil,
    'gzip' => true
  }

  include TestNetHTTPUtils
  include TestNetHTTP_version_1_1_methods
  include TestNetHTTP_version_1_2_methods

  def new
    Net::HTTP.version_1_2
    super
  end
end

class TestNetHTTP_v1_2_gzip_chunked < Test::Unit::TestCase
  CONFIG = {
    'host' => '127.0.0.1',
    'port' => 10081,
    'proxy_host' => nil,
    'proxy_port' => nil,
    'gzip' => true,
    'chunked' => true
  }

  include TestNetHTTPUtils
  include TestNetHTTP_version_1_1_methods
  include TestNetHTTP_version_1_2_methods

  def new
    Net::HTTP.version_1_2
    super
  end
end



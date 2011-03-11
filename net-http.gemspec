# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "net2/http/version"

Gem::Specification.new do |s|
  s.name        = "net2-http"
  s.version     = Net2::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Yehuda Katz"]
  s.email       = ["wycats@gmail.com"]
  s.homepage    = "http://www.yehudakatz.com"
  s.summary     = %q{A number of improvements to Net::HTTP}
  s.description = File.read(File.expand_path("../README", __FILE__))

  s.rubyforge_project = "net-http"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

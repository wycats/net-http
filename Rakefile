require 'bundler'
Bundler::GemHelper.install_tasks

desc "run the tests"
task :test do
  $:.unshift "lib"
  $:.unshift "test"

  require "openssl/utils"

  Dir["test/test_*.rb"].each do |file|
    require file[%r{test/(.*)\.rb}, 1]
  end
end

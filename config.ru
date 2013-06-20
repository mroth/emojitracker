require 'dalli'
require 'memcachier'

# Defined in ENV on Heroku. To try locally, start memcached and uncomment:
# ENV["MEMCACHIER_SERVERS"] = "localhost"
if memcache_servers = ENV["MEMCACHIER_SERVERS"]
  use Rack::Cache,
    verbose: true,
    metastore:   "memcached://#{memcache_servers}",
    entitystore: "memcached://#{memcache_servers}"
end

require "./web"
require "./benchmark_app"

$stdout.sync = true
use Rack::Deflater
run Sinatra::Application

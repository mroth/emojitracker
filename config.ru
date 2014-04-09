require 'rack-timeout'
require 'rack-cache'
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
require "./web_api"
require "./web_admin"

$stdout.sync = true

# deflate output for bandwidth savings
use Rack::Deflater

# set a timeout for slow connections to not use up dyno slots
# unicorn will have this set too, so this number should be lower than unicorns
use Rack::Timeout
Rack::Timeout.timeout = 10

map('/')            { run WebApp }
map('/api')         { run WebAPI }
map('/admin')       { run WebAdmin }

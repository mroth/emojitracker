require 'sinatra'
require 'coffee-script'
require 'oj'
require_relative 'lib/config'

class WebBenchmarkApp < Sinatra::Base
  get '/benchmark' do
    @kiosk_mode = false
    @benchmark_mode = true
    slim :index
  end

  get '/benchmark.js' do
    coffee :benchmark
  end

  post '/benchmarks' do
    if params['report'].nil?
      puts "Received malformed benchmark submission without a report parameter!"
      status 400
      content_type :json
      Oj.dump 'status' => 'ERROR'
    else
      puts "Received benchmark submission: #{params['report']}"
      REDIS.LPUSH 'benchmark_reports', params['report']
      status 200
      content_type :json
      Oj.dump 'status' => 'OK'
    end
  end
end

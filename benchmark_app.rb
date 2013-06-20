require 'sinatra'
require 'coffee-script'
require 'oj'

get '/benchmark.js' do
  coffee :benchmark
end

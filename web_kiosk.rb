require 'sinatra'
require 'coffee-script'
# require 'oj'
# require_relative 'lib/config'

class WebKioskApp < Sinatra::Base

  get '/kiosk' do
    @kiosk_mode = true
    @benchmark_mode = false
    slim :index
  end

  get '/assets/kiosk.css' do
    scss :kiosk
  end

  get '/kiosk.js' do
    coffee :kiosk
  end

end

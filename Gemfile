source 'https://rubygems.org'
ruby '1.9.3'

group :web, :streamer do
  gem 'redis'
  gem 'oj'
end

group :web do
  gem 'sinatra'
  gem 'slim'
  gem 'coffee-script'
  gem 'sass', :require => 'sass'
  gem 'thin'
end

group :streamer do
  gem 'tweetstream', "~> 2.5.0"
  gem 'colored'
end

group :development do
  gem 'foreman'
end

# group :production do
#   gem 'newrelic_rpm'
# end
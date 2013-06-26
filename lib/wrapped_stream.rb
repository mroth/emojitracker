################################################
# stream object wrapper
#
# handles sending common SSE data, and keeps track of stream age
# pass a request object to instantiate some metadata about the stream client
################################################
require 'sinatra/base'
require 'delegate'
require 'oj'

class WrappedStream < DelegateClass(Sinatra::Helpers::Stream)
  attr_reader :request_path, :tag, :age, :client_ip, :client_user_agent, :created_at

  def initialize(wrapped_stream, request=nil, tag=nil)
    @created_at = Time.now.to_i
    init_client_stats(request)
    @tag = tag
    super(wrapped_stream)
  end

  def init_client_stats(request)
    unless request.nil?
      @client_ip = request.ip
      @client_user_agent = request.user_agent
      @request_path = request.path
    end
  end

  # Returns age of stream in seconds as Integer.
  def age
    Time.now.to_i - @created_at
  end

  def match_tag?(tag)
    @tag == tag
  end

  def to_hash
    {
      'request_path' => @request_path,
      'tag' => @tag,
      'created_at' => @created_at,
      'age' => self.age,
      'client_ip' => @client_ip,
      'client_user_agent' => @client_user_agent
    }
  end

  def to_json
    Oj.dump self.to_hash
  end

  def sse_set_retry(ms)
    self << "retry:#{ms}\n\n"
  end

  def sse_data(data)
    self << "data:#{data}\n\n"
  end

  def sse_event_data(event,data)
    self << "event:#{event}\ndata:#{data}\n\n"
  end
end

# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "logstash/json"
require "stud/buffer"


# This output lets you send metrics to
# DataDogHQ based on Logstash events.

# Default `queue_size` and `timeframe` are low in order to provide near realtime alerting.
# If you do not use Datadog for alerting, consider raising these thresholds.
module LogStash module Outputs class DatadogMetrics < LogStash::Outputs::Base

  include Stud::Buffer

  config_name "datadog_gauge"

  # Your DatadogHQ API key. https://app.datadoghq.com/account/settings#api
  config :api_key, :validate => :string, :required => true

  # The name of the time series.
  config :metric_name, :validate => :string, :required => true

  # The name of the host that produced the metric.
  config :host, :validate => :string, :default => "%{host}"

  # Set any custom tags for this event,
  # default are the Logstash tags if any.
  config :dd_tags, :validate => :array

  # How many events to queue before flushing to Datadog
  # prior to schedule set in `@timeframe`
  config :queue_size, :validate => :number, :default => 10

  # How often (in seconds) to flush queued events to Datadog
  config :timeframe, :validate => :number, :default => 10

  public

  def register
    require "net/https"
    require "uri"

    @url = "https://app.datadoghq.com/api/v1/series"
    @uri = URI.parse(@url)
    @client = Net::HTTP.new(@uri.host, @uri.port)
    @client.use_ssl = true
    @client.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @logger.debug("Client", :client => @client.inspect)
    buffer_initialize(
      :max_items => @queue_size,
      :max_interval => @timeframe,
      :logger => @logger
    )
  end # def register

  def receive(event)
    ##########################################################################
    # IST UPDATE:
    # We don't need to push individual event data anymore since we aggregate
    # the events ourselves now. I'm not going to mess with any of the event
    # buffer logic because it's working as-is.
    ##########################################################################
    dd_metrics = Hash.new
    @logger.info("Queueing event", :event => dd_metrics)
    buffer_receive(dd_metrics)
  end

  def flush(events, final=false)
    events_arr = Array(events).flatten

    # Must be wrapped in array according to API
    dd_series = {'series' => [construct_metric_data(events_arr)] }

    request = Net::HTTP::Post.new("#{@uri.path}?api_key=#{@api_key}")

    begin
      request.body = series_to_json(dd_series)
      puts request.body
      request.add_field("Content-Type", 'application/json')
      response = @client.request(request)
      @logger.info("DD convo", :request => request.inspect, :response => response.inspect)
      raise unless response.code == '202'
    rescue Exception => e
      @logger.warn("Unhandled exception", :request => request.inspect, :response => response.inspect, :exception => e.inspect)
    end
  end

  private
  ##########################################################################
  # IST UPDATE:
  # Since the Datadog API only accepts guage metric requests and the
  # original logstash datadog plugin forces us to hardcode a metric value,
  # we just count the number of events present in the queue when flushing
  ##########################################################################
  def construct_metric_data(events_arr)
    now = Time.now.to_i
    num_log_entries = events_arr.size
    metric_data = {
      'metric' => @metric_name,
      'host' => @host,

      # Gauge is the only valid metric for the API
      'type' => 'gauge'
    }

    if @dd_tags
      metric_data['tags'] = @dd_tags
    end

    # Nested array required by API.
    # Float point metric value required by API
    metric_data['points'] = [[now, num_log_entries.to_f]]

    return metric_data
  end


  def series_to_json(series)
    LogStash::Json.dump(series)
  end

  def to_epoch(t)
    Integer(t.is_a?(String) ? Time.parse(t) : t)
  end

end end end # class LogStash::Outputs::DatadogMetrics

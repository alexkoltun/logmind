require "logstash/namespace"
require "logstash/outputs/base"

# This output lets you store logs in elasticsearch and is the most recommended
# output for logstash. If you plan on using the logstash web interface, you'll
# need to use this output.
#
#   *VERSION NOTE*: Your elasticsearch cluster must be running elasticsearch
#   %ELASTICSEARCH_VERSION%. If you use any other version of elasticsearch,
#   you should consider using the [elasticsearch_http](elasticsearch_http)
#   output instead.
#
# If you want to set other elasticsearch options that are not exposed directly
# as config options, there are two options:
#
# * create an elasticsearch.yml file in the $PWD of the logstash process
# * pass in es.* java properties (java -Des.node.foo= or ruby -J-Des.node.foo=)
#
# This plugin will join your elasticsearch cluster, so it will show up in
# elasticsearch's cluster health status.
#
# You can learn more about elasticsearch at <http://elasticsearch.org>
class LogStash::Outputs::ElasticLastEvents < LogStash::Outputs::Base

  config_name "elasticlastevents"
  plugin_status "beta"

  # The index to write events to. This can be dynamic using the %{foo} syntax.
  # The default value will partition your indices by day so you can more easily
  # delete old data or only search specific date ranges.
  config :index, :validate => :string, :default => "logstash-last"

  # The index type to write events to. Generally you should try to write only
  # similar events to the same 'type'. String expansion '%{foo}' works here.
  config :index_type, :validate => :string, :default => "%{@type}"

  # The amount of time in seconds that plugin will index 
  # the last event to the elastic search
  config :index_interval, :validate => :number, :default => 60
  # The document ID for the index. Useful for overwriting existing entries in
  # elasticsearch with the same ID.
  config :document_id, :validate => :string, :default => nil

  # The name of your cluster if you set it on the ElasticSearch side. Useful
  # for discovery.
  config :cluster, :validate => :string

  # The name/address of the host to use for ElasticSearch unicast discovery
  # This is only required if the normal multicast/cluster discovery stuff won't
  # work in your environment.
  config :host, :validate => :string

  # The port for ElasticSearch transport to use. This is *not* the ElasticSearch
  # REST API port (normally 9200).
  config :port, :validate => :number, :default => 9300

  # The name/address of the host to bind to for ElasticSearch clustering
  config :bind_host, :validate => :string

  # Run the elasticsearch server embedded in this process.
  # This option is useful if you want to run a single logstash process that
  # handles log processing and indexing; it saves you from needing to run
  # a separate elasticsearch process.
  config :embedded, :validate => :boolean, :default => false

  # If you are running the embedded elasticsearch server, you can set the http
  # port it listens on here; it is not common to need this setting changed from
  # default.
  config :embedded_http_port, :validate => :string, :default => "9200-9300"

  # Configure the maximum number of in-flight requests to ElasticSearch.
  #
  # Note: This setting may be removed in the future.
  config :max_inflight_requests, :validate => :number, :default => 50

  # The node name ES will use when joining a cluster.
  #
  # By default, this is generated internally by the ES client.
  config :node_name, :validate => :string

  public
  def register
    # TODO(sissel): find a better way of declaring where the elasticsearch
    # libraries are
    # TODO(sissel): can skip this step if we're running from a jar.
    jarpath = File.join(File.dirname(__FILE__), "../../../vendor/**/*.jar")
    Dir[jarpath].each do |jar|
        require jar
    end

    # setup log4j properties for elasticsearch
    @logger.setup_log4j

    if @embedded
      # Default @host with embedded to localhost. This should help avoid
      # newbies tripping on ubuntu and other distros that have a default
      # firewall that blocks multicast.
      @host ||= "localhost"

      # Start elasticsearch local.
      start_local_elasticsearch
    end
    require "jruby-elasticsearch"

    @logger.info("New ElasticSearchLastEvents output", :cluster => @cluster,
                 :host => @host, :port => @port, :embedded => @embedded, :index_interval => @index_interval)
    #@pending = []
	@eventsMap = Hash.new
	
    options = {
      :cluster => @cluster,
      :host => @host,
      :port => @port,
      :bind_host => @bind_host,
      :node_name => @node_name,
    }

    # TODO(sissel): Support 'transport client'
    options[:type] = :node

    @client = ElasticSearch::Client.new(options)
    @inflight_mutex = Mutex.new

	@esThread = Thread.start() do
		loop do
			begin
				clonedEvents = Hash.new
				@inflight_mutex.synchronize do
					clonedEvents = @eventsMap.clone
					@eventsMap.clear
					#@logger.info("cleared hash size", :size => @eventsMap.size);
				end
				if (clonedEvents.size > 0)
					@logger.info("events hash size", :size => clonedEvents.size);
					
					clonedEvents.each_pair do |k,v|
						event = v
						index = event.sprintf(@index)
						type = event.sprintf(@index_type)
						id = event.sprintf(k)
						
						#@logger.info("details", :index => index, :type => type, :id => id);
						
						req = @client.index(index, type, id, event.to_hash)
						
						req.on(:success) do |response|
							@logger.debug("Successfully indexed", :event => event.to_hash)
							#timer.stop
							#decrement_inflight_request_count
						end.on(:failure) do |exception|
							@logger.warn("Failed to index an event, will retry", :exception => exception,
								:event => event.to_hash)
							#timer.stop
							#decrement_inflight_request_count

							# Failed to index, try again after a short sleep (incase our hammering is
							# the problem).
							sleep(0.200)
							receive(event)
						end

						# Execute this request asynchronously.
						req.execute
					end #hash loop
				else
					#@logger.info("thread zero hash");
				end
			
				sleep(@index_interval)
			rescue => e
				@logger.warn("exception", :exception => e, :backtrace => e.backtrace)
			end #rescue
		end #thread loop
	end #thread method

  end # def register

  protected
  def start_local_elasticsearch
    @logger.info("Starting embedded ElasticSearch local node.")
    builder = org.elasticsearch.node.NodeBuilder.nodeBuilder
    # Disable 'local only' - LOGSTASH-277
    #builder.local(true)
    builder.settings.put("cluster.name", @cluster) if !@cluster.nil?
    builder.settings.put("node.name", @node_name) if !@node_name.nil?
    builder.settings.put("http.port", @embedded_http_port)

    @embedded_elasticsearch = builder.node
    @embedded_elasticsearch.start
  end # def start_local_elasticsearch

  public
  def receive(event)
    return unless output?(event)

    index = event.sprintf(@index)
    type = event.sprintf(@index_type)
	
	fieldsMap = event.to_hash
	src = fieldsMap["@source"]
	
	@inflight_mutex.synchronize do
		#@logger.info("hash size before add", :size => @eventsMap.size);
		@eventsMap[src] = event
		#@logger.info("hash size after add", :size => @eventsMap.size);
		#@logger.info(@eventsMap[src])
	end
    
  end # def receive

end # class LogStash::Outputs::Elasticsearch

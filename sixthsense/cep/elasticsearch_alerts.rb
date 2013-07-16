require "logstash/namespace"
require "logstash/outputs/base"
require "java"
	
	require 'esper/esper-4.9.0.jar'	
	require 'esper/lib/commons-logging-1.1.1.jar'
	require 'esper/lib/antlr-runtime-3.2.jar'
	require 'esper/lib/cglib-nodep-2.2.jar'
	
	java_import 'com.espertech.esper.client.EPRuntime'
	java_import 'com.espertech.esper.client.EPServiceProviderManager'
	java_import 'com.espertech.esper.client.EPServiceProvider'
	java_import 'com.espertech.esper.client.EPStatement'
 
	java_import 'com.espertech.esper.client.UpdateListener'
	java_import 'com.espertech.esper.client.EventBean'
	java_import 'org.apache.commons.logging.Log'
	java_import 'org.apache.commons.logging.LogFactory'
 
# This output lets you store logs in elasticsearch.
#
# This plugin uses the HTTP/REST interface to ElasticSearch, which usually
# lets you use any version of elasticsearch server. It is known to work
# with elasticsearch %ELASTICSEARCH_VERSION%
#
# You can learn more about elasticsearch at <http://elasticsearch.org>

  # Create a listener object
class MyUnmatchedListener
  include com.espertech.esper.client.UnmatchedListener

  @logger
  
  def set_logger(logger)
	@logger = logger
	@logger.info("esper un logger method")
  end
  
  def update(event)
	@logger.info("from esper unmatched")
    #@logger.info("from esper unmatched: ", :unmatched => event.getProperties.inspect)
  end
end
class MyListener
  include com.espertech.esper.client.UpdateListener

  @logger
  
  def set_logger(logger)
	@logger = logger
	@logger.info("esper logger method")
  end
  
  def update(newEvents, oldEvents)
    @logger.info("update with match")
	#puts "matched: "
    newEvents.each do |event|
      #puts "- " + event.getUnderlying.inspect
	  #@logger.info("from esper", :matched => event)
    end
  end
end

class LogStash::Outputs::ElasticSearch_Alerts1 < LogStash::Outputs::Base

  config_name "elasticsearch_alerts1"
  plugin_status "beta"

  # The index to write events to. This can be dynamic using the %{foo} syntax.
  # The default value will partition your indices by day so you can more easily
  # delete old data or only search specific date ranges.
  config :index, :validate => :string, :default => "logstash-%{+YYYY.MM.dd}"

  # The index type to write events to. Generally you should try to write only
  # similar events to the same 'type'. String expansion '%{foo}' works here.
  config :index_type, :validate => :string, :default => "%{@type}"

  # The name/address of the host to use for ElasticSearch unicast discovery
  # This is only required if the normal multicast/cluster discovery stuff won't
  # work in your environment.
  config :host, :validate => :string

  # The port for ElasticSearch transport to use. This is *not* the ElasticSearch
  # REST API port (normally 9200).
  config :port, :validate => :number, :default => 9200

  config :openmind_index, :validate => :string, :default => "openmind-management"
  
  config :alerts_index, :validate => :string, :default => "alerts_index"

  config :rule_type, :validate => :string, :default => "cep_rule"
  
  # Set the number of events to queue up before writing to elasticsearch.
  #
  # If this value is set to 1, the normal ['index
  # api'](http://www.elasticsearch.org/guide/reference/api/index_.html).
  # Otherwise, the [bulk
  # api](http://www.elasticsearch.org/guide/reference/api/bulk.html) will
  # be used.
  config :flush_size, :validate => :number, :default => 100

  # The document ID for the index. Useful for overwriting existing entries in
  # elasticsearch with the same ID.
  config :document_id, :validate => :string, :default => nil

  @ep_service
  @statement
  @listener
  @un_listener
  @ep_rt
  public
  def register
  
	@logger.info("before jar")
	
	@ep_service = com.espertech.esper.client.EPServiceProviderManager.getDefaultProvider

	# And the configuration
	ep_config = @ep_service.getEPAdministrator.getConfiguration

	@logger.info("after get config, adding event type")
	
	order_event_type = {
		"f" => {}
	}
	ep_config.addEventType("logmind", order_event_type)
	
	@logger.info("added event type")
	
	expression = "select * from logmind where cast(f('Index')?,double) > 50000"
	@statement = @ep_service.getEPAdministrator.createEPL(expression)
	
	@logger.info("after jar and compile")
	
    require "ftw" # gem ftw
    @agent = FTW::Agent.new
    @queue = []
	
	@live_alerts = Hash.new
	
	#listener = MyListener.new

	@un_listener = MyUnmatchedListener.new
	@un_listener.set_logger(@logger)
	
	@ep_service.getEPRuntime.setUnmatchedListener(@un_listener)
	
	@logger.info("after set unmatched")
	
	@listener = MyListener.new
	@logger.info("after new")
	@listener.set_logger(@logger)
	@logger.info("after logger")
	@statement.addListener(@listener)
	
	#@ep_service.getEPRuntime
	#register_alerts
	
	@logger.info("done register")
  end # def register

  public 
  def register_alerts
  
	# get all alrets definitions from alert_conf index
	get_url = "http://#{@host}:#{@port}/#{@openmind_index}/#{@rule_type}/_search"
	request = @agent.get(get_url)
	conf_response = @agent.execute(request)
	
	jsonRes = conf_response.body.read
	#@logger.info("alerts_defs", :json_res => jsonRes)
	jsonObj = JSON.parse(jsonRes)
	
	t = Time.now
	#formatted_index = "logstash-" + t.strftime("%Y.%m.%d")
	@logger.info("formatted_index", :formatted_index => formatted_index)
	
	# loop through all the queries
	jsonObj["hits"]["hits"].each do |q|
		
		# TODO, ?
		#@live_alerts[q["_id"]] = q
		
		# form percolator api url
		perc_url = "http://#{@host}:#{@port}/_percolator/#{formatted_index}/#{q["_source"]["name"]}"
		
		#p_query = "{ \"query\" : { \"term\" : { \"field1\" : \"value1\" }} }"
		# take the acual query syntax
		perc_query = q["_source"]["holder"]
		
		#@logger.info("perc_url", :perc_url => perc_url)
		@logger.info("perc_query", :query => perc_query)
		
		perc_response = @agent.put!(perc_url, :body =>  perc_query) 
		
		@logger.info("register_percolators", :registered_alert => q["_source"]["name"])
		# TODO, read the body for errors.. try/catch
		#body = "";
		#response.read_body { |chunk| body += chunk }
	end
	
  end
  
  private
  def load_rules
	get_url = "http://#{@host}:#{@port}/#{@alerts_conf}/#{@alerts_type}/_search"
	request = @agent.get(get_url)
	conf_response = @agent.execute(request)
	
	jsonRes = conf_response.body.read
	#@logger.info("alerts_defs", :json_res => jsonRes)
	jsonObj = JSON.parse(jsonRes)
	
	# TODO
	
	
  end
  
  public
  def receive(event)
    return unless output?(event)

    index = event.sprintf(@index)
    type = event.sprintf(@index_type)

	fields = Hash.new 
	fields["f"] = event["@fields"]
	@logger.info("all flds", :flds => fields)
	
	@ep_service.getEPRuntime.sendEvent(fields)
	
	@logger.info("after send", :flds => fields)
	
	# TODO, how us bulk?
    #if @flush_size == 1
    #receive_single(event, index, type)
    #else
    #  receive_bulk(event, index, type)
    #end # 
  end # def receive

  def receive_single(event, index, type)
    success = false
    while !success
      response = @agent.post!("http://#{@host}:#{@port}/#{index}/#{type}?percolate=*",
                              :body => event.to_json)
      # We must read the body to free up this connection for reuse.
      body = "";
      response.read_body { |chunk| body += chunk }

	  @logger.info("percolation_res", :percolation_res => body)
	  
	  
      if response.status != 201
        @logger.error("Error writing to elasticsearch",
                      :response => response, :response_body => body)
      else # sucess, try to index the event is got match
		
		index_res = JSON.parse(body)
		if (index_res["matches"].length > 0)
			# index the event
			@logger.info("index_res", :index_res => index_res["matches"])
			first_index_uri = "http://#{@host}:#{@port}/#{@alerts_index}/#{type}"
			
			map = event.to_hash
			map["matched_queries"] = index_res["matches"]
			map["from_index"] = index_res["_index"]
			
			# TODO, ttl per document... not sure if possible..
			response = @agent.post!(first_index_uri, :body => map.to_json)
			
			body = "";
			response.read_body { |chunk| body += chunk }

			@logger.info("first_index_res", :first_index_res => body)
	  
		end
        success = true
      end
    end
  end # def receive_single

  def receive_bulk(event, index, type)
    header = { "index" => { "_index" => index, "_type" => type } }
    if !@document_id.nil?
      header["index"]["_id"] = event.sprintf(@document_id)
    end
    @queue << [
      header.to_json, event.to_json
    ].join("\n")

    # Keep trying to flush while the queue is full.
    # This will cause retries in flushing if the flush fails.
    flush while @queue.size >= @flush_size
  end # def receive_bulk

  def flush
    @logger.debug? && @logger.debug("Flushing events to elasticsearch",
                                    :count => @queue.count)
    # If we don't tack a trailing newline at the end, elasticsearch
    # doesn't seem to process the last event in this bulk index call.
    #
    # as documented here: 
    # http://www.elasticsearch.org/guide/reference/api/bulk.html
    #  "NOTE: the final line of data must end with a newline character \n."
    response = @agent.post!("http://#{@host}:#{@port}/_bulk",
                            :body => @queue.join("\n") + "\n")

    # Consume the body for error checking
    # This will also free up the connection for reuse.
    body = ""
    response.read_body { |chunk| body += chunk }

    if response.status != 200
      @logger.error("Error writing (bulk) to elasticsearch",
                    :response => response, :response_body => body,
                    :request_body => @queue.join("\n"))
      return
    end

    # Clear the queue on success only.
    @queue.clear
  end # def flush

  def teardown
    flush while @queue.size > 0
  end # def teardown

  # THIS IS NOT USED YET. SEE LOGSTASH-592
  def setup_index_template
  
  
    template_name = "logstash-template"
    template_wildcard = @index.gsub(/%{[^}+]}/, "*")
    template_config = {
      "template" => template_wildcard,
      "settings" => {
        "number_of_shards" => 5,
        "index.compress.stored" => true,
        "index.query.default_field" => "@message"
      },
      "mappings" => {
        "_default_" => {
          "_all" => { "enabled" => false } 
        }
      }
    } # template_config

    @logger.info("Setting up index template", :name => template_name,
                 :config => template_config)
    begin
      success = false
      while !success
        response = @agent.put!("http://#{@host}:#{@port}/_template/#{template_name}",
                               :body => template_config.to_json)
        if response.error?
          body = ""
          response.read_body { |c| body << c }
          @logger.warn("Failure setting up elasticsearch index template, will retry...",
                       :status => response.status, :response => body)
          sleep(1)
        else
          success = true
        end
      end
    rescue => e
      @logger.warn("Failure setting up elasticsearch index template, will retry...",
                   :exception => e)
      sleep(1)
      retry
    end
  end # def setup_index_template
  end # class LogStash::Outputs::ElasticSearchHTTP

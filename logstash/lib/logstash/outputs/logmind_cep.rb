require "logstash/namespace"
require "logstash/outputs/base"
require "java"


require 'esper/esper-4.9.0.jar'	
require 'esper/lib/commons-logging-1.1.1.jar'
require 'esper/lib/antlr-runtime-3.2.jar'
require 'esper/lib/cglib-nodep-2.2.jar'

java_import 'java.util.HashMap'
	
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
    
	@logger.info("from esper unmatched", :e => event.getEventType())
	@logger.info("from esper unmatched", :e => event.getEventType().getPropertyNames())
    #@logger.info("from esper unmatched: ", :unmatched => event.getProperties.inspect)
  end
end
class MyListener
  #include com.espertech.esper.client.UpdateListener
  include com.espertech.esper.client.StatementAwareUpdateListener
  @logger
  
  def set_logger(logger)
	@logger = logger
  end
  
  def set_input_queue(input_queue)
	@input_queue = input_queue
	@logger.info("input queue was set to listener")
  end 
  
  def set_notification(notificaiton_data)
	@notificaiton_data = notificaiton_data
  end
  
  def set_outtype(outtype)
	@outtype = outtype
  end
  def update(newEvents, oldEvents,statement,epServiceProvider)
  
    #@logger.info("update with match from rule", :name => statement.getName())
	props = statement.getEventType().getPropertyNames()
	outEvent = {}
	outEvent["rule"] = statement.getName()
	outEvent["events"] = {}
    newEvents.each do |event|
	  #@logger.info("from esper", :matched => event)
		props.each do |p|
			p_val = event.get(p)
			outEvent["events"][p] = event.get(p)
		end
    end
	
	@logger.info("output from esper", :e => outEvent)
	
	e = LogStash::Event.new(outEvent)
	e['@message'] = "cep rule matched:" << statement.getName()
	e['notificaiton_data'] = @notificaiton_data
	e['@type'] = @outtype
	
	@input_queue.push(e)
	@logger.info("pushed esper event", :e => outEvent)
  end
  
  #def update(newEvents, oldEvents)
  #  @logger.info("update with match")
	#puts "matched: "
#    newEvents.each do |event|
 #     #puts "- " + event.getUnderlying.inspect
#	  event.getUnderlying()
#	  @logger.info("from esper", :matched => event.getUnderlying())
 #   end
  #end
end

class LogStash::Outputs::LogmindCep < LogStash::Outputs::Base

  config_name "logmind_cep"
  plugin_status "stable"

  # The index to write events to. This can be dynamic using the %{foo} syntax.
  # The default value will partition your indices by day so you can more easily
  # delete old data or only search specific date ranges.
  config :index, :validate => :string, :default => "logstash-%{+YYYY.MM.dd}"

  # The index type to write events to. Generally you should try to write only
  # similar events to the same 'type'. String expansion '%{foo}' works here.
  config :out_type, :validate => :string, :default => "cep_alert"

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
  
  config :openmind_perc_index, :validate => :string, :default => "openmind-perc"
  
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
  #@listener
  @un_listener
  @ep_rt
  
  # preserve all epl statements instances
  @statements
  
  private 
  def create_esper_engine
	@logger.info("creating esper runtime")
	@ep_service = com.espertech.esper.client.EPServiceProviderManager.getDefaultProvider

	# And the configuration
	ep_config = @ep_service.getEPAdministrator.getConfiguration
	ep_config.addEventType("logmind", {})
	
	#@listener = MyListener.new
	#@listener.set_logger(@logger)
	
	@un_listener = MyUnmatchedListener.new
	@un_listener.set_logger(@logger)
		
	@ep_service.getEPRuntime.setUnmatchedListener(@un_listener)
	@logger.info("creating esper runtime - done")
  end

  public
  def set_input_queue(input_queue)
	@input_queue = input_queue
	@logger.info("set_input_queue!!!")
  end  
  public
  def register
    begin
		
		require "ftw" # gem ftw
		@agent = FTW::Agent.new
		
		create_esper_engine()
		load_rules()
		
		#where (cast(index,int) > 50)
		#expression = "SELECT * FROM logmind WHERE cast(test?,string) like 'a%'"
		#expression = "SELECT * FROM logmind WHERE cast(index?,int) > 100"
		
		#@statement = @ep_service.getEPAdministrator.createEPL(expression)
		
		@queue = []
		
		@live_alerts = Hash.new
		
		@logger.info("DONE REGISTER")
	rescue Exception => e
		@logger.info("EXCEPTION during init", :ex => e)
	end
  end # def register
  
  private
  def load_rules
  
	@statements = Hash.new
			
	get_url = "http://#{@host}:#{@port}/#{@openmind_index}/#{@rule_type}/_search"
	
	#@logger.info("get_url", :get_url => get_url)
	request = @agent.get(get_url)
	conf_response = @agent.execute(request)
	
	jsonRes = conf_response.body.read
	jsonObj = JSON.parse(jsonRes)

	#@logger.info("rules", :rules => jsonObj)
	jsonObj["hits"]["hits"].each do |rule|
		
		#@logger.info("raw rule", :rule => rule)
		# prefix for all queries
		compiled_epl = "SELECT * FROM pattern[every "
		shouldCompile = false
		
		r = rule['_source']
		id = r['name']
		raw_qs = r['raw_queries']
		
		if (raw_qs != nil)
			#start statement
			index = 1
			
			raw_qs.each do |q|
				perc_q_name = "#{id}_#{q['id']}"
				forPatten = "#{perc_q_name}=logmind(qType?='#{perc_q_name}')"
				compiled_epl = compiled_epl << forPatten
				if (index < raw_qs.length)
					compiled_epl = compiled_epl << ' -> '
				end
				index = index + 1
			end
			if (r['time_window'] != nil)
				compiled_epl = compiled_epl << " WHERE timer:within(#{r['time_window']} sec)]"
			else
				compiled_epl = compiled_epl << ']'
			end
		
			shouldCompile = true
			@logger.info("compiled pattern", :q => compiled_epl)
			# compile it into the engine
		
		else
			@logger.info("found no raw queries for rule, ignoring", :rule_name => id)
		end
		
		# just if we have queries, go through the correlations
		if (shouldCompile)
			corrs = r['correlations']
			if (corrs != nil)
				index = 0
				@logger.info("found correlations" ,:corrs => corrs)
				parsed_cors = Array.new
				corrs.each do |c|
					temp = c["correlation"]
					if (temp != nil and temp != "")
						raw_qs.each do |q|
							perc_q_name = "#{id}_#{q['id']}"
							replace = "$#{q['id']}"
							temp.gsub!(replace,perc_q_name)
							@logger.info("temp" ,:temp => temp)
						end
						# parsed all Q's correlations, store
						parsed_cors[index] = temp
						index = index + 1
					else
						@logger.warn("found an empty correlation, skipping" ,:temp => temp)
					end
					
				end # corrs.each
				if (parsed_cors.length > 0)
					index = 1
					compiled_epl = compiled_epl << " WHERE "
					parsed_cors.each do |pc|
						compiled_epl = compiled_epl << pc
						if (index < parsed_cors.length)
							compiled_epl = compiled_epl << ' AND '
						end
						index = index + 1
					end
				end
			end
		end
		
		if (shouldCompile)
			@logger.info("final rule EPL" ,:name => id, :final_epl => compiled_epl)
			statement = @ep_service.getEPAdministrator.createEPL(compiled_epl,id)
			# create a new listener for every query, 
			# so they will run in dif esper threads
			listener = MyListener.new
			listener.set_logger(@logger)
			listener.set_input_queue(@input_queue)
			
			if (r['notification'] != nil)
				listener.set_notification(r['notification'])
			end
			
			listener.set_outtype(@out_type)
			statement.addListener(listener)
			
			@logger.info("rule was sucessfully compiled" ,:name => id)
			@statements[id] = statement
		end
		
	end # hits iteration
	
  end
  
  public
  def receive(event)
    return unless output?(event)

    #index = event.sprintf(@index)
    type = 'cep_perc' # event['@type'] #.sprintf(@out_type)
	begin
	
		# creat a new 'doc', that is ES percolate request (no index along the way)
		newEvent = Hash.new
		newEvent['doc'] = event
		
		#@logger.info("newEvent.to_json", :data => newEvent.to_json)
		response = @agent.post!("http://#{@host}:#{@port}/#{@openmind_perc_index}/#{type}/_percolate", :body => newEvent.to_json)
		body = "";
		response.read_body { |chunk| body += chunk }

		@logger.info("percolation_res", :percolation_res => body)

		if response.status != 200
			@logger.error("Error during ES percolation",:response => response, :response_body => body)
			return
		end
		
		index_res = JSON.parse(body)
		# found percolation match
		if (index_res["matches"] != nil and index_res["matches"].length > 0)
			#@logger.info("index_res", :index_res => index_res["matches"])
			#create an esper event for every match
			index_res["matches"].each do |match|
				esperEvent = {}
				esperEvent["qType"] = match
				event["@fields"].each do |k,v|
					esperEvent[k] = v
				end

				@ep_service.getEPRuntime.sendEvent(esperEvent,"logmind")
				logger.debug("sent the event to esper", :esperEvent => esperEvent)
			end # matches loop
		end
	rescue Exception => e
		@logger.info("EXCEPTION during receive", :ex => e)	
	end
	
	# TODO, how us bulk?
    #if @flush_size == 1
	#	receive_single(event, index, type)
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

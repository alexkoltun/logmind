require "logstash/namespace"
require "logstash/outputs/base"
require 'net/http'
require 'thread'

require "java"

require 'esper/lib/log4j-1.2.16.jar'
require 'esper/lib/commons-logging-1.1.1.jar'
require 'esper/lib/antlr-runtime-3.2.jar'
require 'esper/lib/cglib-nodep-2.2.jar'
require 'esper/esper-4.9.0.jar'

java_import 'java.util.HashMap'

java_import 'com.espertech.esper.dataflow.ops.BeaconSource'
java_import 'com.espertech.esper.client.EPRuntime'
java_import 'com.espertech.esper.client.EPServiceProviderManager'
java_import 'com.espertech.esper.client.EPServiceProvider'
java_import 'com.espertech.esper.client.EPStatement'
java_import 'com.espertech.esper.client.UpdateListener'
java_import 'com.espertech.esper.client.EventBean'
java_import 'org.apache.commons.logging.Log'
java_import 'org.apache.commons.logging.LogFactory'


# Create a listener object

class MyUnmatchedListener
  include com.espertech.esper.client.UnmatchedListener

  #@logger

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

  def set_events_queue(events_queue)
    @cep_events_queue = events_queue
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

    outEvent["events"] = {}
    newEvents.each do |event|
      #@logger.info("from esper", :matched => event)
      props.each do |p|
        p_val = event.get(p)
        outEvent["events"][p] = event.get(p)
      end
    end
    outEvent["@tags"] = ["cep-event"]

    @logger.info("output from esper", :e => outEvent)

    e = LogStash::Event.new(outEvent)
    e['@message'] = "cep rule matched:" << statement.getName()
    e['notificaiton_data'] = @notificaiton_data
    e['@type'] = @outtype

    e['rule'] = statement.getName()

    @cep_events_queue.push(e)
    @logger.info("pushed esper event", :e => e)
  end

end

# This output lets you store logs in elasticsearch.
#
# This plugin uses the HTTP/REST interface to ElasticSearch, which usually
# lets you use any version of elasticsearch server. It is known to work
# with elasticsearch %ELASTICSEARCH_VERSION%
#
# You can learn more about elasticsearch at <http://elasticsearch.org>
class LogStash::Outputs::ElasticSearchHTTPCEP < LogStash::Outputs::Base

  config_name "elasticsearch_http_cep"
  plugin_status "stable"

  config :out_type, :validate => :string, :default => "cep_alert"

  # The index to write events to. This can be dynamic using the %{foo} syntax.
  # The default value will partition your indices by day so you can more easily
  # delete old data or only search specific date ranges.
  config :index, :validate => :string, :default => "logstash-%{+YYYY.MM.dd}"

  # The index type to write events to. Generally you should try to write only
  # similar events to the same 'type'. String expansion '%{foo}' works here.
  config :index_type, :validate => :string, :default => "%{@type}"

  # The hostname or ip address to reach your elasticsearch server.
  config :host, :validate => :string

  # The port for ElasticSearch HTTP interface to use.
  config :port, :validate => :number, :default => 9200

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

  private
  def create_esper_engine
    @logger.info("creating cep engine runtime")

    @logger.debug("cep engine: getDefaultProvider")
    @ep_service = com.espertech.esper.client.EPServiceProviderManager.getDefaultProvider
    @logger.debug("cep engine: getConfiguration")
    ep_config = @ep_service.getEPAdministrator.getConfiguration
    @logger.debug("cep engine: addEventType")
    ep_config.addEventType("logmind", {})

    @logger.debug("cep engine: MyUnmatchedListener.new")
    @un_listener = MyUnmatchedListener.new
    @un_listener.set_logger(@logger)

    @logger.debug("cep engine: setUnmatchedListener")
    @ep_service.getEPRuntime.setUnmatchedListener(@un_listener)
    @logger.info("done creating cep engine runtime")
  end

  public
  def set_input_queue(input_queue)
    @logger.debug("cep engine: set_input_queue")
    @input_queue = input_queue
  end

  public
  def register
  	@http_agent = Net::HTTP.new(@host, @port)
    @queue = []
    @events = []
    @cep_events_queue = Queue.new
    @cep_events_processing_thread = Thread.new do
      @logger.info('@cep_events_processing_thread started')
      loop do
        event = @cep_events_queue.pop()
        @logger.debug('@cep_events_processing_thread forwarding event', :event => event)
        @input_queue.push(event)
      end
    end

    begin
      @logger.debug('cep engine: create_esper_engine')
      create_esper_engine
      @logger.debug('cep engine: done create_esper_engine')

      @logger.debug('cep engine: load_rules')
      load_rules
      @logger.debug('cep engine: done load_rules')

      @logger.info('done cep engine register')
    rescue Exception => e
      @logger.error('cep engine: EXCEPTION during register', :ex => e, :backtrace => e.backtrace)
    end

    # set flush time as now
    @last_flush_time = Time.now
  end # def register

  private
  def load_rules

    @statements = Hash.new

    #we limit the number of rules to 1000
    get_url = "/#{@logmind_index}/#{@rule_type}/_search?size=1000"

    @logger.info("trying to load rules from", :url => get_url)

    conf_response = @http_agent.get(get_url)

    jsonRes = conf_response.body
    jsonObj = JSON.parse(jsonRes)

    #@logger.info("rules", :rules => jsonObj)
    if (jsonObj["hits"]["hits"] != nil and jsonObj["hits"]["hits"].length > 0)
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
                if (index <  parsed_cors.length)
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
          listener.set_events_queue(@cep_events_queue)

          if (r['notification'] != nil)
            listener.set_notification(r['notification'])
          end

          listener.set_outtype(@out_type)
          statement.addListener(listener)

          @logger.info("rule was sucessfully compiled" ,:name => id)
          @statements[id] = statement
        end

      end # hits iteration
    else
      @logger.warn("found zero rules")
    end
  end

  private
  def create_percolators
    # we limit the number of percolations to duplicate to 1000
    percolations_response = @http_agent.get('/_percolator/logmind-perc/_search?size=1000')
    percolations = JSON.parse(percolations_response.body)

    delete_response = @http_agent.delete("/_percolator/#{@last_index_resolved}")
    @logger.info('percolator delete response', :last_index_resolved => @last_index_resolved, :response => delete_response)

    if percolations && percolations['hits'] && percolations['hits']['hits']
      percolations['hits']['hits'].each do |percolation|
        @http_agent.post("/_percolator/#{@last_index_resolved}/#{percolation['_id']}", JSON.generate(percolation['_source']))
      end
    end

  end


  public
  def receive(event)
    return unless output?(event)

    index = event.sprintf(@index)
    type = event.sprintf(@index_type)

    if @last_index_resolved != index
      @last_index_resolved = index
      create_percolators
    end

    if @flush_size == 1
      receive_single(event, index, type)
    else
      receive_bulk(event, index, type)
    end #
  end # def receive

  def process_index_result(index_res, event)
    @logger.debug('process_index_result', :result => index_res)
    if (index_res["matches"] != nil and index_res["matches"].length > 0)
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
  end

  def receive_single(event, index, type)
    success = false
    while !success
      begin
		    response = @http_agent.post("/#{index}/#{type}?percolate=*", event.to_json)
      rescue EOFError
        @logger.warn("EOF while writing request or reading response header from elasticsearch",
                     :host => @host, :port => @port)
        next # try again
      end

      if response.code != "201"
        @logger.error("Error writing to elasticsearch",
                      :response => response, :response_body => response.body)
      else
        process_index_result JSON.parse(response.body), event
        success = true
      end
    end
  end # def receive_single

  def receive_bulk(event, index, type)
    header = { 'index' => { '_index' => index, '_type' => type, '_percolate' => '*' } }
    if !@document_id.nil?
      header["index"]["_id"] = event.sprintf(@document_id)
    end

    @events << event

    @queue << [
      header.to_json, event.to_json
    ].join("\n")

    # Keep trying to flush while the queue is full.
    # This will cause retries in flushing if the flush fails.
    while ((Time.now - @last_flush_time) > 30) || (@queue.size >= @flush_size)
      flush
      @last_flush_time = Time.now
    end
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
    begin
		  response = @http_agent.post("/_bulk", @queue.join("\n") + "\n")
      response_obj = JSON.parse(response.body)
      if response_obj && response_obj['items']
        response_obj['items'].each_with_index do |item, index|
          process_index_result (item['create'] || item['index']), @events[index]
        end
      end
    rescue EOFError
      @logger.warn("EOF while writing request or reading response header from elasticsearch",
                   :host => @host, :port => @port)
      return # abort this flush
    end

    # Consume the body for error checking
    # This will also free up the connection for reuse.
    #body = ""
    #begin
    #  response.read_body { |chunk| body += chunk }
    #rescue EOFError
    #  @logger.warn("EOF while reading response body from elasticsearch",
    #               :host => @host, :port => @port)
    #  return # abort this flush
    #end

    if response.code != "200"
      @logger.error("Error writing (bulk) to elasticsearch",
                    :code => response.code, :response => response, :response_body => response.body(),
                    :request_body => @queue.join("\n"))
      return
    end

    # Clear the queue on success only.
    @queue.clear
    @events.clear
  end # def flush

  def teardown
    flush while @queue.size > 0
    sleep(1)
    @cep_events_processing_thread && @cep_events_processing_thread.kill
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
        #response = @agent.put!("http://#{@host}:#{@port}/_template/#{template_name}", :body => template_config.to_json)
		response = nil
        if response.error?
          body = ""
          response.read_body { |c| body << c }
          @logger.warn("Failure setting up elasticsearch index template, will retry...",
                       :status => response.code, :response => body)
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

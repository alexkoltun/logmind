require 'rubygems'
require 'json'
require 'net/http'
require 'logger'
require 'time'
require 'fileutils'
require 'net/http'
require 'yaml'
require 'pp'

module GlobalConfig
  LOCAL_INDICES_DIR = ENV['LOGMIND_ES_INDICES_DIR'] ||  '/usr/local/logmind/elasticsearch/data'
end

class IndexMatcher
  def initialize(pattern, older_than)

    es_config = YAML.load_file(ENV['LOGMIND_ES_CONFIG_YAML'] || '/usr/local/logmind/elasticsearch/config/elasticsearch.yml')
    @es_cluster_name = es_config['cluster.name'] || 'elasticsearch'

    @older_than = older_than
    @pattern = pattern

    @time_format = nil

    @pattern.match(/%\{\+([^\}]+)\}/) do |match|
      @time_format = match[1]
      @pattern = @pattern.slice(0..match.begin(0)-1) + '(' + Regexp.escape(@time_format).sub('+','').gsub('YYYY', '[0-9]{4}').gsub('YY', '[0-9]{2}').gsub('MM', '[0-9]{2}').gsub('dd', '[0-9]{2}') + ')' + @pattern.slice(match.end(0)..@pattern.length-1)
    end

    @time_format && @time_format = @time_format.gsub('YYYY', '%Y').gsub('YY', '%Y').gsub('MM', '%m').gsub('dd', '%d')
  end

  def get_es_indices_dir
    GlobalConfig::LOCAL_INDICES_DIR + '/' + @es_cluster_name + '/nodes/0/indices'
  end

  def match(index)
    index.match(@pattern) do |match|
      index_date = Time.strptime(match[1], @time_format)
      return index_date < @older_than
    end
  end
end

class Archiver
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::DEBUG
    @http_client = Net::HTTP.new('localhost', 9200)
  end

  def run

    action_map = nil

#    action_map = [
#        {
#            :pattern => 'logstash-wd-%{+YYYY}',
#            :size_min => 1024*1024,
#            :size_max => nil,
#            :older_than => 60*60*24*7, # seven days
#            :action => 'RELOCATE',
#            :params => { :target => '/tmp'}
#        }
#    ]

    # load action map from elasticsearch
    actions_raw_respone = @http_client.get('/logmind-management/archive-action/_search?size=1000')
    actions_response = JSON.parse(actions_raw_respone.body)

    if(actions_response['hits'])
      action_map = actions_response['hits']['hits']
    else
      @log.error { 'Unable ro get actions from elasticsearch, response: ' + actions_raw_respone.body }
      return -1
    end


    # get stats for all indices
    stats_raw_respone = @http_client.get('/*/_stats/')
    stats_response = JSON.parse(stats_raw_respone.body)

    if !stats_response['ok']
      @log.error { 'Unable ro get indices stats, response: ' + stats_raw_respone.body }
      return -2
    end

    # walk over indices stats and see if archiving operation is needed for them
    action_map.each do |item|
      matcher = nil
      item[:older_than] && matcher = IndexMatcher.new(item[:pattern], Time.now - item[:older_than])

      if stats_response['ok']
        (indices = stats_response['indices']) && indices.each do |k,v|
          if (matcher == nil || matcher.match(k)) && (item['size_min'] == nil || v['primaries']['store']['size_in_bytes'] > item['size_min']) && (item['size_max'] == nil || v['primaries']['store']['size_in_bytes'] < item['size_max'])
            perform_action item['_source'], k
          end
        end
      else
        @log.error { 'Unable to get stats from the server, response: ' + stats_raw_respone.body }
      end
    end
  end

  def perform_action(item, index)
    case item['action']
      when 'DELETE'
        delete_raw_response = @http_client.delete('/' + index)
        delete_response = JSON.parse(delete_raw_response.body)

        return delete_response['ok']
      when 'ARCHIVE'
# 1. close the index
        close_raw_response = @http_client.post('/' + index + '/_close', '')
        close_response = JSON.parse(close_raw_response.body)
        if close_response['ok']
# 1. run archiving shell script
          return FileUtils.exec(item[:params][:archiving_script]) == 0
        end
      when 'RELOCATE'
        @log.info { 'Relocating index: ' + index + ', target: ' + item[:params][:target] }
# 0. check if we already relocated the index to the desired target
        index_dir = get_es_indices_dir + '/' + index
        index_target_dir = item[:params][:target] + '/' + index

        if Pathname.new(index_dir) == Pathname.new(index_target_dir) || (File.symlink?(index_dir) && Pathname.new(File.readlink(index_dir)) == Pathname.new(index_target_dir))
          @logger.info { 'Ignoring RELOCATE command for index: ' + index + ', reason: it seems that the index was already relocated.' }
          return 0
        end

# 1. close the index
        close_raw_response = @http_client.post('/' + index + '/_close', '')
        close_response = JSON.parse(close_raw_response.body)

        if close_response['ok']
# 2. copy the existing index data to the new location
          FileUtils.copy_entry index_dir, index_target_dir
          ## recovery: reopen the index
# 3. unlink the old index data 'link', optionally remove the files as well
          FileUtils.remove_entry index_dir
          ## recovery: reopen the index
# 4. create a symbolic link that points to a new location
          FileUtils.symlink index_target_dir, index_dir
          ## recovery: copy back and open
# 5. open the index
          open_raw_response = @http_client.post('/' + index + '/_open', '')
          open_response = JSON.parse(open_raw_response.body)
          ## recovery: manual only???

          if open_response['ok']
            return true
          end
        end
    end

    pp item, index

    return false
  end
end

archiver = Archiver.new
archiver.run
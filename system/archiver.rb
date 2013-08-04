require 'rubygems'
require 'json'
require 'net/http'
require 'logger'
require 'time'
require 'pp'

class IndexMatcher
  def initialize(pattern, older_than)
    @older_than = older_than
    @pattern = pattern

    @time_format = nil

    @pattern.match(/%\{\+([^\}]+)\}/) do |match|
      @time_format = match[1]
      @pattern = @pattern.slice(0..match.begin(0)-1) + '(' + Regexp.escape(@time_format).sub('+','').gsub('YYYY', '[0-9]{4}').gsub('YY', '[0-9]{2}').gsub('MM', '[0-9]{2}').gsub('dd', '[0-9]{2}') + ')' + @pattern.slice(match.end(0)..@pattern.length-1)
    end

    @time_format && @time_format = @time_format.gsub('YYYY', '%Y').gsub('YY', '%Y').gsub('MM', '%m').gsub('dd', '%d')
  end

  def match(index)
    index.match(@pattern) do |match|
      index_date = Time.strptime(match[1], @time_format)
      @older_than - index_date < 0
    end
  end
end

class Archiver
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::WARN
    @http_client = Net::HTTP.new('localhost', 9200)
  end

  def run

    action_map = [
        {
            :pattern => 'logstash-wd-%{+YYYY}',
            :size_min => 2048,
            :size_max => nil,
            :older_than => 60*60*24*400, # seven days
            :action => 'RELOCATE',
            :params => ['/tmp/new_data']
        }
    ]

    matcher = IndexMatcher.new(action_map[0][:pattern], Time.now - action_map[0][:older_than])

    stats_raw_respone = @http_client.get('/*/_stats/')
    stats_response = JSON.parse(stats_raw_respone.body)

    if stats_response['ok']
      (indices = stats_response['indices']) && indices.each do |k,v|
        if matcher.match(k)
          print "Matched: #{k}\n"
        end
      end
    else
      @log.error { 'Unable to get stats from the server: ' + stats_raw_respone.body }
    end

  end
end

archiver = Archiver.new
archiver.run
require "logstash/inputs/base"
require "logstash/namespace"
require "rubygems"
require "java"
require "pathname"
require "digest/md5"

#require "jdbc/mysql"
#java_import "com.mysql.jdbc.Driver"


class LogStash::Inputs::GenericDb < LogStash::Inputs::Base
  config_name "genericdb"
  plugin_status "beta"

  config :jdbc_adapter, :validate => :string	
  config :jdbc_connection, :validate => :string
  config :db_user, :validate => :string
  config :db_pass, :validate => :string
  
  config :polling_interval, :validate => :number, :default => 60
  config :anchor_fld_name, :validate => :string
  config :anchor_default_val, :validate => :string
  config :exec_statement, :validate => :string
  
  # Where to write the since database (keeps track of the current
  # position of monitored log files). Defaults to the value of
  # environment variable "$SINCEDB_PATH" or "$HOME/.sincedb".
  config :sincedb_path, :validate => :string
  
  @connection
  @last_anchor
  
  public
  def initialize(params)
    super
    #@logger.warn("connection_1", :jdbc_connection => jdbc_connection, :user => db_user, :pass => db_pass)
	
	#"jdbc:mysql://localhost:3306/sakila"
    #@connection = java.sql.DriverManager.getConnection(jdbc_connection, db_user, db_pass)
	
	#require jdbc_adapter
	
	
	
  end

  public
  def register
	if @sincedb_path.nil?
      if ENV["HOME"].nil?
        @logger.error("No HOME environment variable set, I don't know where " \
                      "to keep track of the files I'm watching. Either set " \
                      "HOME in your environment, or set sincedb_path in " \
                      "in your logstash config for the file input with " \
                      "path '#{@path.inspect}'")
        raise # TODO(sissel): HOW DO I FAIL PROPERLY YO
      end
	  # Join by ',' to make it easy for folks to know their own sincedb
	  # generated path (vs, say, inspecting the @path array)
	  @sincedb_path = File.join(ENV["HOME"], ".sincedb_" + Digest::MD5.hexdigest(@path.join(",")))
	end 
	
	read_last_anchor
	if (@last_anchor.nil?)
		@logger.info("last anchor is nil from file, fallback to config")
		@last_anchor = anchor_default_val
	else
		@logger.info("last anchor from file", :last => @last_anchor)
	end
	
	if (@last_anchor.nil?)
		@logger.error("after fallback, last_anchor is nil, can't run")
		raise
	end
	
  end # def register

  public
  def run(queue)
    
	source = "genericDb://#{type}"
	
	loop do
	
		initCon
		
		# prepare statement with anchor fld
		sql = exec_statement.sub("?",@last_anchor)
		
		@logger.info("query", :sql => sql);
		result = select(sql)
		
		if (!result.nil? and result.size > 0)
			@logger.info("details", :resSize => result.size);
		
			result.each { |l|
				hash = Hash.new
				l.each { |k,v|
					hash[k] = v
				}
				e = to_event(hash.to_json, source)
				if e
					queue << e
				end
			}	
		
			last_event = result.last
			@last_anchor = last_event[anchor_fld_name]
			#@logger.warn("last anchor is", :last => @last_anchor)
			
			# store the last_anchor at db file..
			store_last_anchor
		else
			@logger.info("got nil or empty result from query")
		end
		
		closeCon
		
		@logger.info("next polling is within",:seconds => polling_interval)
		sleep polling_interval
	end # of loop
	
  end # def run

  private
  def initCon
	@connection = java.sql.DriverManager.getConnection(jdbc_connection, db_user, db_pass)
  end
  
  private
  def closeCon
	if !@connection.nil? 
		@connection.close
	end
  end
  
  def select(sql)
    stmt = @connection.createStatement
    resultSet = stmt.executeQuery(sql)

    meta = resultSet.getMetaData
    column_count = meta.getColumnCount

    rows = []

    while resultSet.next
      res = {}

      (1..column_count).each do |i|
        name = meta.getColumnName(i)
        case meta.getColumnType(i)
        when java.sql.Types::INTEGER
          res[name] = resultSet.getInt(name)
        else
          res[name] = resultSet.getString(name)
        end
      end

      rows << res
    end

    stmt.close
    return rows
  end # def select

  private
  def store_last_anchor
	path = @sincedb_path
	begin
		db = File.open(path, "w")
	rescue
        @logger.debug("store_last_anchor: #{path}: #{$!}")
        return
	end
	db.puts(@last_anchor)
    db.close
  end # def store_last_anchor
  
  private
  def read_last_anchor
	path = @sincedb_path
	begin
		db = File.open(path,"rb")
	rescue
		@logger.debug("read_last_anchor: #{path}: #{$!}")
		return
	end

	@logger.debug("read_last_anchor: reading from #{path}")
	@last_anchor = db.read.strip
  end # def sread_last_anchor
  
 end # class LogStash::Inputs::GenericDb

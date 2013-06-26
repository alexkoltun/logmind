require 'rubygems'
require 'sinatra'
require 'json'
require 'time'
require 'date'
require 'rss/maker'
require 'yaml'
require 'tzinfo'
require 'grok-pure'
require 'find'
require 'curl'

$LOAD_PATH << '.'
$LOAD_PATH << './lib'

if ENV["KIBANA_CONFIG"]
  require ENV["KIBANA_CONFIG"]
else
  require 'KibanaConfig'
end
Dir['./lib/*.rb'].each{ |f| require f }

ruby_18 { require 'fastercsv' }
ruby_19 { require 'csv' }

configure do
  set :bind, defined?(KibanaConfig::KibanaHost) ? KibanaConfig::KibanaHost : '0.0.0.0'
  set :port, KibanaConfig::KibanaPort
  set :public_folder, Proc.new { File.join(root, "static") }
 # enable :sessions
  use Rack::Session::Cookie, :key => 'rack.session',
      :path => '/',
      :secret => 'logmind_prime1!',
      :httponly => false

  @@users_module = nil
  begin
    if KibanaConfig::Users_module != ""
      require "./lib/modules/users_#{KibanaConfig::Users_module}"
      @@users_module = get_users_module(KibanaConfig)
    end
  rescue
    puts "Failed to load the users module: #{KibanaConfig::Users_module}"
  end

  @@auth_module = nil
  begin
    if KibanaConfig::Auth_module != ""
      require "./lib/modules/auth_#{KibanaConfig::Auth_module}"
      @@auth_module = get_auth_module(KibanaConfig)
    end
  rescue
    puts "Failed to load the auth module: #{KibanaConfig::Auth_module}"
  end

  @@storage_module = nil
  begin
    require "./lib/modules/storage_#{KibanaConfig::Storage_module}"
    @@storage_module = get_storage_module(KibanaConfig)
  rescue
    puts "Failed to load the storage module: #{KibanaConfig::Storage_module}"
  end
end

helpers do
  def js_array(name, array)

  end

  def link_to url_fragment, mode=:full_url
    case mode
    when :path_only
      base = request.script_name
    when :full_url
      if (request.scheme == 'http' && request.port == 80 ||
          request.scheme == 'https' && request.port == 443)
        port = ""
      else
        port = ":#{request.port}"
      end
      base = "#{request.scheme}://#{request.host}#{port}#{request.script_name}"
    else
      raise "Unknown script_url mode #{mode}"
    end
    "#{base}#{url_fragment}"
  end

end

before do
  if request.path.end_with?(".js")
    content_type 'text/javascript'
  end
  if @@auth_module
    unless session[:username]
      if request.path.start_with?("/api")
        # ajax api call, just return an error
        halt 401, JSON.generate({"error" => "Not logged in"})
      elsif !request.path.start_with?("/auth")
        # normal web call, redirect to login
        halt redirect '/auth/login'
      end
    else
      @user_perms = @@storage_module.get_permissions(session[:username])
      if !@user_perms
        # User is authenticated, but not authorized. Put them in
        # a holding state until an admin grants them authorization
        if request.path.start_with?("/api")
          halt 401, JSON.generate({"error" => "Not authorized for any security groups"})
        elsif !request.path.start_with?("/auth/logout")
          halt 401, "You are not authorized for any search groups. Please contact the kibana administrator to grant you permission."
        end
      else
        if !defined?(@user_perms[:tags]) || !@user_perms[:tags]
          @user_perms[:tags] = []
        end
        if !defined?(@user_perms[:is_admin]) || !@user_perms[:is_admin]
          @user_perms[:is_admin] = false
        end

        # check any groups this user belongs to for additional
        # permissions defined in the storage module
        @@users_module.membership(session[:username]).each do |group|
          g_perms = @@storage_module.get_permissions(group)
          if g_perms
            if defined?(g_perms[:tags]) and g_perms[:tags]
              @user_perms[:tags] = (@user_perms[:tags] + g_perms[:tags]).uniq
            end
            if defined?(g_perms[:is_admin])
              @user_perms[:is_admin] ||= g_perms[:is_admin]
            end
          end
        end

        if request.path.start_with?("/admin")
          # only admins get to go here
          if !@user_perms[:is_admin]
            halt 401, "You are not authorized to be here"
          end
        end
      end
    end
  end
end

get '/' do
  headers "X-Frame-Options" => "allow","X-XSS-Protection" => "0" if KibanaConfig::Allow_iframed

  locals = {}
  if @@auth_module
    locals[:username] = session[:username]
    locals[:is_admin] = @user_perms[:is_admin]
  end
  erb :index, :locals => locals
end

get '/stream' do
  send_file File.join(settings.public_folder, 'stream.html')
end

get '/auth/login' do
  locals = {}
  if !@@auth_module
    redirect '/'
  end
  if session[:login_message]
    locals[:login_message] = session[:login_message]
  end
  erb :login, :locals => locals
end

post '/auth/login' do
  if !@@auth_module
    redirect '/'
  end
  username = params[:username]
  password = params[:password]
  if @@auth_module.authenticate(username,password)

    session[:username] = username
    session[:login_message] = ""
    redirect '/'
  else
    session[:login_message] = "Invalid username or password"
    halt redirect '/auth/login'
  end
end

get '/auth/logout' do
  if !@@auth_module
    redirect '/'
  end
  session[:username] = nil
  session[:login_message] = "Successfully logged out"
  redirect '/auth/login'
end

# User/permission administration
get '/admin' do
  locals = {}
  if @@auth_module
    locals[:username] = session[:username]
    locals[:is_admin] = @user_perms[:is_admin]
    locals[:show_back] = true

    locals[:users] = []
    locals[:groups] = []

    locals[:header_title] = "Administration"
    locals[:internal_content] = true
    locals[:current_content] = "admin"
    locals[:pathtobase] = ""

    @@storage_module.get_all_permissions().each do |perm|
      if perm.username.start_with?("@")
        locals[:groups].push(perm)
      else
        locals[:users].push(perm)
      end
    end
  end
  erb :main, :locals => locals
end

get %r{/admin/([\w]+)(/[@% \w]+)?} do
  locals = {}

  locals[:header_title] = "Administration"
  locals[:internal_content] = true
  locals[:current_content] = "adminedit"
  locals[:pathtobase] = "../"

  mode = params[:captures].first
  if @@auth_module
    locals[:username] = session[:username]
    locals[:is_admin] = @user_perms[:is_admin]
    locals[:show_back] = true
    locals[:mode] = mode
    # TODO: Dynamically populate alltags
    locals[:alltags] = ['*', '_grokparsefailure']
    if mode == "edit"
      locals[:pathtobase] = "../../"
      # the second match contains the '/' at the start,
      # so we take the substring starting at position 1
      locals[:user_data] = @@storage_module.get_permissions(params[:captures][1][1..-1])
      locals[:can_delete] = (locals[:user_data][:username]==KibanaConfig::Auth_Admin_User) ? false : true
      locals[:can_change_groups] = @@users_module.respond_to?('add_user_2group')
      locals[:allgroups] = @@users_module.groups()
      # If they are a group, set group values
      if locals[:user_data][:username].start_with?("@")
        locals[:is_group]=true
        locals[:group_members] = @@users_module.group_members(locals[:user_data][:username])
        locals[:allusers] = @@users_module.users()
	locals[:type] = "Group"
      else
        locals[:can_change_pass] = @@users_module.respond_to?('set_password')
        locals[:user_groups] = @@users_module.membership(locals[:user_data][:username])
	locals[:type] = "User"
      end
    elsif mode == "newuser"
      locals[:mode] = "new"
      locals[:type] = "User"
      locals[:allgroups] = @@users_module.groups()
      locals[:can_change_pass] = @@users_module.respond_to?('set_password')
    elsif mode == "newgroup"
      locals[:mode] = "new"
      locals[:type] = "Group"
      locals[:is_group] = true
      locals[:allusers] = @@users_module.users()
    else
      halt 404, "Invalid action"
    end
  end
  erb :main, :locals => locals
end

post '/admin/save' do
  if params[:Groupname] != nil
    # prefix group name with only one @
    params[:Username]= params[:Groupname].gsub(/^@*(.*)$/, '@\1') 
  else
    # strip first @ from username
    params[:Username] = params[:Username].gsub(/^@+/, '')
  end
  # strip illegal characters from username/groupname
  username = params[:Username].gsub(/[^@0-9A-Za-z_\\.-]/, '')
  if username.length < 3
    sleep(1)
    redirect '/admin'
  end
  usertags = params[:usertags]
  if params[:delete] != nil
    puts "Deleting #{username}"
    @@storage_module.del_permissions(username)
    if username.start_with?("@")
      @@users_module.del_group(username)
    else
      @@users_module.del_user(username)
    end
  else
    if @@users_module.lookup_user(username).nil?
      puts "Creating #{username}"
      # sets password to "" if password undefined
      params[:pass1] = "" if params[:pass1].nil?
    else
      puts "Updating #{username}"
    end
    is_admin = (defined?(params[:is_admin]) && params[:is_admin] == "on") ? true : false
    @@storage_module.set_permissions(username,usertags,is_admin)
    # Update the auth group info
    if username.start_with?("@") and @@users_module.respond_to?('add_group')
      puts "username.start_with?(@)"
      members = params[:members]
      @@users_module.add_group(username, members)
    elsif params[:pass1] != nil && params[:pass1] != ""
      puts "Has password!!!"
      password = params[:pass1]
      @@users_module.set_password(username, password)
    else
      @@users_module.add_user(username, "")
    end
    user_groups = params[:user_groups]
    old_groups = @@users_module.membership(username)
    if user_groups.nil?
      #Creating group logmind if not exists:
      all_groups = @@users_module.groups()
      if all_groups == nil or not all_groups.include?("@logmind")
        @@users_module.add_group("@logmind", nil)
        @@storage_module.set_permissions("@logmind", ["*"], true)
      end

      add_groups = ["@logmind"]
      del_groups = old_groups
    elsif old_groups.nil?
      add_groups=user_groups
    else
      add_groups = user_groups-old_groups
      del_groups = old_groups-user_groups
    end
    if not add_groups.nil?
      add_groups.each do |group|
        @@users_module.add_user_2group(username, group)
      end
    end
    if not del_groups.nil?
      del_groups.each do |group|
        @@users_module.rm_user_from_group(username, group)
      end
    end
  end
  # FIXME: Find a better way to make sure the changes will show on page load
  sleep(1)
  redirect '/admin'
end

# Returns
get '/api/search/:hash/?:segment?' do
  segment = params[:segment].nil? ? 0 : params[:segment].to_i

  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,@user_perms,req.from,req.to,req.offset)
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticMulti.new(query,indices)

  # Not sure this is required. This should be able to be handled without
  # server communication
  result.response['kibana']['time'] = {
    "from" => req.from.iso8601, "to" => req.to.iso8601}
  result.response['kibana']['default_fields'] = KibanaConfig::Default_fields

  JSON.generate(result.response)
end

get '/api/graph/:mode/:interval/:hash/?:segment?' do
  segment = params[:segment].nil? ? 0 : params[:segment].to_i

  req     = ClientRequest.new(params[:hash])
  case params[:mode]
  when "count"
    query   = DateHistogram.new(req.search,@user_perms,req.from,req.to,params[:interval].to_i)
  when "mean"
    query   = StatsHistogram.new(req.search,@user_perms,req.from,req.to,req.analyze,params[:interval].to_i)
  end
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticSegment.new(query,indices,segment)

  JSON.generate(result.response)
end

get '/api/id/:id/:index' do
  ## TODO: Make this verify that the index matches the smart index pattern.
  id      = params[:id]
  index   = "#{params[:index]}"
  query   = IDQuery.new(id,@user_perms)
  result  = Kelastic.new(query,index)
  JSON.generate(result.response)
end

get '/api/analyze/:field/trend/:hash' do
  limit = KibanaConfig::Analyze_limit
  show  = KibanaConfig::Analyze_show
  req           = ClientRequest.new(params[:hash])

  query_end     = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,limit,'@timestamp','desc')
  indices_end   = Kelastic.index_range(req.from,req.to)
  result_end    = KelasticMulti.new(query_end,indices_end)

  # Oh snaps. too few results for full limit analysis, rerun with less
  if (result_end.response['hits']['hits'].length < limit)
    limit         = (result_end.response['hits']['hits'].length / 2).to_i
    query_end     = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,limit,'@timestamp','desc')
    indices_end   = Kelastic.index_range(req.from,req.to)
    result_end    = KelasticMulti.new(query_end,indices_end)
  end

  fields = Array.new
  fields = params[:field].split(',,')
  count_end     = KelasticResponse.count_field(result_end.response,fields)

  query_begin   = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,limit,'@timestamp','asc')
  indices_begin = Kelastic.index_range(req.from,req.to).reverse
  result_begin  = KelasticMulti.new(query_begin,indices_begin)
  count_begin   = KelasticResponse.count_field(result_begin.response,fields)



  # Not sure this is required. This should be able to be handled without
  # server communication
  result_end.response['kibana']['time'] = {
    "from" => req.from.iso8601, "to" => req.to.iso8601}

  final = Array.new(0)
  count = result_end.response['hits']['hits'].length
  count_end.each do |key, value|
    first = count_begin[key].nil? ? 0 : count_begin[key];
    final << {
      :id    => key,
      :count => value,
      :start => first,
      :trend => (((value.to_f / count) - (first.to_f / count)) * 100).to_f
    }
  end
  final = final.sort_by{ |hsh| hsh[:trend].abs }.reverse

  result_end.response['hits']['count'] = result_end.response['hits']['hits'].length
  result_end.response['hits']['hits'] = final[0..(show - 1)]
  JSON.generate(result_end.response)
end

get '/api/analyze/:field/terms/:hash' do
  limit   = KibanaConfig::Analyze_show
  req     = ClientRequest.new(params[:hash])
  fields = Array.new
  fields = params[:field].split(',,')
  query   = TermsFacet.new(req.search,@user_perms,req.from,req.to,fields)
  indices = Kelastic.index_range(req.from,req.to,KibanaConfig::Facet_index_limit)
  result  = KelasticMultiFlat.new(query,indices)

  # Not sure this is required. This should be able to be handled without
  # server communication
  result.response['kibana']['time'] = {
    "from" => req.from.iso8601, "to" => req.to.iso8601}

  JSON.generate(result.response)
end

get '/api/analyze/:field/score/:hash' do
  limit = KibanaConfig::Analyze_limit
  show  = KibanaConfig::Analyze_show
  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,limit)
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticMulti.new(query,indices)
  fields = Array.new
  fields = params[:field].split(',,')
  count   = KelasticResponse.count_field(result.response,fields)

  # Not sure this is required. This should be able to be handled without
  # server communication
  result.response['kibana']['time'] = {
    "from" => req.from.iso8601, "to" => req.to.iso8601}

  final = Array.new(0)
  count.each do |key, value|
    final << {
      :id    => key,
      :count => value,
    }
  end
  final = final.sort_by{ |hsh| hsh[:count].abs }.reverse

  result.response['hits']['count']  = result.response['hits']['hits'].length
  result.response['hits']['hits']   = final[0..(show - 1)]
  JSON.generate(result.response)
end

get '/api/analyze/:field/mean/:hash' do
  req     = ClientRequest.new(params[:hash])
  query   = StatsFacet.new(req.search,@user_perms,req.from,req.to,params[:field])
  indices = Kelastic.index_range(req.from,req.to,KibanaConfig::Facet_index_limit)
  type    = Kelastic.field_type(indices.first,params[:field])
  if ['long','integer','double','float'].include? type
    result  = KelasticMultiFlat.new(query,indices)

    # Not sure this is required. This should be able to be handled without
    # server communication
    result.response['kibana']['time'] = {
      "from" => req.from.iso8601, "to" => req.to.iso8601}

    JSON.generate(result.response)
  else
    JSON.generate({"error" => "Statistics not supported for type: #{type}"})
  end
end

get '/api/stream/:hash/?:from?' do
  # This is delayed by 10 seconds to account for indexing time and a small time
  # difference between us and the ES server.
  delay = 10

  # Calculate 'from'  and 'to' based on last event in stream.
  from = params[:from].nil? ? Time.now - (10 + delay) : Time.parse("#{params[:from]}+0:00")

  # ES's range filter is inclusive. delay-1 should give us the correct window. Maybe?
  to = Time.now - (delay)

  # Build and execute
  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,@user_perms,from,to,0,30)
  indices = Kelastic.index_range(from,to)
  result  = KelasticMulti.new(query,indices)
  output  = JSON.generate(result.response)

  if result.response['hits']['total'] > 0
    JSON.generate(result.response)
  end
end

get '/rss/:hash/?:count?' do
  # TODO: Make the count number above/below functional w/ hard limit setting
  count = KibanaConfig::Rss_show
  # count = params[:count].nil? ? 30 : params[:count].to_i
  span  = (60 * 60 * 24)
  from  = Time.now - span
  to    = Time.now

  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,@user_perms,from,to,0,count)
  indices = Kelastic.index_range(from,to)
  result  = KelasticMulti.new(query,indices)
  flat    = KelasticResponse.flatten_response(result.response,req.fields)

  headers "Content-Type"        => "application/rss+xml",
          "charset"             => "utf-8",
          "Content-Disposition" => "inline; filename=kibana_rss_#{Time.now.to_i}.xml"

  content = RSS::Maker.make('2.0') do |m|
    m.channel.title = "Kibana #{req.search}"
    m.channel.link  = "www.example.com"
    m.channel.description =
      "A event search for: #{req.search}.
      With title fields: #{req.fields.join(', ')} "
    m.items.do_sort = true

    result.response['hits']['hits'].each do |hit|
      i = m.items.new_item
      hash    = IdRequest.new(hit['_id'],hit['_index']).hash
      i.title = KelasticResponse.flatten_hit(hit,req.fields).join(', ')
      i.date  = Time.iso8601(KelasticResponse.get_field_value(hit,'@timestamp'))
      i.link  = link_to("/##{hash}")
      i.description = "<pre>#{hit.to_yaml}</pre>"
    end
  end
  content.to_s
end

get '/export/:hash/?:count?' do

  count = KibanaConfig::Export_show
  # TODO: Make the count number above/below functional w/ hard limit setting
  # count = params[:count].nil? ? 20000 : params[:count].to_i
  sep   = KibanaConfig::Export_delimiter

  req     = ClientRequest.new(params[:hash])
  query   = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,count)
  indices = Kelastic.index_range(req.from,req.to)
  result  = KelasticMulti.new(query,indices)
  flat    = KelasticResponse.flatten_response(result.response,req.fields)

  headers "Content-Disposition" => "attachment;filename=Kibana_#{Time.now.to_i}.csv",
    "Content-Type" => "application/octet-stream"

  if RUBY_VERSION < "1.9"
    FasterCSV.generate({:col_sep => sep}) do |file|
      file << req.fields
      flat.each { |row| file << row }
    end
  else
    CSV.generate({:col_sep => sep}) do |file|
      file << req.fields
      flat.each { |row| file << row }
    end
  end

end

post '/api/favorites' do
  if @@auth_module
    name = params[:addFavoriteInput]
    hashcode = params[:hashcode]
    user = session[:username]

    # checks if favorite name already exists
    if !name.nil? and !hashcode.nil? and name != "" and hashcode != ""
      favorites = @@storage_module.get_favorites(user)
      favorites.each do |fav|
        if fav["name"] == name
          return JSON.generate( { :success => false , :message => "Name already exists" } )
        end
      end
      # adds a new favorite
      result = @@storage_module.set_favorite(name,user,hashcode)
      return JSON.generate( { :success => result , :message => "" } )
    else
      halt 500, "Invalid action"
    end
  end
end

get '/api/favorites' do
  if @@auth_module
    user = session[:username]
    results = @@storage_module.get_favorites(user)
    JSON.generate(results)
  end
end

delete '/api/favorites' do
  if @@auth_module
    id = params[:id]
    user = session[:username]
    # check if the user owns the favorite
    if !id.nil? and id != ""
      r = @@storage_module.get_favorite(id)
      if !r.nil? and r[:user] == user
        result = @@storage_module.del_favorite(id)
        return JSON.generate( { :success => result, :message => ""} )
      else
        return JSON.generate( { :success => false, :message => "Operation not permitted" } )
      end
    else
      halt 500, "Invalid action"
    end
  end
end

get '/js/timezone.js' do
  erb :timezone
end

get '/lastevents' do
  locals = {}
  locals[:username] = session[:username]
  locals[:is_admin] = @user_perms[:is_admin]
  locals[:header_title] = "Last Events"
  locals[:internal_content] = true
  locals[:current_content] = "lastevents"
  locals[:pathtobase] = ""
  if @@auth_module
    locals[:show_back] = true

    query   = SortedQuery.new("*",@user_perms,nil,nil,nil)
    result  = Kelastic.new(query,KibanaConfig::LastEvents_index)
    #output  = JSON.generate(result.response)
    #if result.response.has_key?('hits')
    locals[:result] = result.response
    #end

  end
  erb :main, :locals => locals
end

delete '/lastevents' do
  locals = {}
  locals[:username] = session[:username]
  locals[:is_admin] = @user_perms[:is_admin]
  if @@auth_module
    id = params[:id]
    type = params[:type]

    @esf = Elasticsearchmod.new(KibanaConfig::LastEvents_index,type)
    result = @esf.del_by_id(id)
    return JSON.generate( { :success => result, :message => ""} )
  end
end

get '/indiceslist' do
  locals = {}
  locals[:username] = session[:username]
  locals[:is_admin] = @user_perms[:is_admin]
  locals[:header_title] = "Live Indices"
  locals[:internal_content] = true
  locals[:current_content] = "indiceslist"
  locals[:pathtobase] = ""
  if @@auth_module
    locals[:show_back] = true
    result = Kelastic.just_logstash_indices()
    locals[:result] = result
  end
  erb :main, :locals => locals
end


post '/indexController' do
  locals = {}
  locals[:username] = session[:username]
  locals[:is_admin] = @user_perms[:is_admin]

  if @@auth_module
    requested_action = params[:action]
    indexName = params[:indexName]

    case requested_action
      when "archive"
        @@storage_module.index_archive(indexName)
      when "restore"
        @@storage_module.index_restore(indexName)
      else
        return JSON.generate( { :success => false, :message => "Operation not permitted" } )
    end

    return JSON.generate( { :success => "ok", :message => ""} )
  end
end

get '/archivedlist' do
  locals = {}
  locals[:username] = session[:username]
  locals[:is_admin] = @user_perms[:is_admin]
  locals[:header_title] = "Archived Indices"
  locals[:internal_content] = true
  locals[:current_content] = "archivedlist"
  locals[:pathtobase] = ""
  if @@auth_module
    locals[:show_back] = true
    result = @@storage_module.archived_list()
    locals[:result] = result
  end
  erb :main, :locals => locals
end

get %r{/napi/es/(.*)} do
  q = params[:captures].first

  c = Curl::Easy.http_get("http://" + KibanaConfig::Elasticsearch + "/" + q
  ) do |curl|
    curl.headers['Accept'] = 'application/json'
    curl.headers['Content-Type'] = 'application/json'
  end

  c.body_str
end


post %r{/napi/es/(.*)} do
  q = params[:captures].first
  raw = request.env["rack.input"].read

  c = Curl::Easy.http_post("http://" + KibanaConfig::Elasticsearch + "/" + q, raw
  ) do |curl|
    curl.headers['Accept'] = 'application/json'
    curl.headers['Content-Type'] = 'application/json'
  end

  c.body_str
end


put %r{/napi/es/(.*)} do
  q = params[:captures].first
  raw = request.env["rack.input"].read

  c = Curl::Easy.http_put("http://" + KibanaConfig::Elasticsearch + "/" + q, raw
  ) do |curl|
    curl.headers['Accept'] = 'application/json'
    curl.headers['Content-Type'] = 'application/json'
  end

  c.body_str
end


delete %r{/napi/es/(.*)} do
  q = params[:captures].first
  raw = request.env["rack.input"].read

  c = Curl::Easy.http_delete("http://" + KibanaConfig::Elasticsearch + "/" + q
  ) do |curl|
    curl.headers['Accept'] = 'application/json'
    curl.headers['Content-Type'] = 'application/json'
  end

  c.body_str
end

get '/test_auth' do
  auth = Authorization.new('http://localhost:9200')
  user = auth.load_user('alex')
  scope = user.get_scope "view_data"
  allowed = user.allowed?('edit_dashboard', '#campus2_dashboards')
end

def grok
  if @grok.nil?
    @grok = Grok.new

    Dir.foreach('../sixthsense/patterns/') do |item|
      next if item == '.' or item == '..' or item == '.git'
      @grok.add_patterns_from_file(("../sixthsense/patterns/#{item}"))
    end
  end
  @grok
end

def get_files path
  dir_array = Array.new
  Find.find(path) do |f|
    if !File.directory?(f)
      #dir_array << f if !File.directory?.basename(f) # add only non-directories
      dir_array << File.basename(f, ".*")
    end
  end
  return dir_array
end

get '/grocker' do
  @tags = []
  grok.patterns.each do |x,y|
    @tags << "%{#{x}"
  end

  locals = {}
  locals[:internal_content] = true
  locals[:current_content] = "grocker"
  locals[:grocker_template] = :'grocker/index'
  locals[:pathtobase] = "../"
  erb :main, :locals => locals
end

post '/grocker/grok' do
  input = params[:input]
  pattern = params[:pattern]
  named_captures_only = (params[:named_captures_only] == "true")
  singles = (params[:singles] == "true")
  keep_empty_captures = (params[:keep_empty_captures] == "true")

  begin
    grok.compile(params[:pattern])
  rescue
    return "Compile ERROR"
  end

  matches = grok.match(params[:input])
  return "No Matches" if !matches

  fields = {}
  matches.captures.each do |key, value|
    type_coerce = nil
    is_named = false
    if key.include?(":")
      name, key, type_coerce = key.split(":")
      is_named = true
    end

    case type_coerce
      when "int"
        value = value.to_i rescue nil
      when "float"
        value = value.to_f rescue nil
    end

    if named_captures_only && !is_named
      next
    end

    if fields[key].is_a?(String)
      fields[key] = [fields[key]]
    end

    if keep_empty_captures && fields[key].nil?
      fields[key] = []
    end

    # If value is not nil, or responds to empty and is not empty, add the
    # value to the event.
    if !value.nil? && (!value.empty? rescue true)
      # Store fields as an array unless otherwise instructed with the
      # 'singles' config option
      if !fields.include?(key) and singles
        fields[key] = value
      else
        fields[key] ||= []
        fields[key] << value
      end
    end
  end

  if fields
    #pp match.captures
    return JSON.pretty_generate(fields)
  end

  return "No Matches"
end

post '/grocker/discover' do
  grok.discover(params[:input])
end


get '/grocker/discover' do
  locals = {}
  locals[:pathtobase] = "../"
  locals[:internal_content] = true
  locals[:current_content] = "grocker"
  locals[:grocker_template] = :'grocker/discover'
  erb :main, :locals => locals
end

get '/grocker/analysis' do
  locals = {}
  locals[:pathtobase] = "../"
  locals[:internal_content] = true
  locals[:current_content] = "grocker"
  locals[:grocker_template] = :'grocker/analysis'
  erb :main, :locals => locals
end

get '/grocker/patterns' do
  @arr = get_files("../sixthsense/patterns/")
  locals = {}
  locals[:pathtobase] = "../"
  locals[:internal_content] = true
  locals[:current_content] = "grocker"
  locals[:grocker_template] = :'grocker/patterns'
  erb :main, :locals => locals

end

get '/grocker/patterns/*' do
  send_file(params[:spat]) unless params[:spat].nil?
end

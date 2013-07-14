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

if ENV["LOGMIND_CONFIG"]
  require ENV["LOGMIND_CONFIG"]
else
  require 'GlobalConfig'
end
Dir['./lib/*.rb'].each{ |f| require f }

ruby_18 { require 'fastercsv' }
ruby_19 { require 'csv' }

Tire.configure do
  url 'http://' + GlobalConfig::Elasticsearch
end

configure do
  set :bind, defined?(GlobalConfig::OpenmindHost) ? GlobalConfig::OpenmindHost : '0.0.0.0'
  set :port, GlobalConfig::OpenmindPort
  set :public_folder, Proc.new { File.join(root, "static") }
 # enable :sessions
  use Rack::Session::Cookie, :key => 'rack.session',
      :path => '/',
      :secret => 'logmind_prime1!',
      :httponly => false

  auth = Authorization.new
  auth.setup_defaults_if_needed
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

#    @user = Authorization.new.load_user('admin')

  @user = session[:user]

  # login only
  unless @user
    if request.path.start_with?('/api')
      # ajax api call, just return an error
      content_type 'text/javascript'
      halt 401, JSON.generate({'error' => 'authentication_required'})
    elsif !request.path.start_with?('/auth')
      session[:redirect_url] = request.path
      # normal web call, redirect to login
      halt redirect '/auth/login'
    end
  end
end

get '/' do
  headers "X-Frame-Options" => "allow","X-XSS-Protection" => "0" if GlobalConfig::Allow_iframed
  @user.allowed?('frontend_ui_view', nil) || halt(403, 'Unauthorized')
  locals = {}
  if @user
    locals[:currentUserJson] = JSON.generate({'username' => @user.username})
  end
  erb :index, :locals => locals
end

get '/auth/login' do
  locals = {}
  login_message = session[:login_message]
  if login_message && !login_message.empty?()
    locals[:login_message] = login_message
  end
  erb :login, :locals => locals
end

post '/auth/login' do

  login = Authentication.new

  username = params[:username]
  password = params[:password]

  if login.login(username, password)
    auth = Authorization.new
    session[:user] = auth.load_user(username)
    redirect_url = session[:redirect_url]
    unless redirect_url
      redirect_url = '/'
    end

    redirect redirect_url
  else
    session[:login_message] = 'Invalid username or password'
    redirect '/auth/login'
  end
end

get '/auth/logout' do
  session[:username] = nil
  session[:login_message] = "Successfully logged out"
  redirect '/auth/login'
end

get '/rss/:hash/?:count?' do
  # TODO: Make the count number above/below functional w/ hard limit setting
  count = GlobalConfig::Rss_show
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
          "Content-Disposition" => "inline; filename=logmind_rss_#{Time.now.to_i}.xml"

  content = RSS::Maker.make('2.0') do |m|
    m.channel.title = "Logmind #{req.search}"
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

  count = GlobalConfig::Export_show
  # TODO: Make the count number above/below functional w/ hard limit setting
  # count = params[:count].nil? ? 20000 : params[:count].to_i
  sep   = GlobalConfig::Export_delimiter

#  req     = ClientRequest.new(params[:hash])
#  query   = SortedQuery.new(req.search,@user_perms,req.from,req.to,0,count)
#  indices = Kelastic.index_range(req.from,req.to)
#  result  = KelasticMulti.new(query,indices)
#  flat    = KelasticResponse.flatten_response(result.response,req.fields)

  headers "Content-Disposition" => "attachment;filename=Logmind_#{Time.now.to_i}.csv",
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

#
# Index API - /api/idx
# helpers too
#

def get_request_json
  raw = request.env["rack.input"].read

  data = nil

  if raw && !raw.empty?
    data = JSON.parse (raw)
  end

  return data
end

def get_view_scope
  # get the user scope
  # get the items we have a view data permissions to union the items we have any permissions to
  (@user.get_scope('view_data') || []) | (@user.get_scope('*') || [])
end

def api_action_security!(method, action, index)
  if @user
    if @user.allowed?(action, nil)
      return true
    else
      halt 403, JSON.generate({'error' => 'not_authorized'})
    end
  else
    halt 401, JSON.generate({'error' => 'authentication_required'})
  end
end

# actions...

def get_action(index, type, id)
  # check if we are allowed to read the index
  if @user.allowed?('index_read', index)
    view_scope = get_view_scope

    c = Curl::Easy.http_get('http://' + GlobalConfig::Elasticsearch + '/' + index + '/' + type + '/' + id) do |curl|
      curl.headers['Accept'] = 'application/json'
      curl.headers['Content-Type'] = 'application/json'
    end

    result = JSON.parse(c.body_str)

    # check if result permitted
    if view_scope.include?('*') || view_scope.include?(id) || ((view_scope & ((result['_source']['tags'] || []).map { |item| '#' + item })).length > 0)
      return JSON.generate(result)
    end
  end

  halt 403, JSON.generate({'error' => 'not_authorized'})
end

def search_action(data, index, type)
  # check if we are allowed to read the index
  if @user.allowed?('index_read', index)

    # get the user scope
    # get the items we have a view data permissions to union the items we have any permissions to
    view_scope = (@user.get_scope('view_data') || []) | (@user.get_scope('*') || [])

    security_filter = nil

    # if we have access to everything then no need to filter
    unless view_scope.include?('*')
      normalized_scope = view_scope.map { |item| item.slice(1..item.length) if item.start_with?('#') }.reject { |r| r == nil }
      # build the filter
      security_filter = { 'or' => [{ 'terms' => { '@tags' => normalized_scope } }, { 'terms' => { 'tags' => normalized_scope } } ]}
    end

    filtered_query = nil

    if security_filter
      filtered_query = {'query' => {
          'filtered' => {
            'query' => (data['query'] || { 'match_all' => {} }),
            'filter' => security_filter
          }
        }
      }
    else
      filtered_query = {
          'query' => (data['query'] || { 'match_all' => {} })
      }
    end

    if data['facets']
      filtered_query['facets'] = data['facets']
    end

    if data['size']
      filtered_query['size'] = data['size']
    end

    if data['highlight']
      filtered_query['highlight'] = data['highlight']
    end

    if data['sort']
      filtered_query['sort'] = data['sort']
    end

    c = Curl::Easy.http_post('http://' + GlobalConfig::Elasticsearch + '/' + index + ((type == '_any') ? '' : ('/' + type)) + '/_search', JSON.generate(filtered_query)) do |curl|
      curl.headers['Accept'] = 'application/json'
      curl.headers['Content-Type'] = 'application/json'
    end

    return c.body_str
  end

  halt 403, JSON.generate({'error' => 'not_authorized'})
end

def save_action(data, index, type, id)
  # check if we are allowed to write the index
  if @user.allowed?('index_write', index)

    # get the user scope
    # get the items we have a view data permissions to union the items we have any permissions to
    view_scope = (@user.get_scope('modify_data') || []) | (@user.get_scope('*') || [])

    allowed = false

    if id
      existing_object_request = Curl::Easy.http_get('http://' + GlobalConfig::Elasticsearch + '/' + index + '/' + type + '/' + id) do |curl|
        curl.headers['Accept'] = 'application/json'
        curl.headers['Content-Type'] = 'application/json'
      end
      result = JSON.parse(existing_object_request.body_str)
      if view_scope.include?('*') || view_scope.include?(id) || ((view_scope & ((result['_source']['tags'] || []).map { |item| '#' + item })).length > 0)
        allowed = true
      end
    else
      allowed = true
    end

    if allowed
      c = Curl::Easy.http_post('http://' + GlobalConfig::Elasticsearch + '/' + index + '/' + type + '/' + id, JSON.generate(data)) do |curl|
        curl.headers['Accept'] = 'application/json'
        curl.headers['Content-Type'] = 'application/json'
      end

      return c.body_str
    end
  end

  halt 403, JSON.generate({'error' => 'not_authorized'})
end

def delete_action(data, index, type, id)
  # check if we are allowed to write the index
  if @user.allowed?('index_write', index)

    # get the user scope
    # get the items we have a view data permissions to union the items we have any permissions to
    view_scope = (@user.get_scope('delete_data') || []) | (@user.get_scope('*') || [])

    allowed = false

    if id
      existing_object_request = Curl::Easy.http_get('http://' + GlobalConfig::Elasticsearch + '/' + index + '/' + type + '/' + id) do |curl|
        curl.headers['Accept'] = 'application/json'
        curl.headers['Content-Type'] = 'application/json'
      end
      result = JSON.parse(existing_object_request.body_str)

      if view_scope.include?('*') || view_scope.include?(id) || ((view_scope & ((result['_source']['tags'] || []).map { |item| '#' + item })).length > 0)

        c = Curl::Easy.http_delete('http://' + GlobalConfig::Elasticsearch + '/' + index + '/' + type + '/' + id) do |curl|
          curl.headers['Accept'] = 'application/json'
          curl.headers['Content-Type'] = 'application/json'
        end

        return c.body_str
      end

    else
      halt 404, JSON.generate({'error' => 'not_found'})
    end
  end

  halt 403, JSON.generate({'error' => 'not_authorized'})
end
# endpoints

# search action
post '/api/idx/search/:index/?:type?' do
  index = params[:index]
  type = params[:type] || '_any'

  api_action_security! 'search', index, type

  search_action get_request_json, index, type
end

# get action
get '/api/idx/get/:index/:type/:id' do
  index = params[:index]
  type = params[:type] || '_any'
  id = params[:id]

  api_action_security! 'get', index, type

  get_action index, type, id
end

# save action
post '/api/idx/save/:index/:type/:id' do
  index = params[:index]
  type = params[:type]
  id = params[:id]

  api_action_security! 'save', index, type

  save_action get_request_json, index, type, id
end

# delete action
post '/api/idx/delete/:index/:type/:id' do
  index = params[:index]
  type = params[:type]
  id = params[:id]

  api_action_security! 'delete', index, type

  delete_action get_request_json, index, type, id
end

#
# end index API
#

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
  locals[:header_title] = "Message Parsing Editor"
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
  locals[:header_title] = "Message Parsing Editor"
  erb :main, :locals => locals
end

get '/grocker/analysis' do
  locals = {}
  locals[:pathtobase] = "../"
  locals[:internal_content] = true
  locals[:current_content] = "grocker"
  locals[:grocker_template] = :'grocker/analysis'
  locals[:header_title] = "Message Parsing Editor"
  erb :main, :locals => locals
end

get '/grocker/patterns' do
  @arr = get_files("../sixthsense/patterns/")
  locals = {}
  locals[:pathtobase] = "../"
  locals[:internal_content] = true
  locals[:current_content] = "grocker"
  locals[:grocker_template] = :'grocker/patterns'
  locals[:header_title] = "Message Parsing Editor"
  erb :main, :locals => locals

end

get '/grocker/patterns/*' do
  send_file(params[:spat]) unless params[:spat].nil?
end

get '/authapi/get/:method' do
  auth_api_get(params[:method])
end

post '/authapi/post/:method' do
  auth_api_post(params[:method])
end

def auth_api_get(method)
  auth = Authorization.new

  if method == "get_users"
    JSON.generate(auth.get_users)

  elsif method == "get_groups"
    JSON.generate(auth.get_groups)

  end

end

def auth_api_post(method)
  auth = Authorization.new

  data = get_request_json

  if method == "save_user"
    auth.set_groups data['user_name'], data['groups']

    if data['is_new_pass']
      auth.set_password data['user_name'], data['new_pass']
    end

  elsif method == "remove_user"
    auth.remove_user data['user_name']

  end

end

get '/admin' do
  auth = Authorization.new
  locals = {}
  locals[:username] = session[:username]
  locals[:is_admin] = true
  locals[:show_back] = true

  locals[:header_title] = "Administration"
  locals[:internal_content] = true
  locals[:current_content] = "admin"
  locals[:pathtobase] = ""

  erb :main, :locals => locals
end

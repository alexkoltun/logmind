require 'rubygems'
require 'json'
require 'tire'

class Authorization

  def initialize()
  end

  def setup_defaults_if_needed()

    perc_index = Tire.index 'logmind-perc'
    if not perc_index.exists?
      Tire.index 'logmind-perc' do
        create
      end
    end

    mgmt_index = Tire.index 'logmind-management'
    if not mgmt_index.exists?
      dash_json = '{"title":"CEP","rows":[{"title":"CEP","height":"350px","editable":true,"collapse":false,"collapsable":true,"panels":[{"loading":false,"error":false,"span":5,"editable":true,"group":["default"],"type":"cep_editor","status":"Stable","label":"Rule","multi":false,"multi_arrange":"horizontal","current_rule":{"name":"Omer","description":"Omer","time_window":10,"raw_queries":[{"query":"omer","id":"A"},{"query":"error","id":"B"}],"correlations":[{"correlation":""}],"notification":{"enable_notification":true,"destination_email":"o.hanetz@adacom.net"}},"elasticsearch_saveto":"logmind-management","obj_type":"cep_rule","test_index":"logstash-*","test_results":[],"test_result_size":100,"all_fields":[],"selected_fields":["@timestamp","@message"]},{"loading":false,"error":false,"span":3,"editable":true,"group":["default"],"type":"cep_rules","status":"Stable","query":"*","size":20,"pages":5,"offset":0,"sort":["name","desc"],"style":{"font-size":"9pt"},"overflow":"height","fields":["name","description","time_window","notification.enable_notification","notification.destination_email"],"displayNames":{"name":"Name","description":"Description","time_window":"Time Window","notification.enable_notification":"Notification Enabled","notification.destination_email":"Destination Email"},"highlight":[],"sortable":true,"header":true,"paging":true,"spyable":false,"elasticsearch_saveto":"logmind-management","obj_type":"cep_rule"}]}],"editable":true,"last":null}'

      Tire.index 'logmind-management' do
        store :id => 'CEP', :type => 'dashboard', :exists => true, :title => 'CEP', :dashboard => dash_json
        store :id => 'Demo', :type => 'cep_rule', :name => 'Demo', :description => 'Demo CEP Rule'
      end
    end

    index = Tire.index 'authorization'

    if index.exists?

      groups = JSON.generate(get_groups)
      users = JSON.generate(get_users)

      unless groups.include?('administrators')
        save_group 'administrators', []
        save_policy 'group_policy_administrators', ['@administrators'], ['*'], ['*']
      end

      unless groups.include?('users')
        save_group 'users', []
        save_policy 'group_policy_users', ['@users'], ['view_data', 'index_read', 'search', 'frontend_ui_view'], ['logstash-*', 'logmind-management', 'openmind-int']
      end

      unless users.include?('admin')
        save_user 'admin', ['@administrators'], []
        set_password 'admin', 'password'
      end

      unless users.include?('viewer')
        save_user 'viewer', ['@users'], []
        set_password 'viewer', 'password'
      end

      unless users.include?('guest')
        save_user 'guest', [], []
        set_password 'guest', 'password'
      end


    else

      mappings = ' {
          "template": "authorization",
          "mappings": {
              "user": {
                  "properties": {
                      "name": {
                          "index": "not_analyzed",
                          "type": "string"
                      },
                      "password": {
                          "index": "not_analyzed",
                          "type": "string"
                      },
                      "salt": {
                          "index": "not_analyzed",
                          "type": "string"
                      },
                      "groups": {
                          "index": "not_analyzed",
                          "type": "string"
                      },
                      "tags": {
                          "index": "not_analyzed",
                          "type": "string"
                      }
                  }
              },
              "group": {
                  "properties": {
                      "name": {
                          "index": "not_analyzed",
                          "type": "string"
                      },
                      "tags": {
                          "index": "not_analyzed",
                          "type": "string"
                      }
                  }
              },
              "action": {
                  "properties": {
                      "name": {
                          "index": "not_analyzed",
                          "type": "string"
                      },
                      "tags": {
                          "index": "not_analyzed",
                          "type": "string"
                      }
                  }
              },
              "policy": {
                  "properties": {
                      "title": {
                          "index": "not_analyzed",
                          "type": "string"
                      },
                      "who": {
                          "index": "not_analyzed",
                          "type": "string"
                      },
                      "what": {
                          "index": "not_analyzed",
                          "type": "string"
                      },
                      "on": {
                          "index": "not_analyzed",
                          "type": "string"
                      },
                      "tags": {
                          "index": "not_analyzed",
                          "type": "string"
                      }
                  }
              }
          }
      }'

      c = Curl::Easy.http_put('http://' + GlobalConfig::Elasticsearch + '/_template/authorization', mappings) do |curl|
        curl.headers['Accept'] = 'application/json'
        curl.headers['Content-Type'] = 'application/json'
      end

      result = JSON.parse(c.body_str)

      if result['ok']

        save_group 'administrators', []
        save_policy 'group_policy_administrators', ['@administrators'], ['*'], ['*']

        save_group 'users', []
        save_policy 'group_policy_users', ['@users'], ['view_data', 'index_read', 'search', 'frontend_ui_view'], ['logstash-*', 'logmind-management', 'openmind-int']

        save_user 'admin', ['@administrators'], []
        set_password 'admin', 'password'

        save_user 'viewer', ['@users'], []
        set_password 'viewer', 'password'

        save_user 'guest', [], []
        set_password 'guest', 'password'
      end
    end

  end

  def remove_user(username)
    # name is always lower case
    username.downcase!

    Tire.index('authorization') do
      remove :user, username
    end
    # TODO: remove the user from all of the related policies
  end

  def remove_group(name)
    # name is always lower case
    name.downcase!

    Tire.index('authorization') do
      remove :group, name
    end
    # TODO: remove the group from all of the related policies and from all users that have it
  end

  def remove_policy(name)
    # name is always lower case
    name.downcase!

    Tire.index('authorization') do
      remove :policy, name
    end
  end

  def save_user(username, groups = [], tags = [])
    # username is always lower case
    username.downcase!

    Tire.index 'authorization' do
      store :id => username, :type => 'user', :name => username, :groups => groups, :tags => tags
    end
  end

  def set_groups(username, groups)

    # username is always lower case
    username.downcase!

    Tire.index 'authorization' do
      update  'user',username,:doc => { :groups => groups }
    end
  end

  def save_group(name, tags)
    # name is always lower case
    name.downcase!

    Tire.index 'authorization' do
      store :id => name, :type => 'group', :name => name, :tags => tags
    end
  end

  def save_policy(name, who, what = [], on = [], tags = [])

    # name is always lower case
    name.downcase!

    Tire.index 'authorization' do
      store :id => name, :type => 'policy', :name => name, :who => who, :what => what, :on => on, :tags => tags
    end
  end

  def set_password(username, password)

    # username is always lower case
    username.downcase!

    salt = rand(65536)
    salt = salt.to_s(16)
    hashpass = Digest::SHA256.hexdigest(salt + password)

    Tire.index 'authorization' do
      update  'user',username,:doc => { :password => hashpass, :salt => salt }
    end
  end

  def load_user(username)

    # username is always lower case
    username.downcase!

    # fetch the user
    user_query = Tire.search('authorization/user') do
      query do
        term :name, username
      end
    end

    if user_query.results.empty?
      raise 'Invalid user'
    end

    group_names = []
    tag_names = []

    user = user_query.results.first

    # normalize and adjust user's groups list
    (user.groups || []).map do |group|
      group.downcase!
      group[0] == '@' || group.insert(0, '@')
    end

    # normalize and adjust user's tags list
    (user.tags || []).map do |tag|
      tag.downcase!
      tag[0] == '#' || tag.insert(0, '#')
    end

    # build a list of all relevant identifiers to look in the "who" field of the policy
    who_list = [username] + (user.tags || []) + (user.groups || [])

    # get all policies that apply to us
    policies_query = Tire.search('authorization/policy') do
      query do
        terms :who, who_list, :minimum_match => 1
      end
    end

    permissions = {}

    # process the policies
    policies_query.results.each do |policy|
      policy[:what].each do |action|
      permissions[action] = [] if !permissions[action]
      permissions[action] |= policy[:on]
      end
    end

    # get all action tags
    action_tags = permissions.keys.find_all { |item| item.start_with?("#") }
    action_tags.map! { |tag| tag.slice(1..tag.length) }

    # resolve action tags
    actions_query = Tire.search('authorization/action') do
      query do
        terms :tags, action_tags, :minimum_match => 1
      end
    end

    # process action tags
    actions_query.results.each do |action|
      action.tags.each do |tag|
        tags_on = permissions['#' + tag]
        if tags_on
          permissions[action.name] = [] if !permissions[action.name]
          permissions[action.name] |= tags_on
        end
      end
    end

    # clean tags from actions
    permissions.delete_if { |key,value| key.start_with?("#") }

    User.new(user.name, permissions)
  end

  def get_users
    users_query = Tire.search('authorization/user')

    users_query.results
  end

  def get_groups
    groups_query = Tire.search('authorization/group')

    groups_query.results
  end
end
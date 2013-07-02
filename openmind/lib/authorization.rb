require 'rubygems'
require 'json'
require 'tire'

class Authorization

  def initialize()
  end

  def setup_defaults_if_needed()
    save_user 'admin', [], []
    set_password 'admin', 'password'
    save_policy 'user_default_policy_admin', ['admin'], ['*'], ['*']

    save_user 'viewer', [], []
    set_password 'viewer', 'password'
    save_policy 'user_default_policy_viewer', ['viewer'], ['view_data', 'index_read', 'search', 'frontend_ui_view'], ['logstash-*', '#owner-benb@watchdox.com']

    save_user 'guest', [], []
    set_password 'guest', 'password'
    save_policy 'user_default_policy_guest', ['guest'], [], []
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
      store  :id => username, :type => 'user', :name => username, :password => hashpass, :salt => salt
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
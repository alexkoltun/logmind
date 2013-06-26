require 'rubygems'
require 'json'
require 'tire'

class Authorization

  def initialize(url)
    @url = url
    @policies =  [
        {
            :name => "Allow Alex, members of TopManagers group, and all users and groups with the tag 'ny_boss' to create new dashboards and remove users that are tagged 'newyork'",
            :who => ['Alex', '@TopManagers', '#ny_boss'],
            :what => ['view_data', 'new_dashboard', 'remove_user'],
            :on => ['Alex', '#newyork'],
            :when => ['10:00Z-12:00Z']
        }
    ]

  end

  def load_user(username)

    username.downcase!

    # 1. get all of the user's groups
    # 2. get all of the user's tags
    # 3. get all the policies that have the user or the group or the tag in their "who" definition
    # 4. create a hash structure as following: what => on/when, by aggregating the policies
    # 5. method: get_scope(what) => returns the 'on' array
    # 6. method: allowed?(what, on-name, on-tags) / allowed?(what, object) => returns a boolean indicating if the operation is allowed on the object

    Tire.configure do
      url @url
    end

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
    who_list = [username] + user.tags + user.groups

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
end
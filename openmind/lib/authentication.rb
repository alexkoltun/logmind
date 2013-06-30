require 'rubygems'
require 'json'
require 'tire'

class Authentication
  def initialize()
  end

  def login(username, password)
    # username is always lower case
    username.downcase!

    user_query = Tire.search('authorization/user') do
      query do
        term :name, username
      end
    end

    if user_query && !user_query.results.empty? && user_query.results.length == 1
      user = user_query.results.first

      salt = user['salt']
      hashpass = Digest::SHA256.hexdigest(salt + password)

      if(hashpass == user.password)
        return true
      end

      return false
    end
  end
end
class User
  attr_accessor :username, :permissions

  def initialize(username, permissions)
    username = username
    permissions = permissions
  end

  def get_scope(action)
    permissons[action]
  end

  def allowed?(action, scope)
    (permissions[action] ||= []).include? scope
  end
end
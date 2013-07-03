class User

  def initialize(username, permissions)
    @username = username
    @permissions = permissions
  end

  def get_scope(action)
    @permissions[action] if @permissions
  end

  def allowed?(action, scope)
    if @permissions
      if scope == nil
        return @permissions[action] || @permissions['*']
      else
        return (@permissions[action] || []).include?(scope) || (@permissions[action] || []).include?('*') || (@permissions['*'] || []).include?(scope) || (@permissions['*'] || []).include?('*')
      end
    end

    return false
  end
end
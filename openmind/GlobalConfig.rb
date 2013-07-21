module GlobalConfig


  Elasticsearch = "127.0.0.1:9200"

  ElasticsearchTimeout = 500

  OpenmindPort = 5601

  # The adress ip Kibana should listen on. Comment out or set to
  # 0.0.0.0 to listen on all interfaces.
  OpenmindHost = '127.0.0.1'

  # The record type as defined in your logstash configuration.
  # Seperate multiple types with a comma, no spaces. Leave blank
  # for all.
  Type = ''

  # Results to show per page
  Per_page = 50

  # Timezone. Leave this set to 'user' to have the user's browser autocorrect.
  # Otherwise, set a timezone string
  # Examples: 'UTC', 'America/Phoenix', 'Europe/Athens', MST
  # You can use `date +%Z` on linux to get your timezone string
  Timezone = 'user'

  # Format for timestamps. Defaults to mm/dd HH:MM:ss.
  # For syntax see: http://blog.stevenlevithan.com/archives/date-time-format
  # Time_format = 'isoDateTime' 
  Time_format = 'mm/dd HH:MM:ss'

  # Change which fields are shown by default. Must be set as an array
  # Default_fields = ['@fields.vhost','@fields.response','@fields.request']
  Default_fields = ['@message']

  # The default operator used if no explicit operator is specified.
  # For example, with a default operator of OR, the query capital of
  # Hungary is translated to capital OR of OR Hungary, and with default
  # operator of AND, the same query is translated to capital AND of AND
  # Hungary. The default value is OR.
  Default_operator = 'OR'

  # When using analyze, use this many of the most recent
  # results for user's query
  Analyze_limit = 2000

  # Show this many results in analyze/trend/terms/stats modes
  Analyze_show = 25

  # Show this many results in an rss feed
  Rss_show = 25

  # Show this many results in an exported file
  Export_show = 2000

  # Delimit exported file fields with what?
  # You may want to change this to something like "\t" (tab) if you have
  # commas in your logs
  Export_delimiter = ","

  # You may wish to insert a default search which all user searches
  # must match. For example @source_host:www1 might only show results
  # from www1.
  Filter = ''


  # Primary field. By default Elastic Search has a special
  # field called _all that is searched when no field is specified.
  # Dropping _all can reduce index size significantly. If you do that
  # you'll need to change primary_field to be '@message'
  Primary_field = '_all'

  # Default Elastic Search index to query
  Default_index = '_all'

  LastEvents_index = 'logstash-last'

  # Set headers to allow openmind to be loaded in an iframe from a different origin.
  Allow_iframed = false

  # Authentication options for the auth_ldap module
  Ldap_host = '127.0.0.1'
  Ldap_port = 389
  # Adds a '@domain.local' suffix to the username when authenticating against an LDAP directory
  # Ldap_domain_fqdn = 'domain.local'

  # Use this interval as fallback if the client's request in not valid.
  Fallback_interval = 900

  # CEP parameters
  Cep_rule_type = 'cep_rule'
  Cep_index = 'openmind-management'
  Cep_perc_index = 'openmind-perc'
  # name of the percolator field within the event
  Cep_q_fld_type_name = 'qtype'
end

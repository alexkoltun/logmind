Upgrading Logstash:
===============

When upgrading the version of Logstash, the following files should be kept, since they are our files:
 - logstash\lib\logstash\outputs\elasticlastevents.rb (our file)
 - logstash\lib\logstash\outputs\elasticsearch_http.rb (replace Logstash version, that doesn't work on Windows)
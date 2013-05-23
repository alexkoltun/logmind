#!/bin/bash

# run logstash
exec java -Xmx1024m -Xms256m -jar /usr/local/logmind/sixthsense/logstash.jar agent -f $1

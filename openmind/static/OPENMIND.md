=================
= Configuration =
=================

config.js
---------

1. Update elasticsearch URL to 'your-openmind-url/napi/es/'


=========
= Notes =
=========

Panels States
-------------

Explanation of Openmind panels states:
 - Stable: Panel is ready and has been fully tested
 - Experimental (beta): Panel is ready, but has not been fully tested yet
 - Development (broken): Panel is still in development, and not ready
 
 
Logstash Index Patterns
-----------------------
 
Time stamped indices use your selected time range to create a list of 
indices that match a specified timestamp pattern. This can be very efficient for some data sets (eg, logs).

For example, to match the default logstash index pattern you might use <code>[logstash-]YYYY.MM.DD</code>. 
The [] in "[logstash-]" are important as they instruct Openmind not to treat those letters as a pattern.

See <a href="http://momentjs.com/docs/#/displaying/format/">http://momentjs.com/docs/#/displaying/format/</a>
for documentation on date formatting.
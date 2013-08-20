/*

elasticsearch:  URL to your elasticsearch server
openmind_index:   The default ES index to use for storing openmind specific object
                such as stored dashboards
logstash_index: all indices for search
modules:        Panel modules to load. In the future these will be inferred 
                from your initial dashboard, though if you share dashboards you
                will probably need to list them all here 

If you need to configure the default dashboard, please see dashboards/default

*/
var config = new Settings(
{
  // By default this will attempt to reach ES at the same host you have
  // elasticsearch installed on. You probably want to set it to the FQDN of your
  // elasticsearch host
  elasticsearch:    window.location.protocol + "//" + window.location.hostname + ":" + window.location.port,
  openmind_index:     "logmind-management",
  logstash_index:     "logstash-*",
  modules:          ['histogram','map','pie','table','stringquery','sort',
                    'timepicker','text','fields','hits','dashcontrol',
                    'column','derivequeries','trends','bettermap',
		    'dashboards', 'dynamicmenu', 'dynamictopmenu','cep_rules','cep_editor', 'unitable']
  }
);

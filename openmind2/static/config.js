/*

elasticsearch:  URL to your elasticsearch server
openmind_index:   The default ES index to use for storing openmind specific object
                such as stored dashboards 
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
  //elasticsearch:    "http://"+window.location.hostname+"/napi/es/",
    elasticsearch:    "http://127.0.0.1:5601/napi/es/",
    //elasticsearch: 'http://192.168.1.14:9200',
  openmind_index:     "openmind-int", 
  modules:          ['histogram','map','pie','table','stringquery','sort',
                    'timepicker','text','fields','hits','dashcontrol',
                    'column','derivequeries', 'dashboards', 'dynamicmenu'],
  }
);

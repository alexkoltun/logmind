/*

  ## Table

  A paginated table of events matching a query

  ### Parameters
  * query ::  A string representing then current query
  * size :: Number of events per page to show
  * pages :: Number of pages to show. size * pages = number of cached events. 
             Bigger = more memory usage byh the browser
  * offset :: Position from which to start in the array of hits
  * sort :: An array with 2 elements. sort[0]: field, sort[1]: direction ('asc' or 'desc')
  * style :: hash of css properties
  * fields :: columns to show in table
  * overflow :: 'height' or 'min-height' controls wether the row will expand (min-height) to
                to fit the table, or if the table will scroll to fit the row (height) 
  * sortable :: Allow sorting?
  * spyable :: Show the 'eye' icon that reveals the last ES query for this panel
  ### Group Events
  #### Sends
  * table_documents :: An array containing all of the documents in the table. 
                       Only used by the fields panel so far. 
  #### Receives
  * time :: An object containing the time range to use and the index(es) to query
  * query :: An Array of queries, even if its only one
  * sort :: An array with 2 elements. sort[0]: field, sort[1]: direction ('asc' or 'desc')
  * selected_fields :: An array of fields to show
*/

angular.module('openmind.cep_rules', [])
.controller('cep_rules', function($scope, eventBus, fields,$http) {

  // Set and populate defaults
  var _d = {
    status  : "Stable",
    query   : "*",
    size    : 20, // Per page
    pages   : 5,   // Pages available
    offset  : 0,
    sort    : ['name','desc'],
    group   : "default",
    style   : {'font-size': '9pt'},
    overflow: 'height',
    fields  : ['name','description', 'time_window', 'notification.enable_notification', 'notification.destination_email'],
    displayNames: { 'name': 'Name', 'description': 'Description','time_window': 'Time Window', 'notification.enable_notification': 'Notification Enabled', 'notification.destination_email' : 'Destination Email' },
    highlight : [],
    sortable: true,
    header  : true,
    paging  : true, 
    spyable: false,
    elasticsearch_saveto: $scope.config.openmind_index,
    obj_type: 'cep_rule'
  }
  _.defaults($scope.panel,_d)

  $scope.init = function () {

      $scope.get_data();

      eventBus.register($scope,'rule_saved', function(event) {
          //alert('asd');
          $scope.get_data();
      });
  }

  $scope.set_sort = function(field) {
    if($scope.panel.sort[0] === field)
      $scope.panel.sort[1] = $scope.panel.sort[1] == 'asc' ? 'desc' : 'asc';
    else
      $scope.panel.sort[0] = field;
    $scope.get_data();
  }

  $scope.toggle_field = function(field) {
    if (_.indexOf($scope.panel.fields,field) > -1) 
      $scope.panel.fields = _.without($scope.panel.fields,field)
    else
      $scope.panel.fields.push(field)
        //broadcast_results();
  }

  $scope.get_display_value = function(source, field) {
    var parts = field.split('.');
    var current = source;
    for (var i=0; i < parts.length; i++) {
        if (current != null) {
            current = current[parts[i]];
        }
        else {
            return '';
        }
    }
    return current;
  }
  $scope.toggle_details = function(row) {
    row.openmind = row.openmind || {};
    row.openmind.details = row;// ? $scope.without_openmind(row) : false;
  }

  $scope.page = function(page) {
    $scope.panel.offset = page*$scope.panel.size
    $scope.get_data();
  }



    $scope.get_data = function(segment,query_id) {

        $scope.panel.error = false;
        $scope.panel.loading = true;

        // pass index name
        var request = $scope.ejs.Request().indices([$scope.panel.elasticsearch_saveto])
              .types([$scope.panel.obj_type])
              .size($scope.panel.size*$scope.panel.pages)
              .sort($scope.panel.sort[0],$scope.panel.sort[1]);

        //  $scope.populate_modal(request)

        var results = request.doSearch();

        // Populate scope when we have results
        results.then(function(results) {
          $scope.panel.loading = false;

          //if(_segment === 0) {
          //  $scope.hits = 0;
          //  $scope.data = [];
          //  query_id = $scope.query_id = new Date().getTime()
          //}

          // Check for error and abort if found
          if(!(_.isUndefined(results.error))) {
            $scope.panel.error = $scope.parse_error(results.error);
            return;
          }

          // Check that we're still on the same query, if not stop
          //if($scope.query_id === query_id) {
            $scope.data = _.map(results.hits.hits, function(hit) {
              return {
                _source   : hit['_source']
              }
            });

            $scope.hits = results.hits.total;

            // Sort the data
            $scope.data = _.sortBy($scope.data, function(v){
              return v._source[$scope.panel.sort[0]]
            });

            // Reverse if needed
            if($scope.panel.sort[1] == 'desc')
              $scope.data.reverse();

            // Keep only what we need for the set
            $scope.data = $scope.data.slice(0,$scope.panel.size * $scope.panel.pages)

          //} else {
          //  return;
          //}

          // This breaks, use $scope.data for this
          $scope.all_fields = get_all_fields(_.pluck($scope.data,'_source'));
          //broadcast_results();

        });
    }


  $scope.edit_rule = function(ruleRow){

      /*var temp = JSON.parse(ruleRow['_source']['raw_queries']);
      var arr = {};
      if (_.isArray(temp))
          arr = temp;
      else
          arr[0] = temp;
       */
      //if (temp is array)
      var rule =  _.clone(ruleRow);
      //{
      //  name: ruleRow['_source']['name'],
      //  description: ruleRow['_source']['description'],
      //  raw_queries:ruleRow['_source']['raw_queries']
      //};

      //alert(rule.raw_queries.length);
      eventBus.broadcast($scope.$id,$scope.panel.group,"edited_rule", rule);

  }
  $scope.new_rule = function() {
    eventBus.broadcast($scope.$id, $scope.panel.group,"new_rule");
  }
  $scope.populate_modal = function(request) {
    $scope.modal = {
      title: "Table Inspector",
      body : "<h5>Last Elasticsearch Query</h5><pre>"+
          'curl -XGET '+config.elasticsearch+'/'+$scope.index+"/_search?pretty -d'\n"+
          angular.toJson(JSON.parse(request.toString()),true)+
        "'</pre>"
    } 
  }

  $scope.delete_rule = function(rule) {
      var request = $http.post('/api/cep/delete/',rule._source);
      var id = request.then(function(result) {
          $scope.alert('Rule Deleted','This rule has been deleted!','success',5000);
          $scope.getData();
      })
      return false;
  }

  // Broadcast a list of all fields. Note that receivers of field array 
  // events should be able to receive from multiple sources, merge, dedupe 
  // and sort on the fly if needed.

  /*function broadcast_results() {
    eventBus.broadcast($scope.$id,$scope.panel.group,"fields", {
      all   : $scope.all_fields,
      sort  : $scope.panel.sort,
      active: $scope.panel.fields      
    });
    eventBus.broadcast($scope.$id,$scope.panel.group,"table_documents", 
      {
        query: $scope.panel.query,
        docs : _.pluck($scope.data,'_source'),
        index: $scope.index
      });
  }
  */
  $scope.set_refresh = function (state) { 
    $scope.refresh = state; 
  }

  $scope.close_edit = function() {
    if($scope.refresh)
      $scope.get_data();
    $scope.refresh =  false;
  }

  /*
  function set_time(time) {
    $scope.time = time;
    $scope.index = _.isUndefined(time.index) ? $scope.index : time.index
    $scope.get_data();
  }
  */

})
;
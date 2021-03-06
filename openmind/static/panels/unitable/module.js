/*

  ## Universal Table
*/

angular.module('openmind.unitable', [])
.controller('unitable', function($scope, eventBus, fields) {

  // Set and populate defaults
  var _d = {
    status  : "Stable",
    query   : "*",
    size    : 100, // Per page
    pages   : 5,   // Pages available
    offset  : 0,
    sort    : ['@timestamp','desc'],
    localTimeFields: ['@timestamp'],
    localTimeFormat: 'yyyy-mm-dd HH:MM:ss.L',
    group   : "default",
    style   : {'font-size': '9pt'},
    overflow: 'height',
    fields  : [],
    fieldSettings : { '@timestamp' : { displayName: 'Timestamp', cellTemplate: '', headerTemplate: '' } },
    dataSettings : { method: 'direct', index: 'lastevents', type: 'last-event' },
    highlight : [],
    sortable: true,
    header  : true,
    paging  : true, 
    spyable: true
  }
  _.defaults($scope.panel,_d)

  $scope.init = function () {

    $scope.set_listeners($scope.panel.group)

    // Now that we're all setup, request the time from our group
    if ($scope.panel.dataSettings && $scope.panel.dataSettings.method == 'dashboard') {
        eventBus.broadcast($scope.$id,$scope.panel.group,"get_time")
    }
      else {
        $scope.get_data();
    }
  }

  $scope.set_listeners = function(group) {
    eventBus.register($scope,'time',function(event,time) {
      $scope.panel.offset = 0;
      set_time(time)
    });
    eventBus.register($scope,'query',function(event,query) {
      $scope.panel.offset = 0;
      $scope.panel.query = _.isArray(query) ? query[0] : query;
      eventBus.broadcast($scope.$id,$scope.panel.group,'get_time');
    });
    eventBus.register($scope,'sort', function(event,sort){
      $scope.panel.sort = _.clone(sort);
      $scope.get_data();
    });
    eventBus.register($scope,'selected_fields', function(event, fields) {
      $scope.panel.fields = _.clone(fields)
    });
    eventBus.register($scope,'table_documents', function(event, docs) {
        $scope.panel.query = docs.query;
        $scope.data = docs.docs;
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
    broadcast_results();
  }

  $scope.toggle_highlight = function(field) {
    if (_.indexOf($scope.panel.highlight,field) > -1) 
      $scope.panel.highlight = _.without($scope.panel.highlight,field)
    else
      $scope.panel.highlight.push(field)
  }  

  $scope.toggle_details = function(row) {
    row.openmind = row.openmind || {};
    row.openmind.details = !row.openmind.details ? $scope.without_openmind(row) : false;
  }

  $scope.page = function(page) {
    $scope.panel.offset = page*$scope.panel.size
    $scope.get_data();
  }

  $scope.build_search = function(field,value,negate) {
    $scope.panel.query = add_to_query($scope.panel.query,field,value,negate)
    $scope.panel.offset = 0;
    $scope.get_data();
    eventBus.broadcast($scope.$id,$scope.panel.group,'query',[$scope.panel.query]);
  }

  $scope.export_data = function() {

      var request = $scope.ejs.Request().indices($scope.index[0])
          .query(ejs.FilteredQuery(
              ejs.QueryStringQuery($scope.panel.query || '*'),
              ejs.RangeFilter($scope.time.field)
                  .from($scope.time.from)
                  .to($scope.time.to)
          )
      );

      export_data = request.getExportRequestData($scope.panel.fields);

      var iframe_html = '<iframe id="logmind_export_iframe" height="0" width="0" border="0" style="width: 0; height: 0; border: none;"></iframe>';
      //  build html page
      if($('#logmind_export_iframe').length == 0) {
        $('body').append(iframe_html);
      }
      else {
        $('#logmind_export_iframe').replaceWith(iframe_html)
      }

      var frame = document.getElementById('logmind_export_iframe');
      var doc = frame.contentDocument;
      var page;
      page = "<html><body onload='document.forms[0].submit()'>";
      page += "<form method='post' action='" + export_data.url + "'><input type='hidden' name='data' value='" + encodeURIComponent(export_data.data) + "'></form>";
      page += "</body></html>";
      // now write out the new contents
      if (doc == undefined || doc == null)
          doc = frame.contentWindow.document;
      doc.open();
      doc.write(page);
      doc.close();
  }

  $scope.get_data = function() {

    var dataProviders = {
        dashboard: {
            get_data: function(scope) {
                // Make sure we have everything for the request to complete
                if(_.isUndefined($scope.index) || _.isUndefined($scope.time))
                    return null;

                var _segment = scope.segment = 0;

                var request = scope.ejs.Request().indices(scope.index[_segment])
                    .query(ejs.FilteredQuery(
                        ejs.QueryStringQuery(scope.panel.query || '*'),
                        ejs.RangeFilter(scope.time.field)
                            .from(scope.time.from)
                            .to(scope.time.to)
                    )
                    )
                    .highlight(
                        ejs.Highlight(scope.panel.highlight)
                            .fragmentSize(2147483647) // Max size of a 32bit unsigned int
                            .preTags('@start-highlight@')
                            .postTags('@end-highlight@')
                    )
                    .size(scope.panel.size*scope.panel.pages)
                    .sort(scope.panel.sort[0],scope.panel.sort[1]);

                scope.populate_modal(request)

                return request.doSearch()
            }
        },
        direct: {
            get_data: function(scope) {
                var request = scope.ejs.Request().indices(scope.panel.dataSettings.index)
                    .types(scope.panel.dataSettings.type)
                    .query(
                        ejs.QueryStringQuery(scope.panel.query || '*')
                    )
                    .highlight(
                        ejs.Highlight(scope.panel.highlight)
                            .fragmentSize(2147483647) // Max size of a 32bit unsigned int
                            .preTags('@start-highlight@')
                            .postTags('@end-highlight@')
                    )
                    .size(scope.panel.size*scope.panel.pages)
                    .sort(scope.panel.sort[0],scope.panel.sort[1]);

                scope.populate_modal(request)

                return request.doSearch()
            }
        }
    };

    $scope.panel.error =  false;
    $scope.panel.loading = true;


    var results = dataProviders[$scope.panel.dataSettings && $scope.panel.dataSettings.method || 'dashboard'].get_data($scope);

    // Populate scope when we have results
    results.then(function(results) {
      $scope.panel.loading = false;

      $scope.hits = 0;
      $scope.data = [];
      query_id = $scope.query_id = new Date().getTime()

      // Check for error and abort if found
      if(!(_.isUndefined(results.error))) {
        $scope.panel.error = $scope.parse_error(results.error);
        return;
      }

      // Check that we're still on the same query, if not stop
      if($scope.query_id === query_id) {
        $scope.data= $scope.data.concat(_.map(results.hits.hits, function(hit) {
          return {
            _source   : flatten_json(hit['_source']),
            highlight : flatten_json(hit['highlight']||{})
          }
        }));
        
        $scope.hits += results.hits.total;

        // Sort the data
        $scope.data = _.sortBy($scope.data, function(v){
          return v._source[$scope.panel.sort[0]]
        });
        
        // Reverse if needed
        if($scope.panel.sort[1] == 'desc')
          $scope.data.reverse();
        
        // Keep only what we need for the set
        $scope.data = $scope.data.slice(0,$scope.panel.size * $scope.panel.pages)

      } else {
        return;
      }
      
      // This breaks, use $scope.data for this
      $scope.all_fields = get_all_fields(_.pluck($scope.data,'_source'));
      broadcast_results();

      // If we're not sorting in reverse chrono order, query every index for
      // size*pages results
      // Otherwise, only get size*pages results then stop querying
//      if(
//          ($scope.data.length < $scope.panel.size*$scope.panel.pages ||
//            !(($scope.panel.sort[0] === $scope.time.field) && $scope.panel.sort[1] === 'desc')) &&
//          _segment+1 < $scope.index.length
//      ) {
//        $scope.get_data(_segment+1,$scope.query_id)
//      }

    });
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

  $scope.without_openmind = function (row) {
    return { 
      _source   : row._source,
      highlight : row.highlight
    }
  }

  $scope.convert_to_localtime = function(val) {
      return dateFormat(Date.parse(val), $scope.panel.localTimeFormat, false);
  }

  // Broadcast a list of all fields. Note that receivers of field array 
  // events should be able to receive from multiple sources, merge, dedupe 
  // and sort on the fly if needed.
  function broadcast_results() {
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

  $scope.set_refresh = function (state) { 
    $scope.refresh = state; 
  }

  $scope.close_edit = function() {
    if($scope.refresh)
      $scope.get_data();
    $scope.refresh =  false;
  }


  function set_time(time) {
    $scope.time = time;
    $scope.index = _.isUndefined(time.index) ? $scope.index : time.index
    $scope.get_data();
  }

})
.filter('highlight', function() {
  return function(text) {
    if (!_.isUndefined(text) && !_.isNull(text) && text.toString().length > 0) {
      return text.toString().
        replace(/&/g, '&amp;').
        replace(/</g, '&lt;').
        replace(/>/g, '&gt;').
        replace(/\r?\n/g, '<br/>').
        replace(/@start-highlight@/g, '<code class="highlight">').
        replace(/@end-highlight@/g, '</code>')
    }
    return '';
  }
});
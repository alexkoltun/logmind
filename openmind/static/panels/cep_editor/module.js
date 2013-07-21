/*

  ## cep_editor

  Allows add and edit of CEP rule

  ### Parameters
  * label ::  The label to stick over the field 
  * query ::  A string or an array of querys. String if multi is off, array if it is on
              This should be fixed, it should always be an array even if its only 
              one element
  * multi :: Allow input of multiple queries? true/false
  * multi_arrange :: How to arrange multu query string panels, 'vertical' or 'horizontal'
  ### Group Events
  #### Sends
  * query :: Always broadcast as an array, even in multi: false
  #### Receives
  * query :: An array of queries. This is probably needs to be fixed.

*/

angular.module('openmind.cep_editor', [])
.controller('cep_editor', function($scope, eventBus,$http) {

    // Set and populate defaults
    var _d = {
        status  : "Stable",
        label   : "Rule",
        group   : "default",
        multi   : false,
        multi_arrange: 'horizontal',
        current_rule: {},
        elasticsearch_saveto: $scope.config.openmind_index,
        obj_type: 'cep_rule',
        test_index: 'logstash-*',
        test_results: [],
        test_result_size: 100,
        all_fields:[],
        selected_fields: ['@timestamp', '@message']
    }
    _.defaults($scope.panel,_d);


    $scope.init = function() {
        // push first default empty query..
        $scope.reset();
        /*$scope.panel.current_rule.name = '';
        $scope.panel.current_rule.description = '';
        $scope.panel.current_rule.raw_queries = [{query:''}];
        $scope.panel.current_rule.correlations = [{correlation:''}];
        $scope.panel.current_rule.time_window = 10;
        $scope.panel.current_rule.notification = {};
        $scope.panel.current_rule.notification.enable_notification = false;
        $scope.panel.current_rule.notification.destination_email = 'test@example.com';
          */
        eventBus.register($scope,'edited_rule', function(event, rule) {

            //alert($scope.panel.current_rule.notification.enable_notification);
            $scope.panel.current_rule = {};
            $scope.panel.current_rule.name = rule["_source"]["name"];
            $scope.panel.current_rule.description = rule["_source"]["description"];
            $scope.panel.current_rule.time_window = rule["_source"]["time_window"];
            $scope.panel.current_rule.raw_queries = rule["_source"]["raw_queries"];
            $scope.panel.current_rule.correlations = rule["_source"]["correlations"];
            $scope.panel.current_rule.notification = {};
            $scope.panel.current_rule.notification.enable_notification = rule["_source"]["notification"]["enable_notification"];
            $scope.panel.current_rule.notification.destination_email = rule["_source"]["notification"]["destination_email"];
            //alert($scope.panel.current_rule.notification.destination_email);
        });
        eventBus.register($scope,'new_rule', function(event) {
            $scope.reset();
        });
    }

    $scope.test_query = function(q) {
        if (q.query != "") {
            //alert($scope.panel.test_index);
            var request = $scope.ejs.Request().indices([$scope.panel.test_index])
                .query(
                    ejs.QueryStringQuery(q.query)
                )
                .size($scope.panel.test_result_size);

            var results = request.doSearch();

            results.then(function(results) {
                $scope.panel.loading = false;

                //if(_segment === 0) {
                //    $scope.hits = 0;
                //    $scope.data = [];
                //    query_id = $scope.query_id = new Date().getTime()
                //}

                // Check for error and abort if found
                if(!(_.isUndefined(results.error))) {
                    $scope.panel.error = $scope.parse_error(results.error);
                    return;
                }


                $scope.panel.test_results = _.map(results.hits.hits, function(hit) {
                    return {
                        _source   : hit['_source']
                    }
                });

                $scope.panel.all_fields = get_all_fields(_.pluck($scope.panel.test_results,'_source'));
                //alert($scope.test_results.length);
            });
        } // if q != ''
    }

    $scope.save_rule = function() {

        var id = $scope.panel.current_rule.name;
        var type = $scope.panel.obj_type;
        var toSaveQs = [];
        for(var i=0;i<$scope.panel.current_rule.raw_queries.length;i++)
        {
          toSaveQs.push(
              {
                  query: $scope.panel.current_rule.raw_queries[i].query,
                  id: $scope.get_id($scope.panel.current_rule.raw_queries[i])
              });
        }

        var notfi = {};
        notfi.enable_notification = $scope.panel.current_rule.notification && $scope.panel.current_rule.notification.enable_notification;
        notfi.destination_email = ($scope.panel.current_rule.notification && $scope.panel.current_rule.notification.enable_notification)? $scope.panel.current_rule.notification.destination_email : '';

        // TODO, save all rule parts..
        //debugger;
        var saveData = {
            name: $scope.panel.current_rule.name,
            description: $scope.panel.current_rule.description,
            time_window: $scope.panel.current_rule.time_window,
            raw_queries: toSaveQs, //$scope.panel.current_rule.raw_queries
            correlations: _.clone($scope.panel.current_rule.correlations),
            notification: notfi
        };

        var request = $http.post('/api/cep/save/',saveData);

        //)
        //var request = $scope.ejs.Document($scope.panel.elasticsearch_saveto,type,id).source({
        //    name: $scope.panel.current_rule.name,
         //   description: $scope.panel.current_rule.description,
        //    raw_queries: toSaveQs, //$scope.panel.current_rule.raw_queries
         //   correlations: _.clone($scope.panel.current_rule.correlations)
        //})

        //var result = request.doSave();
        var id = request.then(function(result) {
            $scope.alert('Rule Saved','This rule has been saved!','success',5000)

            // notify list for save..
            eventBus.broadcast($scope.$id,$scope.panel.group,"rule_saved");
        })
    }

    $scope.add_query = function(){
        if ($scope.panel.current_rule.raw_queries == undefined)
            $scope.panel.current_rule.raw_queries = [];
        $scope.panel.current_rule.raw_queries.push({query: ''});
    }

    $scope.remove_query = function(q){
      if ($scope.panel.current_rule.raw_queries.length > 1){
        var index = $scope.panel.current_rule.raw_queries.indexOf(q);
        $scope.panel.current_rule.raw_queries.splice(index, 1);
      }
    }

    $scope.get_id = function(q){
      var index = $scope.panel.current_rule.raw_queries.indexOf(q);
      return String.fromCharCode(65 + index).toUpperCase();
    }


    $scope.reset = function(){
        $scope.panel.current_rule =  {};
        $scope.panel.current_rule.name = '';
        $scope.panel.current_rule.description = '';
        $scope.panel.current_rule.raw_queries = [{query:''}];
        $scope.panel.current_rule.correlations = [{correlation:''}];
        $scope.panel.current_rule.time_window = 10;
        $scope.panel.current_rule.enable_notification = false;
        $scope.panel.current_rule.destination_email = 'test@example.com';
    }

    $scope.add_correlation = function(){
        if ($scope.panel.current_rule.correlations == undefined)
            $scope.panel.current_rule.correlations = [];
        $scope.panel.current_rule.correlations.push({correlation: ''});
    }

    $scope.remove_correlation = function(c){
        if ($scope.panel.current_rule.correlations.length > 1){
            var index = $scope.panel.current_rule.correlations.indexOf(c);
            $scope.panel.current_rule.correlations.splice(index, 1);
        }
    }

    $scope.get_cor_id = function(q){
        return $scope.panel.current_rule.correlations.indexOf(q) + 1;
    }
});
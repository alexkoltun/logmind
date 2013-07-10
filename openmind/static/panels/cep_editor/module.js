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
.controller('cep_editor', function($scope, eventBus) {

  // Set and populate defaults
  var _d = {
    status  : "Stable",
    label   : "Rule",
    group   : "default",
    multi   : false,
    multi_arrange: 'horizontal',
    current_rule: {},
    elasticsearch_saveto: $scope.config.openmind_index,
    obj_type: 'cep_rule'
  }
  _.defaults($scope.panel,_d);

  $scope.init = function() {
        // push first default empty query..
        $scope.panel.current_rule.raw_queries = [{query:''}];


        eventBus.register($scope,'edited_rule', function(event, rule) {
            //alert(rule.raw_queries.length);
            $scope.panel.current_rule = rule;

      });
        // If we're in multi query mode, they all get wiped out if we receive a
        // query. Query events must be exchanged as arrays.
        //eventBus.register($scope,'query',function(event,query) {
            //$scope.panel.query = query;
            //update_history(query);
        //});
  }

  $scope.test_rule = function() {
   // TODO
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
      // TODO, save all rule parts..
      var request = $scope.ejs.Document($scope.panel.elasticsearch_saveto,type,id).source({
          name: $scope.panel.current_rule.name,
          description: $scope.panel.current_rule.description,
          raw_queries: toSaveQs//$scope.panel.current_rule.raw_queries
      })

      var result = request.doSave();
      var id = result.then(function(result) {
          $scope.alert('Rule Saved','This rule has been saved to Elasticsearch','success',5000)
          $scope.elasticsearch.title = '';
        })
  }

  $scope.add_query = function(){
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
});
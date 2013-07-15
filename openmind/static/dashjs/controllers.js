/*jshint globalstrict:true */
/*global angular:true */
'use strict';

angular.module('openmind.controllers', [])
.controller('DashCtrl', function($scope, $rootScope, $http, $timeout, ejsResource, eventBus, fields) {

  var _d = {
    title: "",
    editable: true,
    rows: [],
    last: null
  }

  $scope.init = function() {

    $scope.config = config;
    // Make underscore.js available to views
    $scope._ = _;

    // Provide a global list of all see fields
    $scope.fields = fields
    $scope.reset_row();
    $scope.clear_all_alerts();

    // Load dashboard by event 
    eventBus.register($scope,'dashboard', function(event,dashboard){
      $scope.dashboards = dashboard.dashboard;
      $scope.dashboards.last = dashboard.last;
      _.defaults($scope.dashboards,_d)
    })

    // If the route changes, clear the existing dashboard
    $rootScope.$on( "$routeChangeStart", function(event, next, current) {
      delete $scope.dashboards
    });

    var ejs = $scope.ejs = ejsResource(config.elasticsearch);  
  }

  $scope.add_row = function(dashboards,row) {
    $scope.dashboards.rows.push(row);
  }

  $scope.reset_row = function() {
    $scope.row = {
      title: '',
      height: '150px',
      editable: true,
    };
  };

  $scope.row_style = function(row) {
    return { 'min-height': row.collapse ? '5px' : row.height }
  }

  $scope.alert = function(title,text,severity,timeout) {
    var alert = {
      title: title,
      text: text,
      severity: severity || 'info',
    };
    $scope.global_alert.push(alert);
    if (timeout > 0)
      $timeout(function() {
        $scope.global_alert = _.without($scope.global_alert,alert)
      }, timeout);
  }

  $scope.clear_alert = function(alert) {
    $scope.global_alert = _.without($scope.global_alert,alert);
  }

  $scope.clear_all_alerts = function() {
    $scope.global_alert = []
  }  

  $scope.edit_path = function(type) {
    if(type)
      return 'panels/'+type+'/editor.html';
  }

  // This is whoafully incomplete, but will do for now 
  $scope.parse_error = function(data) {
    var _error = data.match("nested: (.*?);")
    return _.isNull(_error) ? data : _error[1];
  }

  $scope.init();

})
.controller('RowCtrl', function($scope, $rootScope, $timeout, ejsResource) {

  var _d = {
    title: "Row",
    height: "150px",
    collapse: false,
    collapsable: true,
    editable: true,
    panels: [],
  }
  _.defaults($scope.row,_d)


  $scope.init = function() {
    $scope.reset_panel();
  }

  $scope.toggle_row = function(row) {
    row.collapse = row.collapse ? false : true;
    if (!row.collapse) {
      $timeout(function() {
        $scope.$broadcast('render')
      });
    }
  }

  // This can be overridden by individual panel
  $scope.close_edit = function() {
    $scope.$broadcast('render')
  }

  $scope.add_panel = function(row,panel) {
    $scope.row.panels.push(panel);
  }

  $scope.reset_panel = function() {
    $scope.panel = {
      loading : false,
      error   : false,
      span    : 3,
      editable: true,
      group   : ['default'],
    };
  };

  $scope.init();

})

.controller('AdminCtrl', function($scope, $rootScope, $http, $timeout, ejsResource) {

    $scope.adminData = {
        usersList: [],
        groupsList: []
    }

    var _d = {
        title: "Admin",
        collapse: false,
        collapsable: false,
        editable: true,
        panels: []
    }
    _.defaults($scope.adminData,_d)


    $scope.init = function() {

        $http.get('/authapi/get/get_users').success(function(result) {
            $scope.adminData.usersList = result;
        });

        $http.get('/authapi/get/get_groups').success(function(result) {
            $scope.adminData.groupsList = result;
        });
    }


    $scope.save_user = function(mode, user, is_new_pass, new_pass) {

        var groups = $scope.get_user_groups();

        $http.post('/authapi/post/save_user', {mode: mode, user_name: user, is_new_pass: is_new_pass, new_pass: new_pass, groups: groups}).success(function(result) {
            alert("Save Successful!");
            if (mode == "add") {
                $scope.init();
            }
        });
    }

    $scope.get_user_groups = function() {
        var groups = [];
        $(".modal.in #curr_groups li").each(function() {
            groups.push("@" + $(this).text());
        })

        return groups;
    }

    $scope.remove_user = function(user) {
        var is_remove = confirm("Remove user '" + user + "'?");
        if (is_remove) {
            $http.post('/authapi/post/remove_user', {user_name: user}).success(function(result) {
                alert("User Removed!");
                $scope.init();
            });
        }
    }

    $scope.is_user_group = function(user, group_name) {
        return $.inArray("@" + group_name, user.groups);
    }


    $scope.get_name = function(str) {
        return str.replace('@', '');
    }


    $scope.init();

});


























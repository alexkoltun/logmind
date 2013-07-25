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

    $scope.is_dirty = false;

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
    $scope.dirty();
  }

  $scope.reset_row = function() {
    $scope.row = {
      title: '',
      height: '150px',
      editable: true
    };
  };

  $scope.row_style = function(row) {
    return { 'min-height': row.collapse ? '5px' : row.height }
  }

  $scope.alert = function(title,text,severity,timeout) {
    var alert = {
      title: title,
      text: text,
      severity: severity || 'info'
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
    return _.isNull(_error) ? $scope.pretty_error(data) : _error[1];
  }

  $scope.pretty_error = function(data) {

      // IndexMissingException
      if (data.indexOf("IndexMissingException") > -1) {
          var index_name = data.substring(data.indexOf("[[") + 2, data.indexOf("]"));
          return "No data at the moment (index: " + index_name + ")";
      }

      // No pretty error.
      return data;
  }


  $scope.dirty = function() {
      eventBus.broadcast($scope.$id,['default'],'dash_dirty');
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
    panels: []
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
      group   : ['default']
    };
  };

  $scope.init();

})

.controller('AdminCtrl', function($scope, $rootScope, $http, $modal, ejsResource) {

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

        $http.post('/authapi/post/save_user', {mode: mode, user_name: user, is_new_pass: is_new_pass, new_pass: new_pass, groups: $scope.user.groups}).success(function(result) {
            alert("Save Successful!");
            if (mode == "add") {
                $scope.init();
            }
        });
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


    $scope.show_add_user_modal = function() {
        var modal_scope = $scope;
        modal_scope.user = {groups: [], allgroups: $scope.get_all_group_names([])}

        var modal = $modal({
            template: 'partials/admin/adduser.html',
            show: true,
            persist: true,
            backdrop: 'static',
            scope: modal_scope
        });
    }


    $scope.show_edit_user_modal = function(user) {
        var modal_scope = $scope;
        modal_scope.user = user;
        modal_scope.user.allgroups = $scope.get_all_group_names(user.groups);

        var modal = $modal({
            template: 'partials/admin/edituser.html',
            show: true,
            persist: true,
            backdrop: 'static',
            scope: modal_scope
        });
    }


    $scope.get_all_group_names = function(current_groups) {
        var group_names = [];
        for (var i = 0; i < $scope.adminData.groupsList.length; i++) {
            var group = "@" + $scope.adminData.groupsList[i].name;
            if ($.inArray(group, current_groups) == -1) {
                group_names.push(group);
            }
        }

        return group_names;
    }


    $scope.move_right = function(user) {
//        $("#" + user + "_avail_groups li.ui-selected").each(function() {
//            var tag = $(this);
//            $("#" + user + "_curr_groups").append("<li class=\"select-item\" value=\"" + tag.text() + "\">" + tag.text() + "</li>");
//            tag.remove();
//        });
        for (var i = 0; i < user.avail_selected.length; i++) {
            user.groups.push(user.avail_selected[i]);
            $scope.remove_from_user_allgroups(user, user.avail_selected[i]);
        }

        user.avail_selected = [];
    }

    $scope.remove_from_user_allgroups = function(user, group_name) {
        var index = -1;
        for (var i = 0; i < user.allgroups.length; i++) {
            if ($scope.get_name(user.allgroups[i]) === $scope.get_name(group_name)) {
                index = i;
                break;
            }
        }

        if (index > -1) {
            user.allgroups.splice(index, 1);
        }
    }

    $scope.move_left = function(user) {
        for (var i = 0; i < user.current_selected.length; i++) {
            user.allgroups.push(user.current_selected[i]);
            $scope.remove_from_user_groups(user, user.current_selected[i]);
        }

        user.current_selected = [];
    }

    $scope.remove_from_user_groups = function(user, group_name) {
        var index = -1;
        for (var i = 0; i < user.groups.length; i++) {
            if ($scope.get_name(user.groups[i]) === $scope.get_name(group_name)) {
                index = i;
                break;
            }
        }

        if (index > -1) {
            user.groups.splice(index, 1);
        }
    }


    $scope.make_selectable = function() {
        $( ".select-list" ).selectable();
    }


    $scope.user_avail_selected = function(user, group_name) {
        if (user.avail_selected === undefined) {
            user.avail_selected = [];
        }

        var index = user.avail_selected.indexOf(group_name);
        if (index > -1) {
            user.avail_selected.splice(index, 1);
        } else {
            user.avail_selected.push(group_name);
        }
    }


    $scope.user_current_selected = function(user, group_name) {
        if (user.current_selected === undefined) {
            user.current_selected = [];
        }

        var index = user.current_selected.indexOf(group_name);
        if (index > -1) {
            user.current_selected.splice(index, 1);
        } else {
            user.current_selected.push(group_name);
        }
    }


    $scope.init();

});


























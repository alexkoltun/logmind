/*

  ## Dashcontrol

  Dash control allows for saving, loading and sharing of dashboards. Do not
  disable the dashcontrol module as a special instance of it allows for loading
  the default dashboard from dashboards/default

  ### Parameters
  * save
  ** gist :: Allow saving to gist. Requires registering an oauth domain with Github
  ** elasticsearch :: Allow saving to a special openmind index within Elasticsearch
  ** local :: Allow saving to local file
  * load
  ** gist :: Allow loading from gists
  ** elasticsearch :: Allow searching and loading of elasticsearch saved dashboards
  ** local :: Allow loading of dashboards from Elasticsearch
  * hide_control :: Upon save, hide this panel
  * elasticsearch_size :: show this many dashboards under the ES section in the load drop down
  * elasticsearch_saveto :: Special openmind index to save to
  * temp :: Allow saving of temp dashboards
  * temp_ttl :: How long should temp dashboards persist

  ### Group Events
  #### Sends
  * dashboard :: An object containing an entire dashboard to be loaded

*/

angular.module('openmind.dynamicmenu', [])
.controller('dynamicmenu', function($scope, $routeParams, $http, eventBus, timer) {
  $scope.panel = $scope.panel || {};
  // Set and populate defaults
  var _d = {
    group   : "default",
    save : {
      gist: false,
      elasticsearch: true,
      local: true,
      'default': true
    },
    load : {
      gist: true,
      elasticsearch: true,
      local: true
    },
    hide_control: false,
    elasticsearch_size: 20,
    elasticsearch_saveto: $scope.config.openmind_index,
    temp: true,
    temp_ttl: '30d'
  }
  _.defaults($scope.panel,_d);

  // A hash of defaults for the dashboard object
  var _dash = {
    title: "",
    editable: true,
    rows: []
  }

    var _default_menu = [
        {
            title: "Home",
            type: "static",
            link: "/",
            icon: "icon-home"
        },
        {
            title: "<span style='font-weight: bold;'>{{ userinfo.username }}</span>",
            type: "container",
            icon: "icon-user icon-large",
            items: [
                {
                    title: "User Administration",
                    type: "static",
                    link: "/admin",
                    icon: "icon-user",
                    tags: ["admin"]
                },
                {
                    title: "Last Events",
                    type: "static",
                    link: "/lastevents",
                    icon: "icon-time",
                    tags: ["admin"]
                },
                {
                    title: "Live Indices",
                    type: "static",
                    link: "/indiceslist",
                    icon: "icon-eye-open",
                    tags: ["admin"]
                },
                {
                    title: "Archived Indices",
                    type: "static",
                    link: "/archivedlist",
                    icon: "icon-eye-close",
                    tags: ["admin"]
                },
                {
                    title: "(Logout)",
                    type: "static",
                    link: "/auth/logout",
                    icon: "icon-off",
                    tags: ["admin"]
                }
            ]
        },
        {
            title: "Dashboards",
            type: "container",
            icon: "icon-th-large",
            items: [
                {
                    title: "Default",
                    type: "static",
                    link: "/",
                    icon: "icon-home"
                },
                {
                    type: "dynamic",
                    icon: "icon-star",
                    link_base: "/#/dashboard/elasticsearch/",
                    title_column: "_id",
                    link_column: "_id",
                    es_index: "openmind-int",
                    es_type: "dashboard",
                    es_query: "*"
                }
            ]
        },
        {
            title: "Message Parsing Editor",
            type: "static",
            link: "/grocker",
            icon: "icon-certificate"
        }
    ]


  $scope._menu = null;

  $scope.userinfo = {
      username: "this is user"
  };


  $scope.load_dynamic_data = function(item) {

      if (item.type === "container") {
          // Items
          $.each(item.items, function() {
              $scope.load_dynamic_data(this);
          });

      } else if (item.type === "dynamic") {
          var res = $scope.ejs.Request().indices(item.es_index).types(item.es_type).query(
              $scope.ejs.QueryStringQuery(item.es_query)).doSearch();

          res.then(function(res) {
              if(_.isUndefined(res.hits)) {
                  return;
              }
              item.items = res.hits.hits;
          });
      }
  }

  $scope.init = function() {

    $scope.ejs.Document("logmind-management", "openmind-menu", "default").doGet(function(a) {
        if (!a.exists) {
            a = $scope.ejs.Document("logmind-management", "openmind-menu", "default").source({
                name: "default",
                tags: ["tag1, tag2"],
                menu_json: angular.toJson(_default_menu)
            }).doIndex();
        }

        $scope._menu = angular.fromJson(a._source.menu_json);

        // Loading dynamic data.
        $.each($scope._menu, function() {
            $scope.load_dynamic_data(this);
        });
    });
    //var menu_obj = $scope.ejs.Request().query($scope.ejs.QueryStringQuery("/logmind-management/openmind-menu/default")).doSearch();

    $scope.elasticsearch_dblist("")
    // Long ugly if statement for figuring out which dashboard to load on init
    // If there is no dashboard defined, find one
    if(_.isUndefined($scope.dashboards)) {
      // First check the URL for a path to a dashboard
      if(!(_.isUndefined($routeParams.type)) && !(_.isUndefined($routeParams.id))) {
        var _type = $routeParams.type;
        var _id = $routeParams.id;
        
        if(_type === 'elasticsearch')
          $scope.elasticsearch_load('dashboard',_id)
        if(_type === 'temp')
          $scope.elasticsearch_load('temp',_id)
        if(_type === 'file')
          $scope.file_load(_id)

      // No dashboard in the URL
      } else {
        // Check if browser supports localstorage, and if there's a dashboard 
        if (Modernizr.localstorage && 
          !(_.isUndefined(localStorage['dashboard'])) &&
          localStorage['dashboard'] !== ''
        ) {
          var dashboard = JSON.parse(localStorage['dashboard']);
          _.defaults(dashboard,_dash);
          $scope.dash_load(JSON.stringify(dashboard))
        // No? Ok, grab default.json, its all we have now
        } else {
          $scope.file_load('default')
        }
        
      }
    }

    $scope.gist_pattern = /(^\d{5,}$)|(^[a-z0-9]{10,}$)|(gist.github.com(\/*.*)\/[a-z0-9]{5,}\/*$)/;
    $scope.gist = {};
    $scope.elasticsearch = {};
  }

  $scope.to_file = function() {
    var blob = new Blob([angular.toJson($scope.dashboards,true)], {type: "application/json;charset=utf-8"});
    saveAs(blob, $scope.dashboards.title+"-"+new Date().getTime());
  }

  $scope.default = function() {
    if (Modernizr.localstorage) {
      localStorage['dashboard'] = angular.toJson($scope.dashboards);
      $scope.alert('Success',
        $scope.dashboards.title + " has been set as your default dashboard",
        'success',5000)
    } else {
      $scope.alert('Bummer!',
        "Your browser is too old for this functionality",
        'error',5000);
    }  
  }

  $scope.share_link = function(title,type,id) {
    $scope.share = {
      location  : location.href.replace(location.hash,""),
      type      : type,
      id        : id,
      link      : location.href.replace(location.hash,"")+"#dashboard/"+type+"/"+id,
      title     : title
    };
  }

  $scope.purge = function() {
    if (Modernizr.localstorage) {
      localStorage['dashboard'] = '';
      $scope.alert('Success',
        'Default dashboard cleared',
        'success',5000)
    } else {
      $scope.alert('Doh!',
        "Your browser is too old for this functionality",
        'error',5000);
    }  
  }

  $scope.file_load = function(file) {
    $http({
      url: "dashboards/"+file,
      method: "GET",
    }).success(function(data, status, headers, config) {
      var dashboard = data
       _.defaults(dashboard,_dash);
       $scope.dash_load(JSON.stringify(dashboard))
    }).error(function(data, status, headers, config) {
      $scope.alert('Default dashboard missing!','Could not locate dashboards/'+file,'error')
    });
  }

  $scope.elasticsearch_save = function(type) {
    // Clone object so we can modify it without influencing the existing obejct
    if($scope.panel.hide_control) {
      $scope.panel.hide = true;
      var save = _.clone($scope.dashboards)
    } else {
      var save = _.clone($scope.dashboards)
    }

    // Change title on object clone
    if(type === 'dashboard')
      var id = save.title = $scope.elasticsearch.title;

    // Create request with id as title. Rethink this.
    var request = $scope.ejs.Document($scope.panel.elasticsearch_saveto,type,id).source({
      user: 'guest',
      group: 'guest',
      title: save.title,
      dashboard: angular.toJson(save)
    })
    
    if(type === 'temp')
      request = request.ttl($scope.panel.temp_ttl)

    var result = request.doIndex();
    var id = result.then(function(result) {
      $scope.alert('Dashboard Saved','This dashboard has been saved to Elasticsearch','success',5000)
      $scope.elasticsearch_dblist($scope.elasticsearch.query);
      $scope.elasticsearch.title = '';
      if(type === 'temp')
        $scope.share_link($scope.dashboards.title,'temp',result._id)
    })

    $scope.panel.hide = false;
  }

  $scope.elasticsearch_delete = function(dashboard) {
    var result = $scope.ejs.Document($scope.panel.elasticsearch_saveto,'dashboard',dashboard._id).doDelete();
    result.then(function(result) {
      $scope.alert('Dashboard Deleted','','success',5000)
      $scope.elasticsearch.dashboards = _.without($scope.elasticsearch.dashboards,dashboard)
    })
  }

  $scope.elasticsearch_load = function(type,id) {
    var request = $scope.ejs.Request().indices($scope.panel.elasticsearch_saveto).types(type);
    var results = request.query(
        $scope.ejs.IdsQuery(id)
        ).size($scope.panel.elasticsearch_size).doSearch();
    results.then(function(results) {
      if(_.isUndefined(results)) {
        return;
      }
      $scope.panel.error =  false;
      $scope.dash_load(results.hits.hits[0]['_source']['dashboard'])
    });
  }

  $scope.elasticsearch_dblist = function(query) {
    if($scope.panel.load.elasticsearch) {
      var request = $scope.ejs.Request().indices($scope.panel.elasticsearch_saveto).types('dashboard');
      var results = request.query(
        $scope.ejs.QueryStringQuery(query || '*')
        ).size($scope.panel.elasticsearch_size).doSearch();
      
      results.then(function(results) {
        if(_.isUndefined(results.hits)) {
          return;
        }
        $scope.panel.error =  false;
        $scope.hits = results.hits.total;
        $scope.elasticsearch.dashboards = results.hits.hits
      });
    }
  }

  $scope.save_gist = function() {
    var save = _.clone($scope.dashboards)
    save.title = $scope.gist.title;
    $http({
    url: "https://api.github.com/gists",
    method: "POST",
    data: {
      "description": save.title,
      "public": false,
      "files": {
        "openmind-dashboard.json": {
          "content": angular.toJson(save,true)
        }
      }
    }
    }).success(function(data, status, headers, config) {
      $scope.gist.last = data.html_url;
      $scope.alert('Gist saved','You will be able to access your exported dashboard file at <a href="'+data.html_url+'">'+data.html_url+'</a> in a moment','success')
    }).error(function(data, status, headers, config) {
      $scope.alert('Unable to save','Save to gist failed for some reason','error',5000)
    });
  }

  $scope.gist_dblist = function(id) {
    $http.jsonp("https://api.github.com/gists/"+id+"?callback=JSON_CALLBACK"
    ).success(function(response) {
      $scope.gist.files = []
      _.each(response.data.files,function(v,k) {
        try {
          var file = JSON.parse(v.content)
          $scope.gist.files.push(file)
        } catch(e) {
          $scope.alert('Gist failure','The dashboard file is invalid','warning',5000)
        }
      });
    }).error(function(data, status, headers, config) {
      $scope.alert('Gist Failed','Could not retrieve dashboard list from gist','error',5000)
    });
  }

  $scope.dash_load = function(dashboard) {
    if(!_.isObject(dashboard))
      dashboard = JSON.parse(dashboard)
    eventBus.broadcast($scope.$id,'ALL','dashboard',{
      dashboard : dashboard,
      last      : $scope.dashboards
    })
    timer.cancel_all();
  }

  $scope.gist_id = function(string) {
    if($scope.is_gist(string))
      return string.match($scope.gist_pattern)[0].replace(/.*\//, '');
  }

  $scope.is_gist = function(string) {
    if(!_.isUndefined(string) && string != '' && !_.isNull(string.match($scope.gist_pattern)))
      return string.match($scope.gist_pattern).length > 0 ? true : false;
    else
      return false
  }
})
.directive("dynmenu", function($compile) {
    return {
        restrict: 'EA',
        link: function (scope, element, attrs) {
            scope.$watch('_menu', function(menu) {
                if (menu) {
                    scope.render_menu();
                }
            }, true);

            scope.generate_menu = function() {

                if (scope._menu == null) {
                    return "";
                }

                var ret = "";
                $.each(scope._menu, function() {
                    if (this.type != undefined) {
                        ret += scope.generate_sub(this);
                    }
                });

                return ret;
            }

            scope.generate_sub = function(item) {
                var ret = "";
                if (item.type === "container") {
                    ret = "<li class=\"submenu\">"
                    ret += "<a class='menulink' href=\"#\"><i class=\"icon " + item.icon + "\"></i> <span>" + item.title + "</span><i class=\"icon-chevron-down\" style=\"float: right; margin-right: 20px;\"></i></a>";
                    ret += "<ul>";

                    // Items
                    $.each(item.items, function() {
                        ret += scope.generate_sub(this);
                    });

                    ret += "</ul></li>"

                } else if (item.type === "static") {
                    ret += "<li><a class='menulink' href=\"" + item.link + "\"><i class=\"icon " + item.icon + "\"></i> <span>" + item.title + "</span></a></li>";

                } else if (item.type === "dynamic") {
                    if (item.items != undefined) {
                        $.each(item.items, function() {
                            ret += "<li><a class='menulink' href=\"" + item.link_base + this[item.link_column] + "\"><i class=\"icon " + item.icon + "\"></i> <span>" + this[item.title_column] + "</span></a></li>";
                        });
                    }
                }

                return ret;
            }

            scope.render_menu = function() {
                var template = scope.generate_menu();
                var newElement = angular.element(template);
                $compile(newElement)(scope);
                element.html("").append(newElement);
            }

            scope.render_menu();
        }
    }
})
    .directive('dashUpload', function(timer, eventBus){
  return {
    restrict: 'A',
    link: function(scope, elem, attrs) {
      function file_selected(evt) {
        var files = evt.target.files; // FileList object

        // files is a FileList of File objects. List some properties.
        var output = [];
        for (var i = 0, f; f = files[i]; i++) {
          var reader = new FileReader();
          reader.onload = (function(theFile) {
            return function(e) {
              scope.dash_load(JSON.parse(e.target.result))
              scope.$apply();
            };
          })(f);
          reader.readAsText(f);
        }
      }

      // Check for the various File API support.
      if (window.File && window.FileReader && window.FileList && window.Blob) {
        // Something
        document.getElementById('dashupload').addEventListener('change', file_selected, false);
      } else {
        alert('Sorry, the HTML5 File APIs are not fully supported in this browser.');
      }
    }
  }
})
    .filter('gistid', function() {
    var gist_pattern = /(\d{5,})|([a-z0-9]{10,})|(gist.github.com(\/*.*)\/[a-z0-9]{5,}\/*$)/;
    return function(input, scope) {
        //return input+"boners"
        if(!(_.isUndefined(input))) {
          var output = input.match(gist_pattern);
          if(!_.isNull(output) && !_.isUndefined(output))
            return output[0].replace(/.*\//, '');
        }
    }
});;
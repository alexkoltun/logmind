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
      username: currentUser.username
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
            });

            a.doSave();
        }

        if (a._source != undefined) {
            $scope._menu = angular.fromJson(a._source.menu_json);

        } else {
            $scope._menu = angular.fromJson(a.source().menu_json);
        }

        // Loading dynamic data.
        $.each($scope._menu, function() {
            $scope.load_dynamic_data(this);
        });
    });
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
});;
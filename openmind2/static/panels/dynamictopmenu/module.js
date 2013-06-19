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

angular.module('openmind.dynamictopmenu', [])
.controller('dynamictopmenu', function($scope, $routeParams, $http, eventBus, timer) {

    var _default_menu = [
        {
            id: "top-user",
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
                }
            ]
        },
        {
            id: "top-messages",
            title: "Messages <span class='label label-important'>5</span>",
            type: "container",
            icon: "icon-envelope",
            items: [
                {
                    title: "New Message",
                    type: "static",
                    link: "/",
                    icon: "icon-envelope",
                    tags: ["admin"]
                },
                {
                    title: "Inbox",
                    type: "static",
                    link: "/",
                    icon: "icon-envelope",
                    tags: ["admin"]
                },
                {
                    title: "Outbox",
                    type: "static",
                    link: "/",
                    icon: "icon-envelope",
                    tags: ["admin"]
                },
                {
                    title: "Trash",
                    type: "static",
                    link: "/",
                    icon: "icon-envelope",
                    tags: ["admin"]
                }
            ]
        },
        {
            id: "top-settings",
            title: "Settings",
            type: "static",
            link: "/",
            icon: "icon-cog",
            tags: ["admin"]
        },
        {
            id: "top-logout",
            title: "Logout",
            type: "static",
            link: "/auth/logout",
            icon: "icon-off",
            tags: ["admin"]
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

    $scope.ejs.Document("logmind-management", "openmind-menu", "default-top").doGet(function(a) {
        if (!a.exists) {
            a = $scope.ejs.Document("logmind-management", "openmind-menu", "default-top").source({
                name: "default-top",
                tags: ["tag1, tag2"],
                menu_json: angular.toJson(_default_menu)
            });

            a.doIndex();
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
.directive("dyntopmenu", function($compile) {
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
                        ret += scope.generate_sub(this, false);
                    }
                });

                return ret;
            }

            scope.generate_sub = function(item, is_sub) {
                var ret = "";
                if (item.type === "container") {
                    ret = "<li class=\"btn btn-inverse dropdown\" id=\"" + item.id + "\">"
                    ret += "<a data-toggle='dropdown' data-target='" + item.id + "' class='dropdown-toggle' href=\"#\"><i class=\"icon " + item.icon + "\"></i> <span class='text'>" + item.title + "</span>&nbsp;&nbsp;<b class='caret'></b></a>";
                    ret += "<ul class='dropdown-menu'>";

                    // Items
                    $.each(item.items, function() {
                        ret += scope.generate_sub(this, true);
                    });

                    ret += "</ul></li>"

                } else if (item.type === "static") {

                    if (is_sub) {
                        ret += "<li>";
                    } else {
                        ret += "<li class='btn btn-inverse'>";
                    }

                    ret += "<a href=\"" + item.link + "\"><i class=\"icon " + item.icon + "\"></i> <span class='text'>" + item.title + "</span></a></li>";

                /*} else if (item.type === "dynamic") {
                    if (item.items != undefined) {
                        $.each(item.items, function() {
                            ret += "<li><a class='menulink' href=\"" + item.link_base + this[item.link_column] + "\"><i class=\"icon " + item.icon + "\"></i> <span>" + this[item.title_column] + "</span></a></li>";
                        });
                    }*/
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
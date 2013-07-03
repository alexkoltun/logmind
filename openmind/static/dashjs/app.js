/*jshint globalstrict:true */
/*global angular:true */
'use strict';

// Base modules
var modules = [
  'openmind.services',
  'openmind.controllers', 
  'openmind.filters', 
  'openmind.directives', 
  'elasticjs.service',
  '$strap.directives',
  'openmind.panels',
  'ngSanitize',
  ]

var scripts = []

var labjs = $LAB
  .script("dashjs/services.js")
  .script("dashjs/controllers.js")
  .script("dashjs/filters.js")
  .script("dashjs/directives.js")
  .script("dashjs/panels.js").wait()

_.each(config.modules, function(v) {
  labjs = labjs.script('panels/'+v+'/module.js')
  modules.push('openmind.'+v)
})

/* Application level module which depends on filters, controllers, and services */
labjs.wait(function(){
  angular.module('openmind', modules).config(['$routeProvider', function($routeProvider) {
      $routeProvider
        .when('/dashboard', {
          templateUrl: 'partials/dashboard.html' 
        })
        .when('/dashboard/:type/:id', {
          templateUrl: 'partials/dashboard.html'
        })
        .when('/dashboard/:type/:id/:params', {
          templateUrl: 'partials/dashboard.html'
        })
        .otherwise({
          redirectTo: 'dashboard'
        });
    }]);
  angular.element(document).ready(function() {
    $('body').attr('ng-controller', 'DashCtrl')
    angular.bootstrap(document, ['openmind']);
  });
});

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
  //.script("common/lib/jquery-1.8.0.min.js").wait()
  .script("common/lib/modernizr-2.6.1.min.js")
  .script("common/lib/underscore.min.js")  
  //.script("common/lib/bootstrap.min.js")
  .script('common/lib/datepicker.js')
  .script('common/lib/timepicker.js')
  .script("common/lib/angular.min.js")
  .script("common/lib/angular-strap.min.js")
  .script("common/lib/angular-sanitize.min.js")
  .script("common/lib/elastic.min.js")
  .script("common/lib/elastic-angular-client.js")
  .script("common/lib/dateformat.js")
  .script("common/lib/date.js")
  .script("common/lib/datepicker.js")
  .script("common/lib/shared.js")
  .script("common/lib/filesaver.js")
  .script("dashjs/services.js")
  .script("dashjs/controllers.js")
  .script("dashjs/filters.js")
  .script("dashjs/directives.js")
  .script("dashjs/panels.js")

_.each(config.modules, function(v) {
  labjs = labjs.script('panels/'+v+'/module.js').wait()
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

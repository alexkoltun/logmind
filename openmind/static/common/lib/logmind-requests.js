(function (ejs) {

    if(typeof(ejs) == 'undefined' || ejs == null) {
        throw new Error("ejs should be initialized prior to loading logmind-requests.js");
    }

    var oldRequest = ejs.Request, oldDocument = ejs.Document;

    'use strict';

    var
    // from underscore.js, used in utils
        ArrayProto = Array.prototype,
        ObjProto = Object.prototype,
        slice = ArrayProto.slice,
        toString = ObjProto.toString,
        hasOwnProp = ObjProto.hasOwnProperty,
        nativeForEach = ArrayProto.forEach,
        nativeIsArray = Array.isArray,
        breaker = {},
        has,
        each,
        extend,
        isArray,
        isObject,
        isString,
        isNumber,
        isFunction,
        isEJSObject, // checks if valid ejs object
        isQuery, // checks valid ejs Query object
        isFilter, // checks valid ejs Filter object
        isFacet, // checks valid ejs Facet object
        isScriptField, // checks valid ejs ScriptField object
        isGeoPoint, // checks valid ejs GeoPoint object
        isIndexedShape, // checks valid ejs IndexedShape object
        isShape, // checks valid ejs Shape object
        isSort, // checks valid ejs Sort object
        isHighlight, // checks valid ejs Highlight object
        isSuggest, // checks valid ejs Suggest object
        isGenerator;

    /* Utility methods, most of which are pulled from underscore.js. */

    // Shortcut function for checking if an object has a given property directly
    // on itself (in other words, not on a prototype).
    has = function (obj, key) {
        return hasOwnProp.call(obj, key);
    };

    // The cornerstone, an `each` implementation, aka `forEach`.
    // Handles objects with the built-in `forEach`, arrays, and raw objects.
    // Delegates to **ECMAScript 5**'s native `forEach` if available.
    each = function (obj, iterator, context) {
        if (obj == null) {
            return;
        }
        if (nativeForEach && obj.forEach === nativeForEach) {
            obj.forEach(iterator, context);
        } else if (obj.length === +obj.length) {
            for (var i = 0, l = obj.length; i < l; i++) {
                if (iterator.call(context, obj[i], i, obj) === breaker) {
                    return;
                }
            }
        } else {
            for (var key in obj) {
                if (has(obj, key)) {
                    if (iterator.call(context, obj[key], key, obj) === breaker) {
                        return;
                    }
                }
            }
        }
    };

    // Extend a given object with all the properties in passed-in object(s).
    extend = function (obj) {
        each(slice.call(arguments, 1), function (source) {
            for (var prop in source) {
                obj[prop] = source[prop];
            }
        });
        return obj;
    };

    // Is a given value an array?
    // Delegates to ECMA5's native Array.isArray
    // switched to ===, not sure why underscore used ==
    isArray = nativeIsArray || function (obj) {
        return toString.call(obj) === '[object Array]';
    };

    // Is a given variable an object?
    isObject = function (obj) {
        return obj === Object(obj);
    };

    // switched to ===, not sure why underscore used ==
    isString = function (obj) {
        return toString.call(obj) === '[object String]';
    };

    // switched to ===, not sure why underscore used ==
    isNumber = function (obj) {
        return toString.call(obj) === '[object Number]';
    };

    // switched to ===, not sure why underscore used ==
    if (typeof (/./) !== 'function') {
        isFunction = function (obj) {
            return typeof obj === 'function';
        };
    } else {
        isFunction = function (obj) {
            return toString.call(obj) === '[object Function]';
        };
    }

    // Is a given value an ejs object?
    // Yes if object and has "_type", "_self", and "toString" properties
    isEJSObject = function (obj) {
        return (isObject(obj) &&
            has(obj, '_type') &&
            has(obj, '_self') &&
            has(obj, 'toString'));
    };

    isQuery = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'query');
    };

    isFilter = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'filter');
    };

    isFacet = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'facet');
    };

    isScriptField = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'script field');
    };

    isGeoPoint = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'geo point');
    };

    isIndexedShape = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'indexed shape');
    };

    isShape = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'shape');
    };

    isSort = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'sort');
    };

    isHighlight = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'highlight');
    };

    isSuggest = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'suggest');
    };

    isGenerator = function (obj) {
        return (isEJSObject(obj) && obj._type() === 'generator');
    };

    // Document

    ejs.Document = function (index, type, id) {
        var params = {},
        // converts client params to a string param1=val1&param2=val1
        genParamStr = function () {
            var clientParams = genClientParams(),
                parts = [];

            for (var p in clientParams) {
                if (!has(clientParams, p)) {
                    continue;
                }

                parts.push(p + '=' + encodeURIComponent(clientParams[p]));
            }

            return parts.join('&');
        },

        // Converts the stored params into parameters that will be passed
        // to a client.  Certain parameter are skipped, and others require
        // special processing before being sent to the client.
        genClientParams = function () {
            var clientParams = {};

            for (var param in params) {
                if (!has(params, param)) {
                    continue;
                }

                // skip params that don't go in the query string
                if (param === 'upsert' || param === 'source' ||
                    param === 'script' || param === 'lang' || param === 'params') {
                    continue;
                }

                // process all over params
                var paramVal = params[param];
                if (isArray(paramVal)) {
                    paramVal = paramVal.join();
                }

                clientParams[param] = paramVal;
            }

            return clientParams;
        };

        return {

            /**
             Sets the index the document belongs to.

             @member ejs.Document
             @param {String} idx The index name
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            index: function (idx) {
                if (idx == null) {
                    return index;
                }

                index = idx;
                return this;
            },

            /**
             Sets the type of the document.

             @member ejs.Document
             @param {String} t The type name
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            type: function (t) {
                if (t == null) {
                    return type;
                }

                type = t;
                return this;
            },

            /**
             Sets the id of the document.

             @member ejs.Document
             @param {String} i The document id
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            id: function (i) {
                if (i == null) {
                    return id;
                }

                id = i;
                return this;
            },

            /**
             <p>Sets timestamp of the document.</p>

             <p>By default the timestamp will be set to the time the docuement was indexed.</p>

             <p>This option is valid during the following operations:
             <code>index</code> and <code>update</code></p>

             @member ejs.Document
             @param {String} parent The parent value
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            timestamp: function (ts) {
                if (ts == null) {
                    return params.timestamp;
                }

                params.timestamp = ts;
                return this;
            },
            /**
             <p>Sets the fields of the document to return.</p>

             <p>By default the <code>_source</code> field is returned.  Pass a single value
             to append to the current list of fields, pass an array to overwrite the current
             list of fields.  The returned fields will either be loaded if they are stored,
             or fetched from the <code>_source</code></p>

             <p>This option is valid during the following operations:
             <code>get</code> and <code>update</code></p>

             @member ejs.Document
             @param {String || Array} fields a single field name or array of field names.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fields: function (fields) {
                if (params.fields == null) {
                    params.fields = [];
                }

                if (fields == null) {
                    return params.fields;
                }

                if (isString(fields)) {
                    params.fields.push(fields);
                } else if (isArray(fields)) {
                    params.fields = fields;
                } else {
                    throw new TypeError('Argument must be string or array');
                }

                return this;
            },

            /**
             <p>Sets the source document.</p>

             <p>When set during an update operation, it is used as the partial update document.</p>

             <p>This option is valid during the following operations:
             <code>index</code> and <code>update</code></p>

             @member ejs.Document
             @param {Object} doc the source document.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            source: function (doc) {
                if (doc == null) {
                    return params.source;
                }

                if (!isObject(doc)) {
                    throw new TypeError('Argument must be an object');
                }

                params.source = doc;
                return this;
            },

            /**
             <p>Allows you to serialize this object into a JSON encoded string.</p>

             @member ejs.Document
             @returns {String} returns this object as a serialized JSON string.
             */
            toString: function () {
                return JSON.stringify(params);
            },

            /**
             <p>The type of ejs object.  For internal use only.</p>

             @member ejs.Document
             @returns {String} the type of object
             */
            _type: function () {
                return 'document';
            },

            /**
             <p>Retrieves the internal <code>document</code> object. This is
             typically used by internal API functions so use with caution.</p>

             @member ejs.Document
             @returns {Object} returns this object's internal object.
             */
            _self: function () {
                return params;
            },

            /**
             <p>Retrieves a document from the given index and type.</p>

             @member ejs.Document
             @param {Function} successcb A callback function that handles the response.
             @param {Function} errorcb A callback function that handles errors.
             @returns {Object} The return value is dependent on client implementation.
             */
            doGet: function (successcb, errorcb) {
                // make sure the user has set a client
                if (ejs.client == null) {
                    throw new Error("No Client Set");
                }

                if (index == null || type == null || id == null) {
                    throw new Error('Index, Type, and ID must be set');
                }

                // we don't need to convert the client params to a string
                // on get requests, just create the url and pass the client
                // params as the data
                var url = '/api/idx/get/' + index + '/' + type + '/' + id;

                return ejs.client.get(url, genClientParams(), successcb, errorcb);
            },

            /**
             <p>Stores a document in the given index and type.  If no id
             is set, one is created during indexing.</p>

             @member ejs.Document
             @param {Function} successcb A callback function that handles the response.
             @param {Function} errorcb A callback function that handles errors.
             @returns {Object} The return value is dependent on client implementation.
             */
            doSave: function (successcb, errorcb) {
                // make sure the user has set a client
                if (ejs.client == null) {
                    throw new Error("No Client Set");
                }

                if (index == null || type == null) {
                    throw new Error('Index and Type must be set');
                }

                if (params.source == null) {
                    throw new Error('No source document found');
                }

                var url = '/api/idx/save/' + index + '/' + type,
                    data = JSON.stringify(params.source),
                    paramStr = genParamStr(),
                    response;

                if (id != null) {
                    url = url + '/' + id;
                }

                if (paramStr !== '') {
                    url = url + '?' + paramStr;
                }

                // do post if id not set so one is created
                response = ejs.client.post(url, data, successcb, errorcb);

                return response;
            },

            /**
             <p>Deletes the document from the given index and type using the
             speciifed id.</p>

             @member ejs.Document
             @param {Function} successcb A callback function that handles the response.
             @param {Function} errorcb A callback function that handles errors.
             @returns {void} Returns the value of the callback when executing on the server.
             */
            doDelete: function (successcb, errorcb) {
                // make sure the user has set a client
                if (ejs.client == null) {
                    throw new Error("No Client Set");
                }

                if (index == null || type == null || id == null) {
                    throw new Error('Index, Type, and ID must be set');
                }

                var url = '/api/idx/delete/' + index + '/' + type + '/' + id,
                    data = '',
                    paramStr = genParamStr();

                if (paramStr !== '') {
                    url = url + '?' + paramStr;
                }

                return ejs.client.post(url, data, successcb, errorcb);
            }

        };
    };

    /**
     @class
         <p>The <code>Request</code> object provides methods generating and
     executing search requests.</p>

     @name ejs.Request

     @desc
     <p>Provides methods for executing search requests</p>

     @param {Object} conf A configuration object containing the initilization
     parameters.  The following parameters can be set in the conf object:
     indices - single index name or array of index names
     types - single type name or array of types
     routing - the shard routing value
     */
    ejs.Request = function (conf) {

        var query, indices, types, params = {},

        // gernerates the correct url to the specified REST endpoint
            getRestPath = function (endpoint) {
                var searchUrl = '/api/idx/' + endpoint,
                    parts = [];

                // join any indices
                if (indices.length > 0) {
                    searchUrl = searchUrl + '/' + indices.join();
                }
                else {
                    throw new Error("At least one index should be set");
                }

                // join any types
                if (types.length > 0) {
                    searchUrl = searchUrl + '/' + types.join();
                }
                else {
                    searchUrl = searchUrl + '/_any';
                }

                for (var p in params) {
                    if (!has(params, p) || params[p] === '') {
                        continue;
                    }

                    parts.push(p + '=' + encodeURIComponent(params[p]));
                }

                if (parts.length > 0) {
                    searchUrl = searchUrl + '?' + parts.join('&');
                }

                return searchUrl;
            };

        /**
         The internal query object.
         @member ejs.Request
         @property {Object} query
         */
        query = {};

        conf = conf || {};
        // check if we are searching across any specific indeices
        if (conf.indices == null) {
            indices = [];
        } else if (isString(conf.indices)) {
            indices = [conf.indices];
        } else {
            indices = conf.indices;
        }

        // check if we are searching across any specific types
        if (conf.types == null) {
            types = [];
        } else if (isString(conf.types)) {
            types = [conf.types];
        } else {
            types = conf.types;
        }

        // check that an index is specified when a type is
        // if not, search across _all indices
        if (indices.length === 0 && types.length > 0) {
            indices = ["_all"];
        }

        if (conf.routing != null) {
            params.routing = conf.routing;
        }

        return {

            /**
             <p>Sets the sorting for the query.  This accepts many input formats.</p>

             <dl>
             <dd><code>sort()</code> - The current sorting values are returned.</dd>
             <dd><code>sort(fieldName)</code> - Adds the field to the current list of sorting values.</dd>
             <dd><code>sort(fieldName, order)</code> - Adds the field to the current list of
             sorting with the specified order.  Order must be asc or desc.</dd>
             <dd><code>sort(ejs.Sort)</code> - Adds the Sort value to the current list of sorting values.</dd>
             <dd><code>sort(array)</code> - Replaces all current sorting values with values
             from the array.  The array must contain only strings and Sort objects.</dd>
             </dl>

             <p>Multi-level sorting is supported so the order in which sort fields
             are added to the query requests is relevant.</p>

             <p>It is recommended to use <code>Sort</code> objects when possible.</p>

             @member ejs.Request
             @param {String} fieldName The field to be sorted by.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            sort: function () {
                var i, len;

                if (!has(query, "sort")) {
                    query.sort = [];
                }

                if (arguments.length === 0) {
                    return query.sort;
                }

                // if passed a single argument
                if (arguments.length === 1) {
                    var sortVal = arguments[0];

                    if (isString(sortVal)) {
                        // add  a single field name
                        query.sort.push(sortVal);
                    } else if (isSort(sortVal)) {
                        // add the Sort object
                        query.sort.push(sortVal._self());
                    } else if (isArray(sortVal)) {
                        // replace with all values in the array
                        // the values must be a fieldName (string) or a
                        // Sort object.  Any other type throws an Error.
                        query.sort = [];
                        for (i = 0, len = sortVal.length; i < len; i++) {
                            if (isString(sortVal[i])) {
                                query.sort.push(sortVal[i]);
                            } else if (isSort(sortVal[i])) {
                                query.sort.push(sortVal[i]._self());
                            } else {
                                throw new TypeError('Invalid object in array');
                            }
                        }
                    } else {
                        // Invalid object type as argument.
                        throw new TypeError('Argument must be string, Sort, or array');
                    }
                } else if (arguments.length === 2) {
                    // handle the case where a single field name and order are passed
                    var field = arguments[0],
                        order = arguments[1];

                    if (isString(field) && isString(order)) {
                        order = order.toLowerCase();
                        if (order === 'asc' || order === 'desc') {
                            var sortObj = {};
                            sortObj[field] = {order: order};
                            query.sort.push(sortObj);
                        }
                    }
                }

                return this;
            },

            /**
             Sets the number of results/documents to be returned. This is set on a per page basis.

             @member ejs.Request
             @param {Integer} s The number of results that are to be returned by the search.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            size: function (s) {
                if (s == null) {
                    return query.size;
                }

                query.size = s;
                return this;
            },

            /**
             By default, searches return full documents, meaning every property or field.
             This method allows you to specify which fields you want returned.

             Pass a single field name and it is appended to the current list of
             fields.  Pass an array of fields and it replaces all existing
             fields.

             @member ejs.Request
             @param {String || Array} s The field as a string or fields as array
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            fields: function (fieldList) {
                if (fieldList == null) {
                    return query.fields;
                }

                if (query.fields == null) {
                    query.fields = [];
                }

                if (isString(fieldList)) {
                    query.fields.push(fieldList);
                } else if (isArray(fieldList)) {
                    query.fields = fieldList;
                } else {
                    throw new TypeError('Argument must be string or array');
                }

                return this;
            },

            /**
             A search result set could be very large (think Google). Setting the
             <code>from</code> parameter allows you to page through the result set
             by making multiple request. This parameters specifies the starting
             result/document number point. Combine with <code>size()</code> to achieve paging.

             @member ejs.Request
             @param {Array} f The offset at which to start fetching results/documents from the result set.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            from: function (f) {
                if (f == null) {
                    return query.from;
                }

                query.from = f;
                return this;
            },

            /**
             Allows you to set the specified query on this search object. This is the
             query that will be used when the search is executed.

             @member ejs.Request
             @param {Query} someQuery Any valid <code>Query</code> object.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            query: function (someQuery) {
                if (someQuery == null) {
                    return query.query;
                }

                if (!isQuery(someQuery)) {
                    throw new TypeError('Argument must be a Query');
                }

                query.query = someQuery._self();
                return this;
            },

            /**
             Allows you to set the specified indices on this request object. This is the
             set of indices that will be used when the search is executed.

             @member ejs.Request
             @param {Array} indexArray An array of collection names.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            indices: function (indexArray) {
                if (indexArray == null) {
                    return indices;
                } else if (isString(indexArray)) {
                    indices = [indexArray];
                } else if (isArray(indexArray)) {
                    indices = indexArray;
                } else {
                    throw new TypeError('Argument must be a string or array');
                }

                // check that an index is specified when a type is
                // if not, search across _all indices
                if (indices.length === 0 && types.length > 0) {
                    indices = ["_all"];
                }

                return this;
            },

            /**
             Allows you to set the specified content-types on this request object. This is the
             set of indices that will be used when the search is executed.

             @member ejs.Request
             @param {Array} typeArray An array of content-type names.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            types: function (typeArray) {
                if (typeArray == null) {
                    return types;
                } else if (isString(typeArray)) {
                    types = [typeArray];
                } else if (isArray(typeArray)) {
                    types = typeArray;
                } else {
                    throw new TypeError('Argument must be a string or array');
                }

                // check that an index is specified when a type is
                // if not, search across _all indices
                if (indices.length === 0 && types.length > 0) {
                    indices = ["_all"];
                }

                return this;
            },

            /**
             Allows you to set the specified facet on this request object. Multiple facets can
             be set, all of which will be returned when the search is executed.

             @member ejs.Request
             @param {Facet} facet Any valid <code>Facet</code> object.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            facet: function (facet) {
                if (facet == null) {
                    return query.facets;
                }

                if (query.facets == null) {
                    query.facets = {};
                }

                if (!isFacet(facet)) {
                    throw new TypeError('Argument must be a Facet');
                }

                extend(query.facets, facet._self());

                return this;
            },

            /**
             Allows you to set a specified filter on this request object.

             @member ejs.Request
             @param {Object} filter Any valid <code>Filter</code> object.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            filter: function (filter) {
                if (filter == null) {
                    return query.filter;
                }

                if (!isFilter(filter)) {
                    throw new TypeError('Argument must be a Filter');
                }

                query.filter = filter._self();
                return this;
            },

            /**
             Performs highlighting based on the <code>Highlight</code>
             settings.

             @member ejs.Request
             @param {Highlight} h A valid Highlight object
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            highlight: function (h) {
                if (h == null) {
                    return query.highlight;
                }

                if (!isHighlight(h)) {
                    throw new TypeError('Argument must be a Highlight object');
                }

                query.highlight = h._self();
                return this;
            },

            /**
             Allows you to set the specified suggester on this request object.
             Multiple suggesters can be set, all of which will be returned when
             the search is executed.  Global suggestion text can be set by
             passing in a string vs. a <code>Suggest</code> object.

             @since elasticsearch 0.90

             @member ejs.Request
             @param {String || Suggest} s A valid Suggest object or a String to
             set as the global suggest text.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            suggest: function (s) {
                if (s == null) {
                    return query.suggest;
                }

                if (query.suggest == null) {
                    query.suggest = {};
                }

                if (isString(s)) {
                    query.suggest.text = s;
                } else if (isSuggest(s)) {
                    extend(query.suggest, s._self());
                } else {
                    throw new TypeError('Argument must be a string or Suggest object');
                }

                return this;
            },

            /**
             Boosts hits in the specified index by the given boost value.

             @member ejs.Request
             @param {String} index the index to boost
             @param {Double} boost the boost value
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            indexBoost: function (index, boost) {
                if (query.indices_boost == null) {
                    query.indices_boost = {};
                }

                if (arguments.length === 0) {
                    return query.indices_boost;
                }

                query.indices_boost[index] = boost;
                return this;
            },

            /**
             Enable/Disable explanation of score for each search result.

             @member ejs.Request
             @param {Boolean} trueFalse true to enable, false to disable
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            explain: function (trueFalse) {
                if (trueFalse == null) {
                    return query.explain;
                }

                query.explain = trueFalse;
                return this;
            },

            /**
             Enable/Disable returning version number for each search result.

             @member ejs.Request
             @param {Boolean} trueFalse true to enable, false to disable
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            version: function (trueFalse) {
                if (trueFalse == null) {
                    return query.version;
                }

                query.version = trueFalse;
                return this;
            },

            /**
             Filters out search results will scores less than the specified minimum score.

             @member ejs.Request
             @param {Double} min a positive <code>double</code> value.
             @returns {Object} returns <code>this</code> so that calls can be chained.
             */
            minScore: function (min) {
                if (min == null) {
                    return query.min_score;
                }

                query.min_score = min;
                return this;
            },

            /**
             Allows you to serialize this object into a JSON encoded string.

             @member ejs.Request
             @returns {String} returns this object as a serialized JSON string.
             */
            toString: function () {
                return JSON.stringify(query);
            },

            /**
             The type of ejs object.  For internal use only.

             @member ejs.Request
             @returns {String} the type of object
             */
            _type: function () {
                return 'request';
            },

            /**
             Retrieves the internal <code>query</code> object. This is typically used by
             internal API functions so use with caution.

             @member ejs.Request
             @returns {String} returns this object's internal object representation.
             */
            _self: function () {
                return query;
            },

            /**
             Executes a delete by query request using the current query.

             @member ejs.Request
             @param {Function} successcb A callback function that handles the response.
             @param {Function} errorcb A callback function that handles errors.
             @returns {Object} Returns a client specific object.
             */
            doDeleteByQuery: function (successcb, errorcb) {
                var queryData = JSON.stringify(query.query);

                // make sure the user has set a client
                if (ejs.client == null) {
                    throw new Error("No Client Set");
                }

                return ejs.client.del(getRestPath('delete-by-query'), queryData, successcb, errorcb);
            },

            /**
             Executes a count request using the current query.

             @member ejs.Request
             @param {Function} successcb A callback function that handles the count response.
             @param {Function} errorcb A callback function that handles errors.
             @returns {Object} Returns a client specific object.
             */
            doCount: function (successcb, errorcb) {
                var queryData = JSON.stringify(query.query);

                // make sure the user has set a client
                if (ejs.client == null) {
                    throw new Error("No Client Set");
                }

                return ejs.client.post(getRestPath('count'), queryData, successcb, errorcb);
            },

            /**
             Executes the search.

             @member ejs.Request
             @param {Boolean} refresh A boolean value that indicates whether or not to automatically refresh the index.
             @param {Function} successcb A callback function that handles the search response.
             @param {Function} errorcb A callback function that handles errors.
             @returns {Object} Returns a client specific object.
             */
            doSearch: function (refresh, successcb, errorcb) {

                if (refresh != null) {
                    query.refresh = refresh;
                }

                var queryData = JSON.stringify(query);

                // make sure the user has set a client
                if (ejs.client == null) {
                    throw new Error("No Client Set");
                }

                if (refresh != null) {
                    params.refresh = refresh;
                }

                return ejs.client.post(getRestPath('search'), queryData, successcb, errorcb);
            },

            getExportRequestData: function (fields) {
                var queryData = JSON.stringify(query);

                // make sure the user has set a client
                if (ejs.client == null) {
                    throw new Error("No Client Set");
                }

                return { url: getRestPath('export') + '?fields=' + encodeURIComponent(fields.join(',')), data: queryData };
            }
        };
    };




})(window.ejs)

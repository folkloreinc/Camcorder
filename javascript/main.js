require.config({

    baseUrl: '/javascript',

    paths: {

        'text' : '../bower_components/requirejs-text/text',
        'template' : 'vendors/template',

        'eventdispatcher' : 'vendors/EventDispatcher'

    },
    shim: {
        'template' : {exports:'tmpl'},
        'eventdispatcher' : {exports:'EventDispatcher'}
    }
});

define('main', ['lib/camcorder'], function(Camcorder) {

    'use strict';

    return Camcorder;

});
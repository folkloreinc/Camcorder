/**
 * 
 * EventDispatcher
 * @author mrdoob / http://mrdoob.com/
 * 
 */
(function () {

    var EventDispatcher = function () {}

    EventDispatcher.prototype = {

        constructor: EventDispatcher,

        apply: function ( object ) {

            object.on = $.proxy(EventDispatcher.prototype.on,object);
            object.hasEvent = $.proxy(EventDispatcher.prototype.hasEvent,object);
            object.off = $.proxy(EventDispatcher.prototype.off,object);
            object.trigger = $.proxy(EventDispatcher.prototype.trigger,object);

        },

        on: function ( type, listener ) {

            if ( this._listeners === undefined ) this._listeners = {};

            var listeners = this._listeners;

            if ( listeners[ type ] === undefined ) {

                listeners[ type ] = [];

            }

            if ( $.inArray(listener,listeners[ type ]) === - 1 ) {

                listeners[ type ].push( listener );

            }

        },

        hasEvent: function ( type, listener ) {

            if ( this._listeners === undefined ) return false;

            var listeners = this._listeners;

            if ( listeners[ type ] !== undefined && $.inArray(listener,listeners[ type ]) !== - 1 ) {

                return true;

            }

            return false;

        },

        off: function ( type, listener ) {

            if ( this._listeners === undefined ) return;

            var listeners = this._listeners;
            var listenerArray = listeners[ type ];

            if ( listenerArray !== undefined ) {

                var index = $.inArray(listener,listenerArray);

                if ( index !== - 1 ) {

                    listenerArray.splice( index, 1 );

                }

            }

        },

        trigger: function ( type ) {
                
            if ( this._listeners === undefined ) return;

            var listeners = this._listeners;
            var listenerArray = listeners[ type ];

            var args = [];
            if(arguments.length > 1) {
                for(var i = 1, al = arguments.length; i < al; i++) {
                    args.push(arguments[i]);
                }
            }

            if ( listenerArray !== undefined ) {

                var array = [];
                var length = listenerArray.length;

                for ( var i = 0; i < length; i ++ ) {

                    array[ i ] = listenerArray[ i ];

                }

                for ( var i = 0; i < length; i ++ ) {

                    array[ i ].apply( this,  args);

                }

            }

        }

    };

    window.EventDispatcher = EventDispatcher;

}());
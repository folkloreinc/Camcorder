define([

    'template',

    'eventdispatcher',

    'text!lib/templates/embed.html'

],
function (

    template,

    EventDispatcher,

    embedTemplate

) {

    'use strict';

    function Camcorder(el,options) {

        this.el = $(el);
        this.options = $.extend({
            'mode' : Camcorder.MODE_RECORD,
            'recordId' : null,
            'debugMode' : true,
            'volume' : 1.0,
            'serverURL' : 'rtmp://localhost/camcorder',
            'flashVersion' : 'auto',
            'swf' : 'swf/',
            'expressInstall' : 'expressInstall.swf',
            'template' : template(embedTemplate),
            'params' : {
                'wmode' : 'window',
                'menu' : 'false',
                'allowScriptAccess' : 'always',
                'allowFullScreen' : 'false'
            },
            'flashVars': {}
        },options);

        this.mode = this.options.mode;
        this.uniqueId = 'camcorder_'+(new Date()).getTime();
        this.recordId = this.options.recordId || this.uniqueId;
        this.callbackName = this.uniqueId+'_listener';
        this._flash = null;

        this.recording = false;
        this.playing = false;
        this.paused = false;

        window[this.callbackName] = $.proxy(this._handleFlashCallback,this);

        if(this.options.flashVersion === 'auto') {
            this.detectFlashVersion();
        }

        this.init();

    }

    EventDispatcher.prototype.apply( Camcorder.prototype );

    Camcorder.isSupported = function() {

        if (swfobject.hasFlashPlayerVersion('9.0.0'))
        {
            return true;
        }
        else
        {
            return false;
        }

    };

    Camcorder.MODE_RECORD = 'record';
    Camcorder.MODE_PLAYBACK = 'playback';

    Camcorder.prototype.detectFlashVersion = function() {

        if (swfobject.hasFlashPlayerVersion('11.0.0'))
        {
            this.options.flashVersion = 11;
        }
        else if (swfobject.hasFlashPlayerVersion('9.0.0'))
        {
            this.options.flashVersion = 9;
        }

    };

    Camcorder.prototype.init = function() {

        this._embedSWF();

    };

    Camcorder.prototype.record = function()
    {
        this._flash.record();
    };

    Camcorder.prototype.stop = function()
    {
        this._flash.stop();
    };

    Camcorder.prototype.play = function()
    {
        this._flash.play();
    };

    Camcorder.prototype.pause = function()
    {
        this._flash.pause();
    };

    Camcorder.prototype.seek = function(time)
    {
        this._flash.seek(time);
    };

    Camcorder.prototype.getCurrentTime = function()
    {
        return this._flash.getCurrentTime();
    };

    Camcorder.prototype.setMode = function(mode)
    {
        this.mode = mode;
        this._flash.setMode(mode);

        this.playing = false;
        this.recording = false;
        this.paused = false;
    };
    
    Camcorder.prototype.setRecordId = function(recordId)
    {
        this.recordId = recordId;
        this._flash.setRecordId(recordId);
    };

    Camcorder.prototype.setVolume = function(volume)
    {
        this._flash.setVolume(volume);
        this.options.volume = volume;
    };

    Camcorder.prototype.mute = function()
    {
        this._flash.setVolume(0);
    };

    Camcorder.prototype.unmute = function()
    {
        this._flash.setVolume(this.options.volume);
    };

    Camcorder.prototype.getMicrophoneActivity = function()
    {
        return this._flash.getMicrophoneActivity();
    };

    Camcorder.prototype.getMicrophoneIntensity = function()
    {
        return this._flash.getMicrophoneIntensity();
    };

    Camcorder.prototype.snapshot = function()
    {
        return this._flash.snapshot();
    };

    Camcorder.prototype.destroy = function() {

        this.off();

        this.el.find('#'+this.uniqueId).remove();
        window[this.callbackName] = null;

    };

    Camcorder.prototype._embedSWF = function() {

        var html = this.options.template({
            id: this.uniqueId
        });
        var $container = $(html);
        this.el.append($container);

        var flashVars = $.extend({
            'mode' : this.mode,
            'serverURL' : this.options.serverURL,
            'jsCallback' : this.callbackName,
            'recordId' : this.recordId,
            'debugMode' : this.options.debugMode ? 'true':'false'
        },this.options.flashVars);

        var params = this.options.params;

        var attr = {
            'id' : this.uniqueId
        };

        var swfDir = this.options.swf.replace(/\/?$/,'/');
        var src = swfDir+'camcorder.swf';
        //var src = swfDir+'camcorder'+(this.flashVersion === 9 ? '_basic':'')+'.swf';
        var expressInstall = swfDir+this.options.expressInstall;
        var el = this.el.find('#'+this.uniqueId)[0];

        swfobject.embedSWF(src, el, '100%', '100%', '9.0.0', expressInstall, flashVars, params, attr, $.proxy(this._handleFlashReady,this));
    };

    Camcorder.prototype._handleFlashReady = function(e) {

        if(!e.success) {
            this._flash = null;
            this.trigger('error');
        } else {
            this._flash = swfobject.getObjectById(e.id);
        }

    };

    Camcorder.prototype._handleFlashCallback = function(code, value) {

        switch(code) {

        case 'record.start':
            this.recording = true;
            this.playing = false;
            this.paused = false;
            break;
        case 'record.stop':
            this.recording = false;
            this.paused = false;
            break;
        case 'record.pause':
            this.recording = true;
            this.paused = true;
            break;
        case 'playback.play':
            this.recording = false;
            this.playing = true;
            this.paused = false;
            break;
        case 'playback.pause':
            this.recording = false;
            this.paused = true;
            break;
        case 'playback.stop':
            this.recording = false;
            this.paused = false;
            break;
        case 'playback.ended':
            this.recording = false;
            this.paused = false;
            break;

        }

        window.setTimeout($.proxy(function() {
            this.trigger(code,value);
        },this),1);

    };

    return Camcorder;

});

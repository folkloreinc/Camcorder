package
{
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.display.LoaderInfo;

    import flash.events.Event;
    import flash.events.NetStatusEvent;
    import flash.events.ActivityEvent;

    import flash.net.NetConnection;

    import flash.utils.ByteArray;

    import flash.external.ExternalInterface;
    import flash.system.Security;

    import VCR;
    import Camera;

    import com.folklore.events.VCREvent;
    import com.folklore.events.CameraEvent;

    public class Camcorder extends Sprite
    {
        /*
         *
         * Constants
         * 
         */
        public static const MODE_RECORD : String = "record";
        public static const MODE_PLAYBACK : String = "playback";

        private static const DEFAULT_SPECTRUM_RADIUS : Number = 150;
        private static const DEFAULT_SPECTRUM_NOISE : Number = 200;
        private static const DEFAULT_SPECTRUM_POINTS : Number = 360;

        /*
         *
         * Properties
         * 
         */
        private static var _debugMode:Boolean;

        private var _connection:NetConnection;

        private var _vcr:VCR;
        private var _camera:Camera;

        private var _serverURL:String;
        private var _mode:String;
        private var _jsCallback:String;

        private var _isReady:Boolean = false;

        private var _recordId:String;

        private var _spectrumMask:SpectrumMask;
        private var _spectrumByteArray:ByteArray = new ByteArray();
        private var _spectrumRadius : Number;
        private var _spectrumNoise : Number;
        private var _spectrumPoints : Number;

        public function Camcorder()
        {
            //Stage
            root.stage.scaleMode = StageScaleMode.NO_SCALE;
            root.stage.align = StageAlign.TOP_LEFT;

            //Get flash vars
            _jsCallback = getStringFlashVar("jsCallback", null);
            _serverURL = getStringFlashVar("serverURL", null);
            _mode = getStringFlashVar("mode", MODE_RECORD);
            _recordId = getStringFlashVar("recordId", createRecordId());
            _debugMode = getStringFlashVar("debugMode", null) == 'true' ? true:false;

            _spectrumRadius = getIntFlashVar("spectrumRadius", DEFAULT_SPECTRUM_RADIUS);
            _spectrumNoise = getIntFlashVar("spectrumNoise", DEFAULT_SPECTRUM_NOISE);
            _spectrumPoints = getIntFlashVar("spectrumPoints", DEFAULT_SPECTRUM_POINTS);

            //Validate
            if(!_serverURL) {
                log( 'You need to set serverURL', 'error' );
                return;
            }

            //Init
            if (stage && root) init();
            else addEventListener(Event.ADDED_TO_STAGE, init);

        }

        /*
         *
         *  Init
         * 
         */
        private function init():void
        {


            log('Init');
            log('Mode: '+_mode);
            log('Record ID: '+_recordId);
            log('Server URL: '+_serverURL);
            log('------');

            initConnection();
            
            //VCR
            _vcr = new VCR(_connection, _recordId);
            _vcr.setSize(stage.stageWidth,stage.stageHeight);
            _vcr.addEventListener(VCREvent.READY, onVCRReady);
            _vcr.addEventListener(VCREvent.PLAY, onVCRPlay);
            _vcr.addEventListener(VCREvent.PLAYED, onVCRPlayed);
            _vcr.addEventListener(VCREvent.PAUSE, onVCRPause);
            _vcr.addEventListener(VCREvent.PAUSED, onVCRPaused);
            _vcr.addEventListener(VCREvent.STOP, onVCRStop);
            _vcr.addEventListener(VCREvent.STOPPED, onVCRStopped);
            _vcr.addEventListener(VCREvent.ENDED, onVCREnded);

            //Camera
            _camera = new Camera(_connection, _recordId);
            _camera.setSize(stage.stageWidth,stage.stageHeight);
            _camera.addEventListener(ActivityEvent.ACTIVITY, onCameraActivity);
            _camera.addEventListener(CameraEvent.MICROPHONE_READY, onCameraMicrophoneReady);
            _camera.addEventListener(CameraEvent.CAMERA_READY, onCameraReady);
            _camera.addEventListener(CameraEvent.RECORD_START, onCameraRecordStart);
            _camera.addEventListener(CameraEvent.RECORD_STARTED, onCameraRecordStarted);
            _camera.addEventListener(CameraEvent.RECORD_PAUSE, onCameraRecordPause);
            _camera.addEventListener(CameraEvent.RECORD_PAUSED, onCameraRecordPaused);
            _camera.addEventListener(CameraEvent.RECORD_STOP, onCameraRecordStop);
            _camera.addEventListener(CameraEvent.RECORD_STOPPED, onCameraRecordStopped);
            _camera.addEventListener(CameraEvent.RECORD_READY, onCameraRecordReady);

            //Spectrum Mask
            _spectrumMask = new SpectrumMask();
            _spectrumMask.radius = _spectrumRadius;
            _spectrumMask.noise = _spectrumNoise;
            _spectrumMask.points = _spectrumPoints;
            _spectrumMask.intensity = 0;
            addChild(_spectrumMask);
            _spectrumMask.draw();

            //Resize
            stage.addEventListener(Event.RESIZE, onResize);

            //JS Api
            initJSApi();

            //Add the sprite
            if(_mode == MODE_PLAYBACK) {
                addChild(_vcr);
                _vcr.mask = _spectrumMask;
            } else if(_mode == MODE_RECORD) {
                addChild(_camera);
                _camera.mask = _spectrumMask;
            }
        }

        private function initConnection():void
        {
            _connection = new NetConnection();
            _connection.addEventListener( NetStatusEvent.NET_STATUS, onConnectionStatus );
            _connection.connect(_serverURL );
        }

        private function initJSApi():void
        {
            if( !ExternalInterface.available )
            {
                return;
            }
            
            Security.allowDomain('*');
            ExternalInterface.addCallback('record',record);
            ExternalInterface.addCallback('play',play);
            ExternalInterface.addCallback('pause',pause);
            ExternalInterface.addCallback('stop',stop);
            ExternalInterface.addCallback('setMode',setMode);
            ExternalInterface.addCallback('getCurrentTime',getCurrentTime);
            ExternalInterface.addCallback('setVolume',setVolume);
            ExternalInterface.addCallback('setSpectrumRadius',setSpectrumRadius);
            ExternalInterface.addCallback('setSpectrumNoise',setSpectrumNoise);
            ExternalInterface.addCallback('setSpectrumPoints',setSpectrumPoints);
            
        }

        /*
         *
         *  External interface methods
         * 
         */
        private function record(recordId:String = null):void
        {
            if(_mode != MODE_RECORD) {
                return;
            }

            _camera.record(recordId);
        }

        private function play(recordId:String = null):void
        {
            if(_mode != MODE_PLAYBACK) {
                return;
            }

            _vcr.play(recordId);
        }

        private function pause():void
        {
            if(_mode == MODE_PLAYBACK) {
                _vcr.pause();
            } else if(_mode == MODE_RECORD) {
                _camera.pause();
            }
        }

        private function stop():void
        {
            if(_mode == MODE_PLAYBACK) {
                _vcr.stop();
            } else if(_mode == MODE_RECORD) {
                _camera.stop();
            }
        }

        private function getCurrentTime():Number
        {
            if(_mode == MODE_PLAYBACK) {
                return _vcr.getCurrentTime();
            }

            return 0.0;
        }

        private function setVolume(volume:Number):void
        {
            if(_mode == MODE_PLAYBACK) {
                _vcr.setVolume(volume);
            }
        }

        private function setMode(mode:String):void
        {

            if(mode == _mode) {
                return;
            }

            var modeSprite:Sprite;
            if(mode == MODE_PLAYBACK) {

                if(_mode == MODE_RECORD) {
                    removeChild(_spectrumMask);
                    removeChild(_camera);
                }

                modeSprite = _vcr;

            } else if(mode == MODE_RECORD) {

                if(_mode == MODE_PLAYBACK) {
                    removeChild(_spectrumMask);
                    removeChild(_vcr);
                }

                modeSprite = _camera;

            }

            if(modeSprite) {
                _isReady = true;
                _mode = mode;
                addChild(_spectrumMask);
                addChild(modeSprite);
                modeSprite.mask = _spectrumMask;
            }
        }

        private function setSpectrumRadius(radius:Number):void
        {
            _spectrumMask.radius = radius;
            _spectrumMask.draw();
        }

        private function setSpectrumNoise(noise:Number):void
        {
            _spectrumMask.noise = noise;
            _spectrumMask.draw();
        }

        private function setSpectrumPoints(points:Number):void
        {
            _spectrumMask.points = points;
            _spectrumMask.draw();
        }

        /*
         *
         *  Private methods
         * 
         */
        private function startSpectrumAnalyzer():void
        {
            log('startSpectrumAnalyzer');
            addEventListener(Event.ENTER_FRAME, onEnterFrame );
        }

        private function stopSpectrumAnalyzer():void
        {
            log('stopSpectrumAnalyzer');
            removeEventListener(Event.ENTER_FRAME, onEnterFrame );
        }

        private function updateSpectrumAnalyzer():void
        {
            var intensity:Number = 0;
            var total:Number = 0;
            var count:Number = 0;

            _spectrumByteArray.position = 0;
            while ( _spectrumByteArray.bytesAvailable ) {
                total += _spectrumByteArray.readFloat();
                count++;
            }
            intensity = count > 0 ? Math.abs(total/count):0;
            if(_mode == MODE_PLAYBACK)
            {
                intensity = intensity*7;
            }

            _spectrumMask.intensity = intensity;
            _spectrumMask.draw();
        }

        /*
         *
         *  Event listeners
         * 
         */
        private function onResize(e:Event = null):void
        {
            log('Resize: '+stage.stageWidth+'x'+stage.stageHeight);

            _vcr.setSize(stage.stageWidth, stage.stageHeight);
            _camera.setSize(stage.stageWidth, stage.stageHeight);
        }

        private function onConnectionStatus( e:NetStatusEvent ):void
        {

            log(e.info.code+': '+e.info.description);

            switch(e.info.code) {

                case "NetConnection.Connect.Success":
                    notify('connection.ready');
                break;

                case "NetConnection.Connect.Failed":
                case "NetConnection.Connect.Rejected":
                    notify('connection.error',e.info);
                    log( 'Couldn\'t connect to the server. Error: ' + e.info.description , 'error');
                break;

            }
        }

        private function onEnterFrame(e:Event = null):void
        {

            if(_mode == MODE_PLAYBACK) {
                _vcr.computeSpectrum(_spectrumByteArray);
            } else if(_mode == MODE_RECORD) {
                _camera.computeSpectrum(_spectrumByteArray);
            }

            updateSpectrumAnalyzer();
        }

        /*
         *
         *  Camera events
         * 
         */
        private function onCameraActivity( e:ActivityEvent ):void
        {

            if(!_isReady && _mode == MODE_RECORD) {
                _isReady = true;
                notify('ready');
                return;
            }

            notify('camera.activity',e.activating);
        }

        private function onCameraReady( e:Event ):void
        {
            startSpectrumAnalyzer();
            notify('camera.ready');
        }

        private function onCameraCleaned( e:Event ):void
        {
            stopSpectrumAnalyzer();
            notify('camera.cleaned');
        }

        private function onCameraMicrophoneReady( e:Event ):void
        {
            notify('microphone.ready');
        }

        private function onCameraRecordStart( e:Event ):void
        {
            notify('record.start');
        }

        private function onCameraRecordStarted( e:Event ):void
        {
            notify('record.started');
        }

        private function onCameraRecordPause( e:Event ):void
        {
            notify('record.pause');
        }

        private function onCameraRecordPaused( e:Event ):void
        {
            notify('record.paused');
        }

        private function onCameraRecordStop( e:Event ):void
        {
            notify('record.stop');
        }

        private function onCameraRecordStopped( e:Event ):void
        {
            notify('record.stopped');
        }

        private function onCameraRecordReady( e:Event ):void
        {
            notify('record.ready',_camera.recording);
        }

        /*
         *
         *  VCR events
         * 
         */
        private function onVCRReady( e:Event ):void
        {
            notify('playback.ready');

            if(!_isReady && _mode == MODE_PLAYBACK) {
                _isReady = true;
                notify('ready');
            }
        }

        private function onVCRPlay( e:Event ):void
        {
            notify('playback.play');
            startSpectrumAnalyzer();
        }

        private function onVCRPlayed( e:Event ):void
        {
            notify('playback.played');
        }

        private function onVCRPause( e:Event ):void
        {
            notify('playback.pause');
        }

        private function onVCRPaused( e:Event ):void
        {
            notify('playback.paused');
        }

        private function onVCRStop( e:Event ):void
        {
            notify('playback.stop');
        }

        private function onVCRStopped( e:Event ):void
        {
            stopSpectrumAnalyzer();
            notify('playback.stopped');
        }

        private function onVCREnded( e:Event ):void
        {
            notify('playback.ended');
        }

        /*
         *
         *  Utility methods
         * 
         */
        private function createRecordId():String
        {
            var date:Date = new Date();
            return 'camera_'+date.time;
        }

        /*
         *
         *  Utility methods
         * 
         */
        
        private function notify( type:String = null, arguments:Object = null ):void
        {
            if( !_jsCallback || !ExternalInterface.available )
                return;
            
            ExternalInterface.call( _jsCallback, type, arguments );

            if(!arguments) {
                log('[Notify] '+type);
            } else {
                log('[Notify] '+type+': '+arguments);
            }
        }

        private function getStringFlashVar(key:String, value:String):String {
            if (LoaderInfo(this.root.loaderInfo).parameters.hasOwnProperty(key)) {
                var ret:String = LoaderInfo(this.root.loaderInfo).parameters[key];
                return ret;
            } else {
                return value;
            }
        }
        
        private function getIntFlashVar(key:String, value:int):int {
            return parseInt(getStringFlashVar(key, String(value)));
        }
        
        private function getBooleanFlashVar(key:String, value:int):int {
            return parseInt(getStringFlashVar(key, String(value)));
        }

        public static function log( msg:String, level:String = 'log' ):void
        {
            if( ExternalInterface.available && _debugMode ) {
                ExternalInterface.call( 'console.'+level, '[Camcorder] '+msg );
            }
        }
    }

}
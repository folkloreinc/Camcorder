package
{
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.display.LoaderInfo;

    import flash.events.Event;
    import flash.events.NetStatusEvent;
    import flash.events.ActivityEvent;

    import flash.media.SoundMixer;
    import flash.media.SoundTransform;

    //import flash.net.NetConnection;
    import com.gearsandcogs.utils.NetConnectionSmart;

    import flash.utils.ByteArray;

    import flash.external.ExternalInterface;
    import flash.system.Security;

    import VCR;
    import Camera;

    import events.VCREvent;
    import events.CameraEvent;

    public class Camcorder extends Sprite
    {
        /*
         *
         * Constants
         *
         */
        public static const MODE_RECORD : String = "record";
        public static const MODE_PLAYBACK : String = "playback";

        /*
         *
         * Properties
         *
         */
        private static var _debugMode:Boolean;

        private var _connection:NetConnectionSmart;
        private var _isConnected:Boolean = false;
        private var _serverURL:String;

        private var _vcr:VCR;
        private var _camera:Camera;
        
        private var _isReady:Boolean = false;

        private var _mode:String;
        private var _recordId:String;
        private var _jsCallback:String;

        private var _spectrumByteArray:ByteArray = new ByteArray();

        private var _playbackIntensityFactor : Number = 0.2;

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
            if(_serverURL) {
                log('Server URL: '+_serverURL);
            }
            log('------');
            
            if(_serverURL && _serverURL.length) {
                initConnection();
            } else {
                initCamera();
                initVCR();
            }

            //Resize
            stage.addEventListener(Event.RESIZE, onResize);

            //JS Api
            initJSApi();
        }

        private function initConnection():void
        {
            _connection = new NetConnectionSmart();
            _connection.addEventListener( NetStatusEvent.NET_STATUS, onConnectionStatus );
            _connection.connect(_serverURL);
        }

        private function initJSApi():void
        {
            if( !ExternalInterface.available )
            {
                log('ExternalInterface is not accessible' , 'error');
                return;
            }

            Security.allowDomain('*');
            
            ExternalInterface.addCallback('record',record);
            ExternalInterface.addCallback('play',play);
            ExternalInterface.addCallback('pause',pause);
            ExternalInterface.addCallback('stop',stop);
            ExternalInterface.addCallback('seek',seek);
            
            ExternalInterface.addCallback('reset',reset);
            
            ExternalInterface.addCallback('setMode',setMode);
            ExternalInterface.addCallback('setRecordId',setRecordId);
            ExternalInterface.addCallback('setVolume',setVolume);
            ExternalInterface.addCallback('setMicrophoneGain',setMicrophoneGain);
            
            ExternalInterface.addCallback('getCurrentTime',getCurrentTime);
            ExternalInterface.addCallback('getMicrophoneActivity',getMicrophoneActivity);
            ExternalInterface.addCallback('getMicrophoneIntensity',getMicrophoneIntensity);
            
            ExternalInterface.addCallback('snapshot',snapshot);

        }
        
        private function initCamera():void
        {
            log('Init Camera');
            
            //Camera
            _camera = new Camera(_connection ? _connection.connection:null, _recordId);
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
            _camera.addEventListener(CameraEvent.SECURITY_OPEN, onCameraSecurityOpen);
            _camera.addEventListener(CameraEvent.SECURITY_CLOSE, onCameraSecurityClose);
            
            if(_mode == MODE_RECORD) {
                addChild(_camera);
                SoundMixer.soundTransform = new SoundTransform(0);
            }
        }
        
        private function initVCR():void
        {
            log('Init VCR');
            
            //VCR
            _vcr = new VCR(_connection ? _connection.connection:null, _recordId);
            _vcr.setSize(stage.stageWidth,stage.stageHeight);
            _vcr.addEventListener(VCREvent.READY, onVCRReady);
            _vcr.addEventListener(VCREvent.PLAY, onVCRPlay);
            _vcr.addEventListener(VCREvent.PLAYED, onVCRPlayed);
            _vcr.addEventListener(VCREvent.PAUSE, onVCRPause);
            _vcr.addEventListener(VCREvent.PAUSED, onVCRPaused);
            _vcr.addEventListener(VCREvent.STOP, onVCRStop);
            _vcr.addEventListener(VCREvent.STOPPED, onVCRStopped);
            _vcr.addEventListener(VCREvent.ENDED, onVCREnded);
            
            if(_mode == MODE_PLAYBACK) {
                addChild(_vcr);
                SoundMixer.soundTransform = new SoundTransform(1.0);
            }
        }
        /*
         *
         *  External interface methods
         *
         */
        private function record(recordId:String = null):void
        {
            if(_mode != MODE_RECORD) {
                log('Cannot record, not in record mode' , 'error');
                return;
            } else if(!_camera) {
                log('Cannot record, camera not ready' , 'error');
                return;
            }
            
            _camera.record(recordId);
        }

        private function play(recordId:String = null):void
        {
            if(_mode != MODE_PLAYBACK) {
                log('Cannot play, not in playback mode' , 'error');
                return;
            } else if(!_vcr) {
                log('Cannot play, vcr not ready' , 'error');
                return;
            }
            
            _vcr.play(recordId);
        }

        private function pause():void
        {
            if(_mode == MODE_PLAYBACK) {
                if(!_vcr) {
                    log('Cannot pause, vcr not ready' , 'error');
                    return;
                }
                _vcr.pause();
            } else if(_mode == MODE_RECORD) {
                if(!_camera) {
                    log('Cannot pause, camera not ready' , 'error');
                    return;
                }
                _camera.pause();
            }
        }

        private function stop():void
        {
            if(_mode == MODE_PLAYBACK) {
                if(!_vcr) {
                    log('Cannot stop, vcr not ready' , 'error');
                    return;
                }
                _vcr.stop();
            } else if(_mode == MODE_RECORD) {
                if(!_camera) {
                    log('Cannot stop, camera not ready' , 'error');
                    return;
                }
                _camera.stop();
            }
        }

        private function seek( time:Number ):void
        {
            if(_mode != MODE_PLAYBACK) {
                log('Cannot seek, not in playback mode' , 'error');
                return;
            } else if(!_vcr) {
                log('Cannot seek, vcr not ready' , 'error');
                return;
            }

            _vcr.seek(time);
        }

        private function reset():void
        {
            if(_mode == MODE_PLAYBACK && _vcr) {
                _vcr.reset();
            }
        }

        private function getCurrentTime():Number
        {
            if(_mode == MODE_PLAYBACK && _vcr) {
                return _vcr.getCurrentTime();
            }

            return 0.0;
        }

        private function getMicrophoneActivity():Number
        {
            if(_mode == MODE_RECORD && _camera) {
                return _camera.getMicrophoneActivity();
            }

            return 0.0;
        }

        private function getMicrophoneIntensity():Number
        {
            if(_mode == MODE_RECORD && _camera) {
                _camera.computeSpectrum(_spectrumByteArray);
                var intensity:Number = 0;
                var total:Number = 0;
                var count:Number = 0;

                _spectrumByteArray.position = 0;
                while ( _spectrumByteArray.bytesAvailable ) {
                    total += _spectrumByteArray.readFloat();
                    count++;
                }
                intensity = count > 0 ? Math.abs(total/count):0;
                return intensity;
            }

            return 0.0;
        }

        private function setVolume(volume:Number):void
        {
            if(_mode == MODE_PLAYBACK) {
                if(volume == 0) {
                    volume = 0.0001;
                }
                _playbackIntensityFactor = volume;
                SoundMixer.soundTransform = new SoundTransform(volume);
            }
        }

        private function setMicrophoneGain(gain:Number):void
        {
            if(!_camera) {
                log('Cannot set microphone gain, camera not ready' , 'error');
                return;
            }
            
            if(_mode == MODE_RECORD) {
                _camera.setMicrophoneGain(gain);
            }
        }

        private function setMode(mode:String):void
        {

            if(mode == _mode) {
                return;
            }

            var modeSprite:Sprite;
            if(mode == MODE_PLAYBACK) {

                if(_mode == MODE_RECORD && _camera) {
                    removeChild(_camera);
                }

                if(_vcr) {
                    modeSprite = _vcr;
                }
                SoundMixer.soundTransform = new SoundTransform(1.0);

            } else if(mode == MODE_RECORD) {

                if(_mode == MODE_PLAYBACK && _vcr) {
                    removeChild(_vcr);
                }
                
                if(_camera) {
                    modeSprite = _camera;
                }
                SoundMixer.soundTransform = new SoundTransform(0);

            }

            if(modeSprite) {
                _isReady = true;
                _mode = mode;
                addChild(modeSprite);
            }
        }
        
        private function setRecordId(recordId:String = null):void
        {
            _recordId = recordId;
            if(_camera) {
                _camera.setRecordId(recordId);
            }
            if(_vcr) {
                _vcr.setRecordId(recordId);
            }
            log('Record ID: '+_recordId);
        }
        
        private function snapshot():String
        {
        
           if(_mode != MODE_RECORD) {
               log('Cannot take a snapshot, not in record mode' , 'error');
               return null;
           }
           
           if(!_camera) {
               log('Cannot take a snapshot, camera not ready' , 'error');
               return null;
           }

           return _camera.snapshot();
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
                intensity = intensity/this._playbackIntensityFactor;
            };
        }

        /*
         *
         *  Event listeners
         *
         */
        private function onResize(e:Event = null):void
        {
            log('Resize: '+stage.stageWidth+'x'+stage.stageHeight);
            
            if(_vcr)
            {
                _vcr.setSize(stage.stageWidth, stage.stageHeight);
            }
            
            if(_camera)
            {
                _camera.setSize(stage.stageWidth, stage.stageHeight);
            }
        }

        private function onConnectionStatus( e:NetStatusEvent ):void
        {
            log(e.info.code+': '+e.info.description);

            switch(e.info.code) {

                case "NetConnection.Connect.Success":
                    _isConnected = true;
                    notify('connection.ready');
                    if(!_camera) {
                        initCamera();
                    }
                    if(!_vcr) {
                        this.initVCR();
                    }
                break;

                case "NetConnection.Connect.Failed":
                case "NetConnection.Connect.Rejected":
                    _isConnected = false;
                    notify('connection.error',e.info);
                    log( 'Couldn\'t connect to the server. Error: ' + e.info.description , 'error');
                break;
                
                case "NetConnection.Connect.Closed":
                    _isConnected = false;
                    notify('connection.closed');
                break;

            }
        }

        private function onEnterFrame(e:Event = null):void
        {
            var hasUpdated:Boolean = false;
            
            if(_mode == MODE_PLAYBACK && _vcr) {
                _vcr.computeSpectrum(_spectrumByteArray);
                hasUpdated = true;
            } else if(_mode == MODE_RECORD && _camera) {
                _camera.computeSpectrum(_spectrumByteArray);
                hasUpdated = true;
            }
            
            if(hasUpdated) {
                updateSpectrumAnalyzer();
            }
        }

        /*
         *
         *  Camera events
         *
         */
        private function onCameraActivity( e:ActivityEvent ):void
        {

            notify('camera.activity',e.activating);
        }

        private function onCameraReady( e:Event ):void
        {
            notify('camera.ready');
            
            if(!_isReady && _mode == MODE_RECORD) {
                _isReady = true;
                notify('ready');
                return;
            }
        }

        private function onCameraSecurityOpen( e:Event ):void
        {
            notify('camera.security_open');
        }
        
        private function onCameraSecurityClose( e:Event ):void
        {
            notify('camera.security_close');
        }

        private function onCameraCleaned( e:Event ):void
        {
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

        private function getBooleanFlashVar(key:String, value:String):Boolean {
            return getStringFlashVar(key, value) === 'true';
        }

        public static function log( msg:String, level:String = 'log' ):void
        {
            if( ExternalInterface.available && _debugMode ) {
                ExternalInterface.call( 'console.'+level, '[Camcorder] '+msg );
            }
        }
    }

}

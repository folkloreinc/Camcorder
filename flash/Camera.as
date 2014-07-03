package
{
	
	import flash.display.Sprite;

	import flash.events.Event;
	import flash.events.ActivityEvent;
	import flash.events.StatusEvent;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.events.SampleDataEvent;
	import flash.events.MouseEvent;

	import flash.media.Video;

	import flash.net.NetConnection;
	import flash.net.NetStream;

	import flash.utils.Timer;
    import flash.utils.ByteArray;

    import flash.external.ExternalInterface;
    import flash.system.Security;
	import flash.system.SecurityPanel;

    import lib.FFT2;
    import com.folklore.events.CameraEvent;
	
	public class Camera extends Sprite
	{

		/*
         *
         * Constants
         * 
         */
		private static const DEFAULT_WIDTH : uint = 640;
		private static const DEFAULT_HEIGHT : uint = 480;
		private static const DEFAULT_QUALITY : uint = 90;
        private static const DEFAULT_FRAMERATE : uint = 30;

		private static const DEFAULT_BUFFER_TIME : uint = 20000;
		private static const DEFAULT_BANDWIDTH : uint = 0;

		private static const DEFAULT_AUDIO_RATE : uint = 44;
		private static const DEFAULT_AUDIO_QUALITY : uint = 10;

		private static const DEFAULT_MOTION_LEVEL : uint = 20;
		private static const DEFAULT_MOTION_TIMEOUT : uint = 2000;

        /*
         *
         * Properties
         * 
         */
		private var _video:Video;
		private var _width:Number = DEFAULT_WIDTH;
		private var _height:Number = DEFAULT_HEIGHT;
		private var _webcamWidth:Number = DEFAULT_WIDTH;
		private var _webcamHeight:Number = DEFAULT_HEIGHT;

		private var _quality:Number = DEFAULT_QUALITY;
		private var _framerate:Number = DEFAULT_FRAMERATE;
		private var _bandwidth:Number = DEFAULT_BANDWIDTH;
		private var _motionLevel:Number = DEFAULT_MOTION_LEVEL;
		private var _motionTimeout:Number = DEFAULT_MOTION_TIMEOUT;
		private var _bufferTime = DEFAULT_BUFFER_TIME / 1000.0;
		private var _audioRate = DEFAULT_AUDIO_RATE;

		private var _flushBufferTimer:Timer;

		public var webcam:flash.media.Camera;
		public var microphone:flash.media.Microphone;

		private var _connection:NetConnection;
		private var _stream:NetStream;

		private var _isPaused:Boolean = false;
		private var _isReady:Boolean = false;
		private var _cameraReady:Boolean = false;
		private var _settingsOpened:Boolean = false;

		public var recording:Object;
		public var recordingStartTime:Date;

		//Spectrum Analyser
		private var m_writePos:int = 0;
        private var m_buf:Vector.<Number> = null;
        private var m_fft:FFT2;                     // FFT object
 
        private var m_tempRe:Vector.<Number>;     // Temporary buffer - real part
        private var m_tempIm:Vector.<Number>;     // Temporary buffer - imaginary part
        private var m_mag:Vector.<Number>;            // Magnitudes (at each of the frequencies below)
        private var m_freq:Vector.<Number>;           // Frequencies (for each of the magnitudes above)
        private var m_win:Vector.<Number>;

        private const LOGN:int = 11;
        private const MIN_DB:int = 100;
        private const N:int = 1 << LOGN;
        private const BUF_LEN:int = N;
		
		public function Camera(connection:NetConnection, recordId:String = null)
		{

			_connection = connection;

			if(recordId) {
				setRecordId(recordId);
			}

			if (stage && root) init();

            addEventListener(Event.ADDED_TO_STAGE, init);
            addEventListener(Event.REMOVED_FROM_STAGE, clean);
			
		}

		/*
		 *
		 *	Initializer
		 * 
		 */
		private function init(e:Event = null):void
		{

			Camcorder.log('[Camera] init');

			//Create video player
			_video = new Video(_width, _height);
			_video.smoothing = true;
			_video.x = 0;
			_video.y = 0;
			addChild( _video );

			//Webcam
			if( !webcam ) {
				webcam = flash.media.Camera.getCamera();
				webcam.setMode(_webcamWidth, _webcamHeight, _framerate, true);
				webcam.setQuality(_bandwidth, _quality );
				webcam.setKeyFrameInterval( _framerate );
				webcam.setMotionLevel(_motionLevel,_motionTimeout);
				webcam.addEventListener(StatusEvent.STATUS, onWebcamStatus);
				webcam.addEventListener(ActivityEvent.ACTIVITY, onWebcamActivity);

			}
			
			_video.attachCamera( webcam );

			if (webcam.muted) {
				showSettings('privacy');
			}
			
			// Microphone
			if( !microphone ) {
				microphone = flash.media.Microphone.getMicrophone();
				
				if (microphone != null && microphone) {
					
					microphone.rate = _audioRate;
					microphone.gain = 60;
					microphone.setUseEchoSuppression(false);
					microphone.setLoopBack(true);
					microphone.setSilenceLevel(0, 0);

					microphone.addEventListener(StatusEvent.STATUS, onMicrophoneStatus);
					microphone.addEventListener( SampleDataEvent.SAMPLE_DATA, onMicrophoneSampleData );
					
					if (! microphone.muted) {
						dispatchEvent(new CameraEvent(CameraEvent.MICROPHONE_READY));
					}

				}
			}

			onResize();

			initSpectrumAnalyser();

		}

		private function initSpectrumAnalyser():void
		{
			m_fft = new FFT2();
            m_fft.init(LOGN);
            m_tempRe = new Vector.<Number>(N);
            m_tempIm = new Vector.<Number>(N);
            m_mag = new Vector.<Number>(N/2);

            //m_smoothMag = new Vector.<Number>(N/2);
 			var i:uint;
            // Vector with frequencies for each bin number. Used
            // in the graphing code (not in the analysis itself).
            m_freq = new Vector.<Number>(N/2);
            for ( i = 0; i < N/2; i++ )
                m_freq[i] = i*44100/N;
 
            // Hanning analysis window
            m_win = new Vector.<Number>(N);
            for ( i = 0; i < N; i++ )
                m_win[i] = (4.0/N) * 0.5*(1-Math.cos(2*Math.PI*i/N));
 
            // Create a buffer for the input audio
            m_buf = new Vector.<Number>(BUF_LEN);
            for ( i = 0; i < BUF_LEN; i++ )
                m_buf[i] = 0.0;
		}

		private function clean(e:Event = null):void
		{
			Camcorder.log('[Camera] clean');
			stopPublishStream();
			_video.attachCamera( null );
			_isReady = false;

			microphone.setLoopBack(false);
    		microphone = null;

			dispatchEvent(new CameraEvent(CameraEvent.CAMERA_CLEANED));
		}

		/*
		 *
		 *	Public methods
		 * 
		 */
		public function record(recordId:String = null):void
		{

			if(_stream) {
				Camcorder.log('[Camera] Already recording');
				return;
			}

			if(recordId) {
				setRecordId(recordId);
			}
			
			if(!recording) {
				return;
			}

			//Dispatch event
			dispatchEvent(new CameraEvent(CameraEvent.RECORD_START));
			
			//Start the publish stream
			startPublishStream( _isPaused ? true:false );

			//Update recording start time
			recordingStartTime = new Date();
			if(!_isPaused) {
				recording.duration = 0;
			}

			if(_isPaused) {
				_isPaused = false;
			}

		}

		public function pause():void
		{

			if(!_stream) {
				return;
			}
			
			_isPaused = true;

			//Dispatch event
			dispatchEvent(new CameraEvent(CameraEvent.RECORD_PAUSE));
			
			// Stop the publish stream if necessary
			stopPublishStream();

			//Update duration
			var recordingEndTime:Date = new Date();
			recording.duration += (recordingEndTime.time - recordingStartTime.time)/1000;
		}

		public function stop():void
		{
			if(!_stream) {
				return;
			}

			//Dispatch event
			dispatchEvent(new CameraEvent(CameraEvent.RECORD_STOP));
			
			// Stop the publish stream if necessary
			stopPublishStream();
			
			//Update duration
			var recordingEndTime:Date = new Date();
			recording.duration += (recordingEndTime.time - recordingStartTime.time)/1000;
			
		}

		public function getMicrophoneLevel():Number
		{
			return microphone ? (microphone.activityLevel/100):0;
		}

		public function setRecordId(recordId:String)
		{
			recording = {
				id: recordId,
				duration: 0,
				width: 0,
				height: 0
			};
		}

		public function showSettings(key:String):void {

			this._settingsOpened = true;

			Camcorder.log('Opening security panel');

			if (key == null) {
				key = SecurityPanel.CAMERA;
			}
			Security.showSettings(key);

			root.stage.addEventListener(MouseEvent.MOUSE_OVER, onMouseMove);
            
		}

		public function setWebcamSize(width:Number, height:Number):void
		{
			_webcamWidth = width;
			_webcamHeight = height;

			if(webcam)
			{
				webcam.setMode(_webcamWidth, _webcamHeight, _framerate, true);
			}

			onResize();
		}

		public function setSize(width:Number, height:Number):void
		{
			_width = width;
			_height = height;

			onResize();
		}

		public function computeSpectrum(byteArray:ByteArray)
		{
			var i:int;
            var pos:Number = m_writePos;
            for ( i = 0; i < N; i++ )
            {
                m_tempRe[i] = m_win[i]*m_buf[pos];
                pos = (pos+1)%BUF_LEN;
            }
 
            // Zero out the imaginary component
            for ( i = 0; i < N; i++ )
                m_tempIm[i] = 0.0;

            // Do FFT and get magnitude spectrum
            m_fft.run( m_tempRe, m_tempIm );
            for ( i = 0; i < N/2; i++ )
            {
                var re:Number = m_tempRe[i];
                var im:Number = m_tempIm[i];
                m_mag[i] = Math.sqrt(re*re + im*im);
            }
 
            byteArray.position = 0;
 
            // Convert to dB magnitude
            const SCALE:Number = 20/Math.LN10;
            for ( i = 0; i < N/2; i++ )
            {
                // 20 log10(mag) => 20/ln(10) ln(mag)
                // Addition of MIN_VALUE prevents log from returning minus infinity if mag is zero
                m_mag[i] = m_mag[i] != 0 ? (SCALE*Math.log( m_mag[i] + Number.MIN_VALUE )):0;
                byteArray.writeFloat((m_mag[i] != 0 && m_mag[i] > -MIN_DB ? (m_mag[i]+MIN_DB):0)/MIN_DB);
            }

            byteArray.position = 0;
        }

		/*
		 *
		 *	Private methods
		 * 
		 */
		private function startPublishStream( append:Boolean ):void
		{

			// Set up the publish stream
			_stream = new NetStream( _connection );
			_stream.client = {};
			_stream.bufferTime = _bufferTime;
			
			//Event listeners
			_stream.addEventListener( NetStatusEvent.NET_STATUS, onStreamStatus );
			
			//Publish
			_stream.publish( recording.id, append ? "append":"record" );
			
			//Metadata
			var metaData:Object = new Object();
			_stream.send("@setDataFrame", "onMetaData", metaData);
			
			//Attach media
			_stream.attachCamera( webcam );
			_stream.attachAudio( microphone );

			//Add data to recording object
			recording.width = webcam.width;
			recording.height = webcam.height;

		}
		
		private function stopPublishStream():void
		{

			if(!_stream) {
				return;
			}

			//Detach media
			_stream.attachCamera( null );
			_stream.attachAudio( null );
			
			//Stop the recording or delay if the buffer is not empty
			if( _stream.bufferLength == 0 ) {
				doStopPublishStream();
			} else {
				_flushBufferTimer = new Timer( 250 );
				_flushBufferTimer.addEventListener( TimerEvent.TIMER, checkBufferLength );
				_flushBufferTimer.start();
			}
			

		}
		
		private function checkBufferLength( event:Event ):void
		{
			// Do nothing if the buffer is still not empty
			if( _stream.bufferLength > 0 )
				return;
			
			// If the buffer is empty, destroy the timer
			_flushBufferTimer.removeEventListener( TimerEvent.TIMER, checkBufferLength );
			_flushBufferTimer.stop();
			_flushBufferTimer = null;
			
			// Then actually stop the publish stream
			doStopPublishStream();
		}

		private function doStopPublishStream():void
		{
			_stream.close();
		}

		/*
		 *
		 *	Event listeners
		 * 
		 */
		private function onResize(e:Event = null):void
		{
			if(!_video) {
				return;
			}

			var videoRatio:Number = _webcamWidth/_webcamHeight;
			var stageRatio:Number = _width/_height;

			var videoX:Number, videoY:Number, videoWidth:Number, videoHeight:Number;
			if(videoRatio > stageRatio) {
				videoHeight = _height;
				if(videoRatio > 0) {
					videoWidth = Math.ceil(_height * videoRatio);
				} else {
					videoWidth = Math.ceil(_height / videoRatio);
				}
				videoY = 0;
				videoX = -Math.ceil((videoWidth - _width)/2);
			} else {
				videoWidth = _width;
				if(videoRatio > 0) {
					videoHeight = Math.ceil(_width / videoRatio);
				} else {
					videoHeight = Math.ceil(_width * videoRatio);
				}
				videoX = 0;
				//videoY = -Math.ceil((videoHeight - _height)/2);
				videoY = 0;
			}

			_video.width = videoWidth;
			_video.height = videoHeight;
			_video.x = videoX;
			_video.y = videoY;
		}

		private function onMouseMove(e:Event):void {
			
			_settingsOpened = false;

            root.stage.removeEventListener(MouseEvent.MOUSE_OVER, onMouseMove);

			if(!_isReady && _cameraReady) {
				_isReady = true;
				dispatchEvent(new CameraEvent(CameraEvent.CAMERA_READY));
			}

			Camcorder.log('Security panel closed');
        }

		private function onWebcamStatus(e:StatusEvent):void
		{

			Camcorder.log('[Camera] onWebcamStatus: '+e.code);

			switch(e.code) {
				case "Camera.Unmuted":
					_cameraReady = true;
					if(!_isReady && !_settingsOpened) {
						_isReady = true;
						dispatchEvent(new CameraEvent(CameraEvent.CAMERA_READY));
					}
				break;
			}
		}

		private function onWebcamActivity(e:ActivityEvent):void
		{
			if(!_settingsOpened) {
				dispatchEvent(e);
				if(!_isReady) {
					_isReady = true;
					dispatchEvent(new CameraEvent(CameraEvent.CAMERA_READY));
				}
			}
		}

		private function onMicrophoneStatus(e:StatusEvent):void
		{
			Camcorder.log('[Camera] onMicrophoneStatus: '+e.code);
			switch(e.code) {
				case "Microphone.Unmuted":
					dispatchEvent(new CameraEvent(CameraEvent.MICROPHONE_READY));
				break;
			}
		}

		private function onMicrophoneSampleData( e:SampleDataEvent ):void
        {
            // Get number of available input samples
            var len:Number = e.data.length/4;
 
            // Read the input data and stuff it into
            // the circular buffer
            for ( var i:int = 0; i < len; i++ )
            {
                m_buf[m_writePos] = e.data.readFloat();
                m_writePos = (m_writePos+1)%BUF_LEN;
            }
        }

		private function onStreamStatus( e:NetStatusEvent ):void
		{

			Camcorder.log('[Camera] '+e.info.code+': '+e.info.description);

			switch(e.info.code) {
				case "NetStream.Record.Start":
					dispatchEvent(new CameraEvent(CameraEvent.RECORD_STARTED));
				break;
				case "NetStream.Record.Stop":
					dispatchEvent(new CameraEvent(_isPaused ? CameraEvent.RECORD_PAUSED:CameraEvent.RECORD_STOPPED));
				break;
				case "NetStream.Unpublish.Success":
					if(!_isPaused) {
						dispatchEvent(new CameraEvent(CameraEvent.RECORD_READY));
					}
					_stream = null;
				break;
			}
		}

	}
}

package
{
	
	import flash.display.Sprite;

	import flash.events.Event;
	import flash.events.NetStatusEvent;

	import flash.media.Video;
    import flash.media.SoundMixer;
    import flash.media.SoundTransform;

	import flash.net.NetConnection;
	import flash.net.NetStream;

    import flash.external.ExternalInterface;

    import flash.utils.ByteArray;
    
    import com.folklore.events.VCREvent;
	
	public class VCR extends Sprite
	{
		/*
         *
         * Constants
         * 
         */
		private static const DEFAULT_WIDTH : uint = 640;
		private static const DEFAULT_HEIGHT : uint = 480;

		/*
         *
         * Properties
         * 
         */
		private var _video:Video;
		private var _width:Number = DEFAULT_WIDTH;
		private var _height:Number = DEFAULT_HEIGHT;
		private var _videoWidth:Number = DEFAULT_WIDTH;
		private var _videoHeight:Number = DEFAULT_HEIGHT;

		private var _connection:NetConnection;
		private var _stream:NetStream;

		private var _soundTransform:SoundTransform;

		private var _isPaused:Boolean = false;
		private var _isReady:Boolean = false;
		private var _isResetting:Boolean = false;
		private var _isResettingPlayed:Boolean = false;
		private var _isResettingPaused:Boolean = false;

		private var _recordId:String;
		
		public function VCR(connection:NetConnection, recordId:String = null)
		{

			_connection = connection;

			if(recordId) {
				_recordId = recordId;
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

			Camcorder.log('[VCR] init');

			//Create video player
			if(!_video) {
				_video = new Video(_videoWidth, _videoHeight);
				_video.smoothing = true;
				_video.x = 0;
				_video.y = 0;
				addChild( _video );
			}

			onResize();

			if(_recordId) {
				if (_connection.connected) resetVideo();
            	else _connection.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);
			} else {
				_isReady = true;
				dispatchEvent(new VCREvent(VCREvent.READY));
			}

		}

		private function clean(e:Event = null):void
		{
			Camcorder.log('[VCR] clean');
			
			stopPlayStream();

			_isReady = false;

		}

		private function resetVideo():void
		{
			if(_recordId) {
				_isResetting = true;
				_isResettingPlayed = false;
				_isResettingPaused = false;
				_isPaused = true;

				startPlayStream();

				_stream.play( _recordId );
				_stream.pause();
				_stream.seek(0);
			}
		}

		/*
		 *
		 *	Public methods
		 * 
		 */

		public function play(recordId:String = null):void
		{
			if(recordId) {
				_recordId = recordId;
			}

			dispatchEvent(new VCREvent(VCREvent.PLAY));

			if(!_stream) {
				startPlayStream();
			}

			if(_isPaused) {
				_stream.resume();
			} else {
				_stream.play( _recordId );
			}

			if(_isPaused) {
				_isPaused = false;
			}
		}

		public function seek( time:Number ):void
		{
			if( !_stream ) {
				return;
			}
			
			_stream.seek( time );
		}

		public function pause():void
		{
			if( !_stream ) {
				return;
			}

			dispatchEvent(new VCREvent(VCREvent.PAUSE));
			
			_isPaused = true;

			_stream.pause();

		}

		public function stop():void
		{
			if( !_stream ) {
				return;
			}

			dispatchEvent(new VCREvent(VCREvent.STOP));

			stopPlayStream();
			resetVideo();
		}

		public function reset():void
		{
			stopPlayStream();
			resetVideo();
		}

		public function setVolume(volume:Number):void
		{
			_soundTransform = new SoundTransform();
			_soundTransform.volume = volume;

			if(_stream) {
				_stream.soundTransform = _soundTransform;
			}
		}

		public function setVideoSize(width:Number, height:Number):void
		{
			_videoWidth = width;
			_videoHeight = height;
		}

		public function setSize(width:Number, height:Number):void
		{
			_width = width;
			_height = height;

			onResize();
		}

		public function getCurrentTime():Number
		{
			if(_stream) {
				return _stream.time;
			}
			return 0.0;
		}

		public function computeSpectrum(byteArray:ByteArray):void
		{
			SoundMixer.computeSpectrum(byteArray,true,0);
		}

		/*
		 *
		 *	Private methods
		 * 
		 */
		private function startPlayStream():void
		{

			// Set up the play stream
			_stream = new NetStream( _connection );
			_stream.client = {};
			_stream.bufferTime = 2;

			if(_soundTransform) {
				_stream.soundTransform = _soundTransform;
			}
			
			//Event listeners
			_stream.addEventListener( NetStatusEvent.NET_STATUS, onStreamStatus );
			
			// Add an event listener to dispatch a notification and go back to the webcam preview when the playing is finished
			_stream.client.onPlayStatus = onPlayStatus;
			
			// Replace the webcam preview by the stream playback
			_video.attachNetStream( _stream );
			
		}
		
		/** Stop the play stream */
		private function stopPlayStream():void
		{
			if(_stream) {
				_stream.close();
				_stream = null;
			}
			_video.attachNetStream( null );
			dispatchEvent(new VCREvent(VCREvent.STOPPED));

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

			var videoRatio:Number = _videoWidth/_videoHeight;
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
		
		private function onPlayStatus(info:Object):void
		{

			switch(info.code) {
				case "NetStream.Play.Complete":
					stopPlayStream();
					dispatchEvent(new VCREvent(VCREvent.ENDED));
				break;
			}
			
		}

		private function onConnectionStatus( e:NetStatusEvent ):void
		{
			switch(e.info.code) {

                case "NetConnection.Connect.Success":
                    resetVideo();
                    _connection.removeEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);
                break;

            }
			
		}

		private function onStreamStatus( e:NetStatusEvent ):void
		{

			Camcorder.log('[VCR] '+e.info.code+': '+e.info.description);

			if(_isResetting) {
				if(e.info.code == "NetStream.Play.Start") {
					_isResettingPlayed = true;
				} else if(e.info.code == "NetStream.Pause.Notify") {
					_isResettingPaused = true;
				}
				if(_isResettingPlayed && _isResettingPaused) {
					_isResetting = false;
					if(!_isReady) {
						_isReady = true;
						dispatchEvent(new VCREvent(VCREvent.READY));
					}
				}
				return;
			}

			switch(e.info.code) {
				case "NetStream.Play.Start":
					dispatchEvent(new VCREvent(VCREvent.PLAYED));
				break;
				case "NetStream.Play.Stop":
					
				break;
				case "NetStream.Pause.Notify":
					dispatchEvent(new VCREvent(VCREvent.PAUSED));
				break;
			}
		}

	}
}
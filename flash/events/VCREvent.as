package events
{
    import flash.events.Event;

    public class VCREvent extends Event
    {

        public static const READY:String = "Playback.ready";
        public static const PLAY:String = "Playback.play";
        public static const PLAYED:String = "Playback.played";
        public static const STOP:String = "Playback.stop";
        public static const STOPPED:String = "Playback.stopped";
        public static const PAUSE:String = "Playback.pause";
        public static const PAUSED:String = "Playback.paused";
        public static const ENDED:String = "Playback.ended";

        public function VCREvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
        {
            super(type, bubbles, cancelable);
        }
    }

}

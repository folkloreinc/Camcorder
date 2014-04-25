package
{
    import flash.events.Event;

    public class CamcorderEvent extends Event
    {
        public static const CAMCORDER_READY:String = "Camcorder.ready";

        public function CamcorderEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
        {
            super(type, bubbles, cancelable);
        }
    }

}
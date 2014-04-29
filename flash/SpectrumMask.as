package
{
    import flash.display.Sprite;

	public class SpectrumMask extends Sprite
	{

        public var radius:Number = 150;
        public var noise:Number = 200;
        public var points:Number = 90;

        public var intensity:Number = 0;
		
		public function SpectrumMask()
		{
            
		}

        public function draw():void
        {

            var currentNoise:Number = intensity * noise;
            if(currentNoise > noise) {
                currentNoise = noise;
            }
            
            graphics.clear();
            graphics.lineStyle(1, 0x000000); 
            graphics.beginFill(0x000000); 

            var numPoints:Number = (points * (1-(currentNoise/noise)));
            if(numPoints < 36) {
                numPoints = 36;
            }
            /*var numPoints:Number = Math.random() * points;
            if(numPoints < 36) {
                numPoints = 36;
            }*/
            var steps:Number = (360/numPoints);
            var centerX:Number = Math.round(stage.stageWidth/2);
            var centerY:Number = Math.round(stage.stageHeight/2);

            var startX:Number = 0;
            var startY:Number = 0;

            for(var i:uint = 0; i < 360; i += steps) {

                var angle:Number = i * Math.PI / 180;

                var random:Number;
                if(i < 45 || (i > 135 && i < 225) || (i > 315 && i <= 360)) {
                    random = Math.random() * intensity * noise * 2;
                } else {
                    random = Math.random() * intensity * noise;
                }

                /*if(currentNoise > 100 && Math.random() < 0.3) {
                    random = -(Math.random() * noise);
                }*/
                //var randomX:Number = random != 0 ? (random * (width/height)):random;
                var randomX:Number = random;

                var x:Number = Math.round(centerX + (radius + randomX) * Math.cos(angle));
                var y:Number = Math.round(centerY + (radius + random) * Math.sin(angle));

                if(i === 0) {
                    startX = x;
                    startY = y;
                    graphics.moveTo(x,y);
                } else {
                    graphics.lineTo(x,y);
                }
            }

            graphics.lineTo(startX,startY);

            graphics.endFill(); 
            
        }

	}
}
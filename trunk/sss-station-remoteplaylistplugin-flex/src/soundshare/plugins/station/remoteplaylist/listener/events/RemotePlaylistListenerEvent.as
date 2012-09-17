package soundshare.plugins.station.remoteplaylist.listener.events
{
	import flash.events.Event;
	
	import flashsocket.client.managers.events.events.ClientEventDispatcherEvent;
	
	public class RemotePlaylistListenerEvent extends ClientEventDispatcherEvent
	{
		public static const SONG_CHANGED:String = "SONG_CHANGED";
		public static const STOP_PLAYING:String = "STOP_PLAYING";
		
		public static const CONNECTION_CLOSED:String = "CONNECTION_CLOSED";
		
		public static const LOAD_AUDIO_DATA_ERROR:String = "loadAudioDataError";
		
		public var index:int;
		
		public var path:String;
		
		public var error:String;
		public var code:int;
		
		public function RemotePlaylistListenerEvent(type:String, data:Object = null, body:Object=null, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, data, body, bubbles, cancelable);
		}
		
		override public function clone():Event
		{
			var event:RemotePlaylistListenerEvent = new RemotePlaylistListenerEvent(type, data, body, bubbles, cancelable);
			event.index = index;
			
			return event;
		}
	}
}
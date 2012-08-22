package soundshare.plugins.station.remoteplaylist.broadcaster.events
{
	import socket.client.managers.events.events.ClientEventDispatcherEvent;
	
	public class RemotePlaylistBroadcasterEvent extends ClientEventDispatcherEvent
	{
		public static const PREPARE_COMPLETE:String = "prepareComplete";
		public static const PREPARE_ERROR:String = "prepareError";
		
		public static const LOAD_AUDIO_DATA_ERROR:String = "loadAudioDataError";
		
		public function RemotePlaylistBroadcasterEvent(type:String, data:Object=null, body:Object=null, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, data, body, bubbles, cancelable);
		}
	}
}
package soundshare.plugins.station.remoteplaylist.managers.listener.events
{
	import flash.events.Event;
	
	public class RemotePlaylistPluginListenerManagerEvent extends Event
	{
		public static const SAVE_PLAYLIST_COMPLETE:String = "savePlaylistComplete";
		public static const SAVE_PLAYLIST_ERROR:String = "savePlaylistError";
		
		public static const LOAD_PLAYLIST_COMPLETE:String = "loadPlaylistComplete";
		public static const LOAD_PLAYLIST_ERROR:String = "loadPlaylistError";
		
		public var plylist:Array;
		
		public function RemotePlaylistPluginListenerManagerEvent(type:String, plylist:Array=null, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			
			this.plylist = plylist;
		}
	}
}
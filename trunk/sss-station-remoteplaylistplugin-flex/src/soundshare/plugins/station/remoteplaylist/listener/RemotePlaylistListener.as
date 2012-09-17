package soundshare.plugins.station.remoteplaylist.listener
{
	import flashsocket.message.FlashSocketMessage;
	
	import soundshare.station.data.StationContext;
	import soundshare.plugins.station.remoteplaylist.builders.messages.listener.RemotePlaylistListenerMessageBuilder;
	import soundshare.plugins.station.remoteplaylist.listener.events.RemotePlaylistListenerEvent;
	import soundshare.sdk.managers.events.SecureClientEventDispatcher;
	import soundshare.sdk.sound.player.broadcast.BroadcastPlayer;
	
	public class RemotePlaylistListener extends SecureClientEventDispatcher
	{
		public static const NONE_STATE:String = "";
		
		public static const PREPARE_STATE:String = "PREPARE_STATE";
		public static const PREPARE_COMPLETE_STATE:String = "PREPARE_COMPLETE_STATE";
		
		public static const CREATE_BROADCAST_STATE:String = "CREATE_BROADCAST_STATE";
		public static const CREATE_BROADCAST_COMPLETE_STATE:String = "CREATE_BROADCAST_COMPLETE_STATE";
		
		private var state:String = NONE_STATE;
		
		public var context:StationContext;
		
		private var _playlist:Array;
		private var _playOrder:int = 0;
		private var _playing:Boolean = false;
		
		private var broadcastPlayer:BroadcastPlayer;
		private var songIndex:int = 0;
		
		private var messageBuilder:RemotePlaylistListenerMessageBuilder;
		
		public function RemotePlaylistListener()
		{
			super();
			
			broadcastPlayer = new BroadcastPlayer();
			broadcastPlayer.minSamples = 5;
			
			messageBuilder = new RemotePlaylistListenerMessageBuilder(this);
			
			addAction("BROADCAST_AUDIO_DATA", processAudioData);
			addAction("LOAD_AUDIO_DATA_ERROR", loadAudioDataError);
			addAction("CHANGE_SONG", changeSong);
			addAction("STOP_PLAYING", stopPlaying);
			addAction("CLOSE_CONNECTION", closeConnection);
		}
		
		override protected function $dispatchSocketEvent(message:FlashSocketMessage):void
		{
			var event:Object = getActionData(message);
			
			if (event)
				dispatchEvent(new RemotePlaylistListenerEvent(event.type, event.data));
		}
		
		// ************************************************************************************************************
		// 												
		// ************************************************************************************************************
		
		private function processAudioData(message:FlashSocketMessage):void
		{
			/*var t:int = getTimer();
			
			trace("1.-RemotePlaylistListener[processAudioData]-", message.$body.length);
			
			message.$body.uncompress();
			
			trace("2.-RemotePlaylistListener[processAudioData]-", message.$body.length, getTimer() - t);*/
			
			broadcastPlayer.process(message.$body);
		}
		
		// ************************************************************************************************************
		// 												COMMANDS
		// ************************************************************************************************************
		
		public function play(index:int = 0, sendPlayOrder:Boolean = false):void
		{
			trace("RemotePlaylistListener[playSong]", index, sendPlayOrder);
			
			_playing = true;
			songIndex = index;
			
			var message:FlashSocketMessage = messageBuilder.buildPlaySongMessage(index, sendPlayOrder ? playOrder : -1);
			send(message);
		}
		
		public function stop():void
		{
			trace("-RemotePlaylistListener[stopSong]-");
			
			var message:FlashSocketMessage = messageBuilder.buildStopSongMessage();
			send(message);
		}
		
		public function previous():void
		{
			trace("-RemotePlaylistListener[previousSong]-");
			
			var message:FlashSocketMessage = messageBuilder.buildPreviousSongMessage();
			send(message);
		}
		
		public function next():void
		{
			trace("-RemotePlaylistListener[nextSong]-");
			
			var message:FlashSocketMessage = messageBuilder.buildNextSongMessage();
			send(message);
		}
		
		public function changePlayOrder(order:int = 0):void
		{
			trace("-RemotePlaylistListener[changePlayOrder]-", _playOrder);
			
			_playOrder = order;
			
			var message:FlashSocketMessage = messageBuilder.buildChangePlayOrder(order);
			send(message);
		}
		
		// ************************************************************************************************************
		// 												ACTIONS
		// ************************************************************************************************************
		
		private function stopPlaying(message:FlashSocketMessage):void
		{
			trace("-RemotePlaylistListener[stopPlaying]-");
			
			_playing = false;
			dispatchEvent(new RemotePlaylistListenerEvent(RemotePlaylistListenerEvent.STOP_PLAYING));
		}
		
		private function closeConnection(message:FlashSocketMessage):void
		{
			trace("-RemotePlaylistListener[closeConnection]-");
			
			_playing = false;
			dispatchEvent(new RemotePlaylistListenerEvent(RemotePlaylistListenerEvent.CONNECTION_CLOSED));
		}
		
		private function changeSong(message:FlashSocketMessage):void
		{
			var body:Object = message.getJSONBody();
			
			trace("-RemotePlaylistListener[changeSong]-", body.index);
			
			if (body.hasOwnProperty("index"))
			{
				var e:RemotePlaylistListenerEvent = new RemotePlaylistListenerEvent(RemotePlaylistListenerEvent.SONG_CHANGED);
				e.index = int(body.index);
				
				songIndex = int(body.index);
				dispatchEvent(e);
			}
		}
		
		private function loadAudioDataError(message:FlashSocketMessage):void
		{
			_playing = false;
			
			var e:RemotePlaylistListenerEvent = new RemotePlaylistListenerEvent(RemotePlaylistListenerEvent.LOAD_AUDIO_DATA_ERROR);
			e.error = "Unable to load audio file.";
			e.code = 100;
			e.path = playlist[songIndex].path;
			
			dispatchEvent(e);
		}
		
		// ************************************************************************************************************
		// ************************************************************************************************************
		
		public function get playOrder():int
		{
			return _playOrder;
		}
		
		public function get playing():Boolean
		{
			return _playing;
		}
		
		public function set volume(value:Number):void
		{
			broadcastPlayer.volume = value;
		}
		
		public function get volume():Number
		{
			return broadcastPlayer.volume;
		}
		
		public function get trackIndex():int
		{
			return songIndex;
		}
		
		public function set playlist(value:Array):void
		{
			_playlist = value;
		}
		
		public function get playlist():Array
		{
			return _playlist;
		}
	}
}
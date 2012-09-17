package soundshare.plugins.station.remoteplaylist.managers.broadcaster
{
	import flash.events.EventDispatcher;
	
	import flashsocket.client.events.FlashSocketClientEvent;
	
	import soundshare.station.data.StationContext;
	import soundshare.station.data.channels.RemoteChannelContext;
	import soundshare.plugins.station.remoteplaylist.broadcaster.RemotePlaylistBroadcaster;
	import soundshare.sdk.controllers.connection.client.ClientConnection;
	import soundshare.sdk.controllers.connection.client.events.ClientConnectionEvent;
	import soundshare.sdk.data.BroadcastServerContext;
	import soundshare.sdk.data.SoundShareContext;
	import soundshare.sdk.data.plugin.PluginData;
	import soundshare.sdk.data.servers.ServerData;
	import soundshare.sdk.db.mongo.playlists.loader.PlaylistsLoader;
	import soundshare.sdk.db.mongo.playlists.loader.events.PlaylistsLoaderEvent;
	import soundshare.sdk.managers.connections.server.ConnectionsManager;
	import soundshare.sdk.managers.connections.server.events.ConnectionsManagerEvent;
	import soundshare.sdk.plugins.manager.IPluginManager;
	import soundshare.sdk.plugins.manager.events.PluginManagerEvent;
	
	public class RemotePlaylistPluginBroadcasterManager extends EventDispatcher implements IPluginManager
	{
		private var stationContext:StationContext;
		private var _pluginData:PluginData;
		
		private var playlistsLoader:PlaylistsLoader;
		
		private var connectionsManager:ConnectionsManager;
		private var connection:ClientConnection;
		
		private var remoteChannelContext:RemoteChannelContext;
		
		private var serverData:ServerData = new ServerData();
		
		public static const NONE_STATE:String = "";
		public static const PREPARE_STATE:String = "PREPARE_STATE";
		public static const PREPARE_COMPLETE_STATE:String = "PREPARE_COMPLETE_STATE";
		
		private var state:String = NONE_STATE;
		
		private var broadcaster:RemotePlaylistBroadcaster;
		private var bsContext:BroadcastServerContext;
		
		private var playlistId:String;
		
		public function RemotePlaylistPluginBroadcasterManager(context:SoundShareContext)
		{
			super();
			
			this.context = context;
			
			remoteChannelContext = new RemoteChannelContext();
			remoteChannelContext.pluginManager = this;
			
			broadcaster = new RemotePlaylistBroadcaster();
		}
		
		public function prepare(data:Object = null):void
		{
			if (state == NONE_STATE)
			{
				state == PREPARE_STATE;
				
				playlistId = data.playlistId;
				serverData.readObject(data.serverData);
				
				broadcaster.receiverRoute = data.playerRoute as Array;
				
				remoteChannelContext.stationId = stationContext.stationData._id;
				
				trace("-RemotePlaylistPluginBroadcasterManager[prepare]-", serverData.address, serverData.port, data.playlistId);
				
				connection = context.connectionsController.createConnection("CONNECTION-" + broadcaster.id);
				connection.addUnit(broadcaster);
				
				bsContext = context.broadcastServerContextBuilder.build();
				bsContext.connection = connection;
				
				connection.addEventListener(FlashSocketClientEvent.DISCONNECTED, onInitializationDisconnect);
				connection.addEventListener(FlashSocketClientEvent.ERROR, onInitializationError);
				connection.addEventListener(ClientConnectionEvent.INITIALIZATION_COMPLETE, onInitializationComplete);
				connection.address = serverData.address;
				connection.port = serverData.port;
				connection.connect();
			}
			else
			{
				destroy();
				dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Unable to create plugin broadcast.", 200));
			}
		}
		
		private function onInitializationDisconnect(e:FlashSocketClientEvent):void
		{
			trace("--RemotePlaylistPluginBroadcasterManager[onInitializationDisconnect]-");
			
			connection.removeEventListener(FlashSocketClientEvent.DISCONNECTED, onInitializationDisconnect);
			connection.removeEventListener(FlashSocketClientEvent.ERROR, onInitializationError);
			connection.removeEventListener(ClientConnectionEvent.INITIALIZATION_COMPLETE, onInitializationComplete);
			
			context.connectionsController.destroyConnection(connection);
			
			connection.removeUnit(broadcaster.id);
			connection = null;
			
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Unable to create connection with the server!", 201));
			destroy();
		}
		
		private function onInitializationError(e:FlashSocketClientEvent):void
		{
			trace("--RemotePlaylistPluginBroadcasterManager[onInitializationError]-")
			
			connection.removeEventListener(FlashSocketClientEvent.DISCONNECTED, onInitializationDisconnect);
			connection.removeEventListener(FlashSocketClientEvent.ERROR, onInitializationError);
			connection.removeEventListener(ClientConnectionEvent.INITIALIZATION_COMPLETE, onInitializationComplete);
			
			context.connectionsController.destroyConnection(connection);
			
			connection.removeUnit(broadcaster.id);
			connection = null;
			
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Unable to create connection with the server!", 202));
			destroy();
		}
		
		private function onInitializationComplete(e:ClientConnectionEvent):void
		{
			trace("--RemotePlaylistPluginBroadcasterManager[onInitializationComplete]-", broadcaster.route, e.data);
			
			connection.removeEventListener(FlashSocketClientEvent.DISCONNECTED, onInitializationDisconnect);
			connection.removeEventListener(FlashSocketClientEvent.ERROR, onInitializationError);
			connection.removeEventListener(ClientConnectionEvent.INITIALIZATION_COMPLETE, onInitializationComplete);
			
			connection.addEventListener(FlashSocketClientEvent.DISCONNECTED, onDisconnect);
			
			// broadcastContext.connection = connection;
			
			connectionsManager = bsContext.connectionsManagerBuilder.build();
			connectionsManager.addSocketEventListener(ConnectionsManagerEvent.WATCH_FOR_DISCONNECT_COMPLETE, onWatchForDisconnectComplete);
			connectionsManager.addSocketEventListener(ConnectionsManagerEvent.WATCH_FOR_DISCONNECT_ERROR, onWatchForDisconnectError);
			connectionsManager.watchForDisconnect([broadcaster.receiverRoute[1]]);
		}
		
		private function onWatchForDisconnectComplete(e:ConnectionsManagerEvent):void
		{
			connectionsManager.removeSocketEventListener(ConnectionsManagerEvent.WATCH_FOR_DISCONNECT_COMPLETE, onWatchForDisconnectComplete);
			connectionsManager.removeSocketEventListener(ConnectionsManagerEvent.WATCH_FOR_DISCONNECT_ERROR, onWatchForDisconnectError);
			
			var onlineReport:Object = e.data.report;
			
			trace("--RemotePlaylistPluginBroadcasterManager[onWatchForDisconnectComplete]-");
			
			if (onlineReport && onlineReport[broadcaster.receiverRoute[1]])
			{
				connectionsManager.addSocketEventListener(ConnectionsManagerEvent.DISCONNECT_DETECTED, onListenerDisconnect);
				loadPlaylists();
			}
			else
			{
				dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Connection is lost.", 203));
				destroy();
			}
		}
		
		private function onWatchForDisconnectError(e:ConnectionsManagerEvent):void
		{
			trace("--RemotePlaylistPluginBroadcasterManager[onWatchForDisconnectError]-");
			
			bsContext.connectionsManagerBuilder.destroy(connectionsManager);
			connectionsManager = null;
			
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Unable to preapare broadcast.", 204));
			destroy();
		}
		
		// ******************************************************************************************************************
		
		private function loadPlaylists():void
		{
			playlistsLoader = context.playlistsLoaderBuilder.build();
			playlistsLoader.addEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistsComplete);
			playlistsLoader.addEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistsError);
			playlistsLoader.load([playlistId]);
		}
		
		private function onPlaylistsComplete(e:PlaylistsLoaderEvent):void
		{
			trace("PlaylistsChannel[onPlaylistsComplete]:", e.playlists.length);
			
			playlistsLoader.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistsComplete);
			playlistsLoader.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistsError);
			
			context.playlistsLoaderBuilder.destroy(playlistsLoader);
			playlistsLoader = null;
			
			var playlist:Array = new Array();
			
			while (e.playlists.length > 0)
				playlist = playlist.concat(e.playlists.shift() as Array);
			
			trace("PlaylistsChannel[onPlaylistsComplete]:", playlist);
			
			broadcaster.playlist = playlist;
			broadcaster.prepareMessage();
			
			state = PREPARE_COMPLETE_STATE;
			
			addChannelContext();
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.READY, {broadcasterRoute: broadcaster.route}));
		}
		
		private function onPlaylistsError(e:PlaylistsLoaderEvent):void
		{
			playlistsLoader.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistsComplete);
			playlistsLoader.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistsError);
			
			context.playlistsLoaderBuilder.destroy(playlistsLoader);
			playlistsLoader = null;
			
			trace("-RemotePlaylistPluginBroadcasterManager[onPlaylistsError]- Error loading playlists!");
			
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Unable to load playlist.", 205));
			destroy();
		}
		
		private function onDisconnect(e:FlashSocketClientEvent):void
		{
			trace("--RemotePlaylistPluginBroadcasterManager[onDisconnect]-");
			
			if (state == PREPARE_STATE)
				dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Connection is lost.", 206));
			
			destroy();
		}
		
		private function onListenerDisconnect(e:ConnectionsManagerEvent):void
		{
			trace("--RemotePlaylistPluginBroadcasterManager[onListenerDisconnect]-");
			
			destroy();
		}
		
		public function destroy(data:Object = null):void
		{
			trace("--RemotePlaylistPluginBroadcasterManager[destroy]-");
			
			broadcaster.close();
			executeDestroy();
		}
		
		private function executeDestroy():void
		{
			reset();
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.DESTROY));
		}
		
		// ******************************************************************************************************************
		
		public function reset():void
		{
			trace("-RemotePlaylistPluginBroadcasterManager[reset]", state);
			
			if (state == NONE_STATE)
				return ;
			
			state = NONE_STATE;
			broadcaster.reset();
			
			if (playlistsLoader)
			{
				context.playlistsLoaderBuilder.destroy(playlistsLoader);
				playlistsLoader = null;
			}
			
			if (connectionsManager)
			{
				bsContext.connectionsManagerBuilder.destroy(connectionsManager);
				connectionsManager = null;
			}
			
			if (bsContext)
			{
				connection.removeEventListener(FlashSocketClientEvent.DISCONNECTED, onInitializationDisconnect);
				connection.removeEventListener(FlashSocketClientEvent.ERROR, onInitializationError);
				connection.removeEventListener(ClientConnectionEvent.INITIALIZATION_COMPLETE, onInitializationComplete);
				connection.removeEventListener(FlashSocketClientEvent.DISCONNECTED, onDisconnect);
				
				context.connectionsController.destroyConnection(connection);
				
				connection.removeUnit(broadcaster.id);
				connection = null;
				
				context.broadcastServerContextBuilder.destroy(bsContext);
				bsContext = null;
			}
			
			removeChannelContext();
		}
		
		private function addChannelContext():void
		{
			var index:int = stationContext.channels.getItemIndex(remoteChannelContext);
			
			if (index == -1)
				stationContext.channels.addItem(remoteChannelContext);
		}
		
		private function removeChannelContext():void
		{
			var index:int = stationContext.channels.getItemIndex(remoteChannelContext);
			
			if (index != -1)
				stationContext.channels.removeItemAt(index);
			
			remoteChannelContext.clearObject();
		}
		
		public function match(data:Object):Object
		{
			return null;
		}
		
		public function set context(value:SoundShareContext):void
		{
			stationContext = value as StationContext;
		}
		
		public function get context():SoundShareContext
		{
			return stationContext;
		}
		
		public function set pluginData(value:PluginData):void
		{
			_pluginData = value;
		}
		
		public function get pluginData():PluginData
		{
			return _pluginData;
		}
	}
}
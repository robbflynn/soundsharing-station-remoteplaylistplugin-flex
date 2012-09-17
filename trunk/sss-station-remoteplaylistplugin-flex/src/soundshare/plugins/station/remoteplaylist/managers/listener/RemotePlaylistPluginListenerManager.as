package soundshare.plugins.station.remoteplaylist.managers.listener
{
	import flash.events.EventDispatcher;
	
	import flashsocket.client.events.FlashSocketClientEvent;
	
	import soundshare.station.data.StationContext;
	import soundshare.station.utils.debuger.Debuger;
	import soundshare.plugins.station.remoteplaylist.listener.RemotePlaylistListener;
	import soundshare.plugins.station.remoteplaylist.listener.events.RemotePlaylistListenerEvent;
	import soundshare.plugins.station.remoteplaylist.managers.listener.events.RemotePlaylistPluginListenerManagerEvent;
	import soundshare.sdk.controllers.connection.client.ClientConnection;
	import soundshare.sdk.controllers.connection.client.events.ClientConnectionEvent;
	import soundshare.sdk.data.BroadcastServerContext;
	import soundshare.sdk.data.SoundShareContext;
	import soundshare.sdk.data.platlists.PlaylistContext;
	import soundshare.sdk.data.plugin.PluginData;
	import soundshare.sdk.data.servers.ServerData;
	import soundshare.sdk.db.mongo.base.events.MongoDBRestEvent;
	import soundshare.sdk.db.mongo.playlists.PlaylistsDataManager;
	import soundshare.sdk.db.mongo.playlists.loader.PlaylistsLoader;
	import soundshare.sdk.db.mongo.playlists.loader.events.PlaylistsLoaderEvent;
	import soundshare.sdk.managers.connections.server.ConnectionsManager;
	import soundshare.sdk.managers.connections.server.events.ConnectionsManagerEvent;
	import soundshare.sdk.managers.plugins.PluginsManager;
	import soundshare.sdk.managers.plugins.events.PluginsManagerEvent;
	import soundshare.sdk.managers.servers.ServersManager;
	import soundshare.sdk.managers.servers.events.ServersManagerEvent;
	import soundshare.sdk.managers.stations.StationsManager;
	import soundshare.sdk.managers.stations.events.StationsManagerEvent;
	import soundshare.sdk.plugins.manager.IPluginManager;
	import soundshare.sdk.plugins.manager.events.PluginManagerEvent;
	import soundshare.sdk.sound.player.local.LocalSoundPlayer;
	
	public class RemotePlaylistPluginListenerManager extends EventDispatcher implements IPluginManager
	{
		public static const NONE_STATE:String = "";
		
		public static const PREPARE_STATE:String = "PREPARE_STATE";
		public static const PREPARE_COMPLETE_STATE:String = "PREPARE_COMPLETE_STATE";
		
		public static const CREATE_BROADCAST_STATE:String = "CREATE_BROADCAST_STATE";
		public static const CREATE_BROADCAST_COMPLETE_STATE:String = "CREATE_BROADCAST_COMPLETE_STATE";
		
		private var _pluginData:PluginData;
		
		private var state:String = NONE_STATE;
		
		private var stationContext:StationContext;
		
		private var playlistsLoader:PlaylistsLoader;
		private var playlistLoader:PlaylistsLoader;
		
		private var _playlistContext:PlaylistContext;
		
		private var stationsManager:StationsManager;
		private var serversManager:ServersManager;
		
		private var existPluginsManager:PluginsManager;
		private var requestPluginsManager:PluginsManager;
		
		private var connection:ClientConnection;
		
		private var targetRoutingMap:Object;
		
		private var _playlist:Array;
		private var _local:Boolean = false;
		private var _ready:Boolean = false;
		
		private var localSoundPlayer:LocalSoundPlayer;
		private var remotePlaylistListener:RemotePlaylistListener;
		
		private var serverData:ServerData = new ServerData();
		private var soundIndex:int = 0;
		
		private var bsContext:BroadcastServerContext;
		private var connectionsManager:ConnectionsManager;
		
		public function RemotePlaylistPluginListenerManager()
		{
			super();
			
			localSoundPlayer = new LocalSoundPlayer();
			
			remotePlaylistListener = new RemotePlaylistListener();
			remotePlaylistListener.addEventListener(RemotePlaylistListenerEvent.SONG_CHANGED, onSongChanged);
			remotePlaylistListener.addEventListener(RemotePlaylistListenerEvent.STOP_PLAYING, onStopPlaying);
			remotePlaylistListener.addEventListener(RemotePlaylistListenerEvent.CONNECTION_CLOSED, onConnectionClosed);
			remotePlaylistListener.addEventListener(RemotePlaylistListenerEvent.LOAD_AUDIO_DATA_ERROR, onLoadAudioDataError);
			
		}
		
		private function onSongChanged(e:RemotePlaylistListenerEvent):void
		{
			dispatchEvent(e.clone());
		}
		
		private function onStopPlaying(e:RemotePlaylistListenerEvent):void
		{
			dispatchEvent(e.clone());	
		}
		
		private function onConnectionClosed(e:RemotePlaylistListenerEvent):void
		{
			trace("-RemotePlaylistPluginListenerManager[onConnectionClosed]-");
			
			reset(false);
			dispatchEvent(e.clone());
		}
		
		private function onLoadAudioDataError(e:RemotePlaylistListenerEvent):void
		{
			trace("-RemotePlaylistPluginListenerManager[onLoadAudioDataError]-");
			
			Debuger.error(e.error);
			Debuger.error(e.path);
			
			Debuger.show();
			
			dispatchEvent(e.clone());
		}
		
		public function prepare(data:Object = null):void
		{
			trace("1.-RemotePlaylistPluginListenerManager[prepare]-", state);
			
			if (state == NONE_STATE)
			{
				this.state = PREPARE_STATE;
				this._playlistContext = stationContext.selectedPlaylist;
				this._ready = false;
				
				/*_local = false;
				
				stationsManager = context.stationsManagersBuilder.build();
				stationsManager.addSocketEventListener(StationsManagerEvent.START_WATCH_COMPLETE, onStartWatchComplete);
				stationsManager.addSocketEventListener(StationsManagerEvent.START_WATCH_ERROR, onStartWatchError);
				stationsManager.startWatchStations([playlistContext.stationId]);*/
				
				if (stationContext.stationData._id != playlistContext.stationId) // TODO: Fast hack to test plugin
				{
					_local = false;
				
					stationsManager = context.stationsManagersBuilder.build();
					stationsManager.addSocketEventListener(StationsManagerEvent.START_WATCH_COMPLETE, onStartWatchComplete);
					stationsManager.addSocketEventListener(StationsManagerEvent.START_WATCH_ERROR, onStartWatchError);
					stationsManager.startWatchStations([playlistContext.stationId]);
				}
				else
				{
					_local = true;
					loadPlaylists();
				}
				
				trace("2.-RemotePlaylistPluginListenerManager[prepare]-", playlistContext.stationId);
			}
			else
				dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Station is not ready!", 100));
		}
		
		private function onStartWatchComplete(e:StationsManagerEvent):void
		{
			stationsManager.removeSocketEventListener(StationsManagerEvent.START_WATCH_COMPLETE, onStartWatchComplete);
			stationsManager.removeSocketEventListener(StationsManagerEvent.START_WATCH_ERROR, onStartWatchError);
			
			var stationsReport:Object = e.data.stationsReport;
			
			trace("1.--RemotePlaylistPluginListenerManager[onStartWatchComplete]-", stationsReport, stationsReport ? stationsReport[playlistContext.stationId] : "SHITT");
			
			if (stationsReport && stationsReport[playlistContext.stationId])
			{
				trace("2.--RemotePlaylistPluginListenerManager[onStartWatchComplete]-", stationsReport);
				targetRoutingMap = stationsReport[playlistContext.stationId].routingMap;
				dispatchEvent(new StationsManagerEvent(StationsManagerEvent.STATION_UP_DETECTED, e.data));
			}
			else
			{
				targetRoutingMap = null;
				dispatchEvent(new StationsManagerEvent(StationsManagerEvent.STATION_DOWN_DETECTED, e.data));
			}
			
			stationsManager.addSocketEventListener(StationsManagerEvent.STATION_UP_DETECTED, onStationUpDetected);
			stationsManager.addSocketEventListener(StationsManagerEvent.STATION_DOWN_DETECTED, onStationDownDetected);
			
			loadPlaylists();
		}
		
		private function onStartWatchError(e:StationsManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onStartWatchError]-");
			
			context.stationsManagersBuilder.destroy(stationsManager);
			stationsManager = null;
			
			reset();
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Station error please try again.", 101));
		}
		
		private function onStationUpDetected(e:StationsManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onLoginDetected]-");
			
			targetRoutingMap = e.data.routingMap;
			dispatchEvent(new StationsManagerEvent(StationsManagerEvent.STATION_UP_DETECTED, e.data));
		}
		
		private function onStationDownDetected(e:StationsManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onLogoutDetected]-");
			
			targetRoutingMap = null;
			
			if (state == CREATE_BROADCAST_STATE)
			{
				dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Unable to play sound because station connection is lost.", 102));
				reset(false);
			}
			else
			if (state == CREATE_BROADCAST_COMPLETE_STATE)
				reset(false);
			
			dispatchEvent(new StationsManagerEvent(StationsManagerEvent.STATION_DOWN_DETECTED, e.data));
		}
		
		private function loadPlaylists():void
		{
			trace("--RemotePlaylistPluginListenerManager[loadPlaylists]-");
			
			if (playlistContext.total > 0)
			{
				playlistsLoader = context.playlistsLoaderBuilder.build();
				playlistsLoader.addEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistsComplete);
				playlistsLoader.addEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistsError);
				playlistsLoader.load([playlistContext._id]);
			}
			else
			{
				_playlist = new Array();
				
				state = PREPARE_COMPLETE_STATE;
				dispatchEvent(new PluginManagerEvent(PluginManagerEvent.READY));
			}
		}
		
		private function onPlaylistsComplete(e:PlaylistsLoaderEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onPlaylistsComplete]-");
			
			e.currentTarget.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistsComplete);
			e.currentTarget.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistsError);
			
			context.playlistsLoaderBuilder.destroy(e.currentTarget as PlaylistsLoader);
			playlistsLoader = null;
			
			_playlist = e.playlists[0];
			_ready = true;
			
			if (local)
				localSoundPlayer.playlist = _playlist;
			else
				remotePlaylistListener.playlist = _playlist;
			
			state = PREPARE_COMPLETE_STATE;
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.READY));
		}
		
		private function onPlaylistsError(e:PlaylistsLoaderEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onPlaylistsError]-");
			
			e.currentTarget.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistsComplete);
			e.currentTarget.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistsError);
			
			context.playlistsLoaderBuilder.destroy(e.currentTarget as PlaylistsLoader);
			playlistsLoader = null;
			
			reset();
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Unable to load playlist please try again.", 103));
		}
		
		public function destroy(data:Object = null):void
		{
			reset();
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.DESTROY));
		}
		
		// ***************************************************************************************************************************************
		// ***************************************************************************************************************************************
		// ***************************************************************************************************************************************
		
		public function play(index:int = 0):void
		{
			trace("1.--RemotePlaylistPluginListenerManager[play]-", state, index, local);
			
			if (local)
			{
				soundIndex = index;
				localSoundPlayer.play(soundIndex);
			}
			else
			{
				if (state == PREPARE_COMPLETE_STATE)
				{
					soundIndex = index;
					
					state = CREATE_BROADCAST_STATE;
					
					existPluginsManager = context.pluginsManagersBuilder.build(targetRoutingMap);
					existPluginsManager.addSocketEventListener(PluginsManagerEvent.PLUGIN_EXIST_COMPLETE, onPluginExistComplete);
					existPluginsManager.addSocketEventListener(PluginsManagerEvent.PLUGIN_EXIST_ERROR, onPluginExistError);
					existPluginsManager.pluginExist(pluginData._id);
					
					trace("2.--RemotePlaylistPluginListenerManager[play]-", existPluginsManager.route);
					trace("3.--RemotePlaylistPluginListenerManager[play]-", existPluginsManager.receiverRoute);
				}
				else
				if (state == CREATE_BROADCAST_COMPLETE_STATE)
				{
					soundIndex = index;
					remotePlaylistListener.play(soundIndex);
				}
			}
		}
		
		private function onPluginExistComplete(e:PluginsManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onPluginExistComplete]-");
			
			e.currentTarget.removeSocketEventListener(PluginsManagerEvent.PLUGIN_EXIST_COMPLETE, onPluginExistComplete);
			e.currentTarget.removeSocketEventListener(PluginsManagerEvent.PLUGIN_EXIST_ERROR, onPluginExistError);
			
			context.pluginsManagersBuilder.destroy(e.currentTarget as PluginsManager);
			existPluginsManager = null;
			
			serversManager = context.serversManagersBuilder.build();
			serversManager.addSocketEventListener(ServersManagerEvent.GET_AVAILABLE_SERVER_COMPLETE, onGetAvailableServerComplete);
			serversManager.addSocketEventListener(ServersManagerEvent.GET_AVAILABLE_SERVER_ERROR, onGetAvailableServerError);
			serversManager.getAvailableServer();
		}
		
		private function onPluginExistError(e:PluginsManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onPluginExistError]-");
			
			e.currentTarget.removeSocketEventListener(PluginsManagerEvent.PLUGIN_EXIST_COMPLETE, onPluginExistComplete);
			e.currentTarget.removeSocketEventListener(PluginsManagerEvent.PLUGIN_EXIST_ERROR, onPluginExistError);
			
			context.pluginsManagersBuilder.destroy(e.currentTarget as PluginsManager);
			existPluginsManager = null;
			
			reset(false);
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, e.data.error, e.data.code));
		}
		
		private function onGetAvailableServerComplete(e:ServersManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onGetAvailableServerComplete]-");
			
			serversManager.removeSocketEventListener(ServersManagerEvent.GET_AVAILABLE_SERVER_COMPLETE, onGetAvailableServerComplete);
			serversManager.removeSocketEventListener(ServersManagerEvent.GET_AVAILABLE_SERVER_ERROR, onGetAvailableServerError);
			
			context.serversManagersBuilder.destroy(serversManager);
			serversManager = null;
			
			serverData.readObject(e.data);
			
			
			connection = context.connectionsController.createConnection("CONNECTION-" + remotePlaylistListener.id);
			connection.addUnit(remotePlaylistListener);
			
			bsContext = context.broadcastServerContextBuilder.build();
			bsContext.connection = connection;
			
			
			connection.addEventListener(FlashSocketClientEvent.DISCONNECTED, onInitializationDisconnect);
			connection.addEventListener(FlashSocketClientEvent.ERROR, onInitializationError);
			connection.addEventListener(ClientConnectionEvent.INITIALIZATION_COMPLETE, onInitializationComplete);
			connection.address = serverData.address;
			connection.port = serverData.port;
			connection.connect();
		}
		
		private function onGetAvailableServerError(e:ServersManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onGetAvailableServerError]-");
			
			serversManager.removeSocketEventListener(ServersManagerEvent.GET_AVAILABLE_SERVER_COMPLETE, onGetAvailableServerComplete);
			serversManager.removeSocketEventListener(ServersManagerEvent.GET_AVAILABLE_SERVER_ERROR, onGetAvailableServerError);
			
			context.serversManagersBuilder.destroy(serversManager);
			serversManager = null;
			
			reset(false);
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "There aro no active server.", 104));
			//dispatchEvent(new RemotePlaylistListenerEvent(RemotePlaylistListenerEvent.BROADCAST_CONNECTION_ERROR, e.data));
		}
		
		private function onInitializationDisconnect(e:FlashSocketClientEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onInitializationDisconnect]-");
			
			connection.removeEventListener(FlashSocketClientEvent.DISCONNECTED, onInitializationDisconnect);
			connection.removeEventListener(FlashSocketClientEvent.ERROR, onInitializationError);
			connection.removeEventListener(ClientConnectionEvent.INITIALIZATION_COMPLETE, onInitializationComplete);
			
			context.connectionsController.destroyConnection(connection);
			
			connection.removeUnit(remotePlaylistListener.id);
			connection = null;
			
			reset(false);
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Connection is lost.", 105));
		}
		
		private function onInitializationError(e:FlashSocketClientEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onInitializationError]-");
			
			connection.removeEventListener(FlashSocketClientEvent.DISCONNECTED, onInitializationDisconnect);
			connection.removeEventListener(FlashSocketClientEvent.ERROR, onInitializationError);
			connection.removeEventListener(ClientConnectionEvent.INITIALIZATION_COMPLETE, onInitializationComplete);
			
			context.connectionsController.destroyConnection(connection);
			
			connection.removeUnit(remotePlaylistListener.id);
			connection = null;
			
			reset(false);
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Unable to create connection with the server.", 106));
		}
		
		private function onInitializationComplete(e:ClientConnectionEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onInitializationComplete]-", remotePlaylistListener.route);
			
			connection.removeEventListener(FlashSocketClientEvent.DISCONNECTED, onInitializationDisconnect);
			connection.removeEventListener(FlashSocketClientEvent.ERROR, onInitializationError);
			connection.removeEventListener(ClientConnectionEvent.INITIALIZATION_COMPLETE, onInitializationComplete);
			
			connection.addEventListener(FlashSocketClientEvent.DISCONNECTED, onDisconnect);
			
			requestPluginsManager = context.pluginsManagersBuilder.build(targetRoutingMap);
			requestPluginsManager.addSocketEventListener(PluginsManagerEvent.PLUGIN_REQUEST_COMPLETE, onPluginRequestComplete);
			requestPluginsManager.addSocketEventListener(PluginsManagerEvent.PLUGIN_REQUEST_ERROR, onPluginRequestError);
			requestPluginsManager.pluginRequest(pluginData._id, PluginsManager.BROADCASTER, {
				playlistId: playlistContext._id,
				playerRoute: remotePlaylistListener.route,
				serverData: serverData.publicData
			});
			
			trace("---- YES ---", remotePlaylistListener.route)
		}
		
		private function onPluginRequestComplete(e:PluginsManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onPluginRequestComplete]-");
			
			e.currentTarget.removeSocketEventListener(PluginsManagerEvent.PLUGIN_REQUEST_COMPLETE, onPluginRequestComplete);
			e.currentTarget.removeSocketEventListener(PluginsManagerEvent.PLUGIN_REQUEST_ERROR, onPluginRequestError);
			
			context.pluginsManagersBuilder.destroy(e.currentTarget as PluginsManager);
			requestPluginsManager = null;
			
			remotePlaylistListener.receiverRoute = e.data.broadcasterRoute;
			
			connectionsManager = bsContext.connectionsManagerBuilder.build();
			connectionsManager.addSocketEventListener(ConnectionsManagerEvent.WATCH_FOR_DISCONNECT_COMPLETE, onWatchForDisconnectComplete);
			connectionsManager.addSocketEventListener(ConnectionsManagerEvent.WATCH_FOR_DISCONNECT_ERROR, onWatchForDisconnectError);
			connectionsManager.watchForDisconnect([remotePlaylistListener.receiverRoute[1]]);
		}
		
		private function onPluginRequestError(e:PluginsManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onPluginRequestError]-");
			
			e.currentTarget.removeSocketEventListener(PluginsManagerEvent.PLUGIN_REQUEST_COMPLETE, onPluginRequestComplete);
			e.currentTarget.removeSocketEventListener(PluginsManagerEvent.PLUGIN_REQUEST_ERROR, onPluginRequestError);
			
			context.pluginsManagersBuilder.destroy(e.currentTarget as PluginsManager);
			requestPluginsManager = null;
			
			reset(false);
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, e.data.error, e.data.code));
		}
		
		private function onWatchForDisconnectComplete(e:ConnectionsManagerEvent):void
		{
			connectionsManager.removeSocketEventListener(ConnectionsManagerEvent.WATCH_FOR_DISCONNECT_COMPLETE, onWatchForDisconnectComplete);
			connectionsManager.removeSocketEventListener(ConnectionsManagerEvent.WATCH_FOR_DISCONNECT_ERROR, onWatchForDisconnectError);
			
			var onlineReport:Object = e.data.report;
			
			trace("--RemotePlaylistPluginListenerManager[onWatchForDisconnectComplete]-");
			
			if (onlineReport && onlineReport[remotePlaylistListener.receiverRoute[1]])
			{
				state = CREATE_BROADCAST_COMPLETE_STATE;
				connectionsManager.addSocketEventListener(ConnectionsManagerEvent.DISCONNECT_DETECTED, onBroadcasterDisconnect);
				
				remotePlaylistListener.play(soundIndex);
			}
			else
			{
				reset();
				dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Connection is lost.", 107));
			}
		}
		
		private function onWatchForDisconnectError(e:ConnectionsManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onWatchForDisconnectError]-");
			
			bsContext.connectionsManagerBuilder.destroy(connectionsManager);
			connectionsManager = null;
			
			reset();
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Unable to preapare broadcast.", 108));
		}
		
		private function onDisconnect(e:FlashSocketClientEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onDisconnect]-");
			
			reset(false);
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Connection is lost.", 109));
		}
		
		private function onBroadcasterDisconnect(e:ConnectionsManagerEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onBroadcasterDisconnect]-");
			
			reset(false);
			dispatchEvent(new PluginManagerEvent(PluginManagerEvent.ERROR, null, "Broadcaster connection is lost.", 110));
		}
		
		public function stop():void
		{
			if (local)
				localSoundPlayer.stop();
			else
				remotePlaylistListener.stop();
		}
		
		public function next():void
		{
			if (local)
				localSoundPlayer.next();
			else
				remotePlaylistListener.next();
		}
		
		public function previous():void
		{
			if (local)
				localSoundPlayer.previous();
			else
				remotePlaylistListener.previous();
		}
		
		public function changePlayOrder(order:int = 0):void
		{
			if (local)
				localSoundPlayer.changePlayOrder(order);
			else
				remotePlaylistListener.changePlayOrder(order);
		}
		
		public function get playOrder():Number
		{
			if (local)
				return localSoundPlayer.playOrder;
			
			return remotePlaylistListener.playOrder;
		}
		
		public function get trackIndex():Number
		{
			if (local)
				return localSoundPlayer.trackIndex;
			
			return remotePlaylistListener.trackIndex;
		}
		
		public function set volume(value:Number):void
		{
			if (local)
				localSoundPlayer.volume = value;
			else
				remotePlaylistListener.volume = value;
		}
		
		public function get volume():Number
		{
			if (local)
				return localSoundPlayer.volume;
			
			return remotePlaylistListener.volume;
		}
		
		//**************************************************************************************************************
		// 												SAVE PLAYLIST SONGS
		//**************************************************************************************************************
		
		public function saveSongs():void
		{
			var playlistsDataManager:PlaylistsDataManager = context.playlistsDataManagersBuilder.build();
			
			playlistsDataManager.addEventListener(MongoDBRestEvent.COMPLETE, onSavePlaylistFileComplete);
			playlistsDataManager.addEventListener(MongoDBRestEvent.ERROR, onSavePlaylistFileError);
			playlistsDataManager.savePlaylistFile(playlistContext._id, playlist, context.sessionId);
		}
		
		private function onSavePlaylistFileComplete(e:MongoDBRestEvent):void
		{
			e.currentTarget.removeEventListener(MongoDBRestEvent.COMPLETE, onSavePlaylistFileComplete);
			e.currentTarget.removeEventListener(MongoDBRestEvent.ERROR, onSavePlaylistFileError);
			
			context.playlistsDataManagersBuilder.destroy(e.currentTarget as PlaylistsDataManager);
			playlistContext.total = playlist.length;
			
			dispatchEvent(new RemotePlaylistPluginListenerManagerEvent(RemotePlaylistPluginListenerManagerEvent.SAVE_PLAYLIST_COMPLETE));
		}
		
		private function onSavePlaylistFileError(e:MongoDBRestEvent):void
		{
			e.currentTarget.removeEventListener(MongoDBRestEvent.COMPLETE, onSavePlaylistFileComplete);
			e.currentTarget.removeEventListener(MongoDBRestEvent.ERROR, onSavePlaylistFileError);
			
			context.playlistsDataManagersBuilder.destroy(e.currentTarget as PlaylistsDataManager);
			
			dispatchEvent(new RemotePlaylistPluginListenerManagerEvent(RemotePlaylistPluginListenerManagerEvent.SAVE_PLAYLIST_ERROR));
		}
		
		//**************************************************************************************************************
		// 												LOAD PLAYLIST SONGS
		//**************************************************************************************************************
		
		public function loadPlaylist(playlistId:String):void
		{
			trace("--RemotePlaylistPluginListenerManager[loadPlaylist]-");
			
			if (playlistLoader)
			{
				playlistLoader.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistComplete);
				playlistLoader.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistError);
				
				context.playlistsLoaderBuilder.destroy(playlistLoader);
				playlistLoader = null;
			}
			
			playlistLoader = context.playlistsLoaderBuilder.build();
			playlistLoader.addEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistComplete);
			playlistLoader.addEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistError);
			playlistLoader.load([playlistId]);
		}
		
		private function onPlaylistComplete(e:PlaylistsLoaderEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onPlaylistComplete]-");
			
			e.currentTarget.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistComplete);
			e.currentTarget.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistError);
			
			context.playlistsLoaderBuilder.destroy(e.currentTarget as PlaylistsLoader);
			playlistLoader = null;
			
			dispatchEvent(new RemotePlaylistPluginListenerManagerEvent(RemotePlaylistPluginListenerManagerEvent.LOAD_PLAYLIST_COMPLETE, e.playlists[0]));
		}
		
		private function onPlaylistError(e:PlaylistsLoaderEvent):void
		{
			trace("--RemotePlaylistPluginListenerManager[onPlaylistError]-");
			
			e.currentTarget.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistComplete);
			e.currentTarget.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistError);
			
			context.playlistsLoaderBuilder.destroy(e.currentTarget as PlaylistsLoader);
			playlistLoader = null;
			
			dispatchEvent(new RemotePlaylistPluginListenerManagerEvent(RemotePlaylistPluginListenerManagerEvent.LOAD_PLAYLIST_ERROR));
		}
		
		//**************************************************************************************************************
		// 													RESET
		//**************************************************************************************************************
		
		public function reset(all:Boolean = true):void
		{
			trace("--RemotePlaylistPluginListenerManager[reset]-", state);
			
			if (state == NONE_STATE || (!all && state == PREPARE_COMPLETE_STATE))
				return ;
			
			if (all)
			{
				if (stationsManager)
				{
					context.stationsManagersBuilder.destroy(stationsManager);
					stationsManager = null;
				}
				
				if (playlistsLoader)
				{
					playlistsLoader.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistsComplete);
					playlistsLoader.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistsError);
					
					context.playlistsLoaderBuilder.destroy(playlistsLoader);
					playlistsLoader = null;
				}
				
				state = NONE_STATE;
				targetRoutingMap = null;
			}
			else
				state = PREPARE_COMPLETE_STATE;
			
			if (playlistLoader)
			{
				playlistLoader.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_COMPLETE, onPlaylistComplete);
				playlistLoader.removeEventListener(PlaylistsLoaderEvent.PLAYLISTS_ERROR, onPlaylistError);
				
				context.playlistsLoaderBuilder.destroy(playlistLoader);
				playlistLoader = null;
			}
			
			if (serversManager)
			{
				context.serversManagersBuilder.destroy(serversManager);
				serversManager = null;
			}
			
			if (existPluginsManager)
			{
				context.pluginsManagersBuilder.destroy(existPluginsManager);
				existPluginsManager = null;
			}
			
			if (requestPluginsManager)
			{
				context.pluginsManagersBuilder.destroy(requestPluginsManager);
				requestPluginsManager = null;
			}
			
			if (bsContext)
			{
				if (connectionsManager)
				{
					bsContext.connectionsManagerBuilder.destroy(connectionsManager);
					connectionsManager = null;
				}
				
				connection.removeEventListener(FlashSocketClientEvent.DISCONNECTED, onInitializationDisconnect);
				connection.removeEventListener(FlashSocketClientEvent.ERROR, onInitializationError);
				connection.removeEventListener(ClientConnectionEvent.INITIALIZATION_COMPLETE, onInitializationComplete);
				connection.removeEventListener(FlashSocketClientEvent.DISCONNECTED, onDisconnect);
				
				context.connectionsController.destroyConnection(connection);
				
				connection.removeUnit(remotePlaylistListener.id);
				connection = null;
				
				context.broadcastServerContextBuilder.destroy(bsContext);
				bsContext = null;
			}
			else
				localSoundPlayer.stop();
		}
		
		public function match(data:Object):Object
		{
			return null;
		}
		
		public function get playlistContext():PlaylistContext
		{
			return _playlistContext;
		}
		
		public function get playlist():Array
		{
			return _playlist;
		}
		
		public function get local():Boolean
		{
			return _local;
		}
		
		public function get isOwner():Boolean
		{
			return stationContext.accountData._id == playlistContext.accountId;
		}
		
		public function get ready():Boolean
		{
			return _ready;
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
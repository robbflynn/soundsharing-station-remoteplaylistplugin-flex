package soundshare.plugins.station.remoteplaylist.builders
{
	import soundshare.station.data.StationContext;
	import soundshare.plugins.station.remoteplaylist.managers.broadcaster.RemotePlaylistPluginBroadcasterManager;
	import soundshare.plugins.station.remoteplaylist.managers.listener.RemotePlaylistPluginListenerManager;
	import soundshare.plugins.station.remoteplaylist.views.RemotePlaylistListenerView;
	import soundshare.sdk.data.SoundShareContext;
	import soundshare.sdk.data.plugin.PluginData;
	import soundshare.sdk.plugins.builder.IPluginBuilder;
	import soundshare.sdk.plugins.builder.result.PluginBuilderResult;
	import soundshare.sdk.plugins.manager.events.PluginManagerEvent;
	
	public class RemotePlaylistPluginBuilder implements IPluginBuilder
	{
		private static const MAX_LISTENERS_CACHE:int = 5;
		private static const MAX_BROADCASTERS_CACHE:int = 5;
		
		private var stationContext:StationContext;
		
		private var listenerView:RemotePlaylistListenerView;
		
		private var listenerManagersCache:Vector.<RemotePlaylistPluginListenerManager> = new Vector.<RemotePlaylistPluginListenerManager>();
		private var broadcasterManagersCache:Vector.<RemotePlaylistPluginBroadcasterManager> = new Vector.<RemotePlaylistPluginBroadcasterManager>();
		
		public function RemotePlaylistPluginBuilder()
		{
		}
		
		protected function buildListenerView():RemotePlaylistListenerView
		{
			if (!listenerView)
				listenerView = new RemotePlaylistListenerView();
			
			return listenerView;
		}
		
		protected function buildListenerManager():RemotePlaylistPluginListenerManager
		{
			var manager:RemotePlaylistPluginListenerManager; 
			
			if (listenerManagersCache.length > 0)
				manager = listenerManagersCache.shift();
			else
				manager = new RemotePlaylistPluginListenerManager();
			
			manager.context = context;
			
			return manager;
		}
		
		public function buildListener(pluginData:PluginData, buildView:Boolean = true, data:Object = null):PluginBuilderResult
		{
			var manager:RemotePlaylistPluginListenerManager = buildListenerManager();
			manager.addEventListener(PluginManagerEvent.DESTROY, onDestroyListenerPlugin);
			manager.pluginData = pluginData;
			
			var view:RemotePlaylistListenerView = buildListenerView();
			view.manager = manager;
			
			return new PluginBuilderResult(manager, view);
		}
		
		protected function onDestroyListenerPlugin(e:PluginManagerEvent):void
		{
			e.currentTarget.removeEventListener(PluginManagerEvent.DESTROY, onDestroyListenerPlugin);
			
			if (listenerManagersCache.length < MAX_LISTENERS_CACHE)
				listenerManagersCache.push(e.currentTarget as RemotePlaylistPluginListenerManager);
		}
		
		public function buildBroadcaster(pluginData:PluginData, buildView:Boolean = true, data:Object = null):PluginBuilderResult
		{
			var manager:RemotePlaylistPluginBroadcasterManager = new RemotePlaylistPluginBroadcasterManager(context);
			manager.addEventListener(PluginManagerEvent.DESTROY, onDestroyBroadcasterPlugin);
			
			return new PluginBuilderResult(manager);
		}
		
		protected function onDestroyBroadcasterPlugin(e:PluginManagerEvent):void
		{
			e.currentTarget.removeEventListener(PluginManagerEvent.DESTROY, onDestroyBroadcasterPlugin);
			
			if (broadcasterManagersCache.length < MAX_LISTENERS_CACHE)
				broadcasterManagersCache.push(e.currentTarget as RemotePlaylistPluginBroadcasterManager);
		}
		
		public function buildConfiguration(pluginData:PluginData, buildView:Boolean = true, data:Object = null):PluginBuilderResult
		{
			return new PluginBuilderResult();
		}
		
		public function set context(value:SoundShareContext):void
		{
			stationContext = value as StationContext;
		}
		
		public function get context():SoundShareContext
		{
			return stationContext;
		}
	}
}
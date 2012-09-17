package soundshare.plugins.station.remoteplaylist.builders.messages.broadcaster
{
	import flash.utils.ByteArray;
	
	import flashsocket.message.FlashSocketMessage;
	import flashsocket.client.base.ClientSocketUnit;
	
	import soundshare.sdk.data.SoundShareContext;
	import soundshare.sdk.managers.events.SecureClientEventDispatcher;
	
	public class RemotePlaylistBroadcasterMessageBuilder
	{
		public var target:SecureClientEventDispatcher;
		
		private var broadcastHeaderObject:Object;
		private var broadcastSetInfoHeaderObject:Object;
		
		private var broadcastMessage:FlashSocketMessage;
		private var broadcastInfoMessage:FlashSocketMessage;
		
		public function RemotePlaylistBroadcasterMessageBuilder(target:SecureClientEventDispatcher)
		{
			this.target = target;
			
			this.broadcastHeaderObject = {
				route: {
					sender: target.route,
					receiver: target.receiverRoute
				},
				data: {
					token: target.token,
					action: {
						xtype: "BROADCAST_AUDIO_DATA"
					}
				}
			}
				
			this.broadcastSetInfoHeaderObject = {
				route: {
					sender: target.route,
					receiver: target.receiverRoute
				},
				data: {
					token: target.token,
					action: {
						xtype: "SET_AUDIO_INFO_DATA"
					}
				}
			}
				
			this.broadcastMessage = new FlashSocketMessage();
			this.broadcastInfoMessage = new FlashSocketMessage();
		}
		
		protected function build(xtype:String):FlashSocketMessage
		{
			if (!xtype)
				throw new Error("Invalid xtype!");
			
			var message:FlashSocketMessage = new FlashSocketMessage();
			message.setJSONHeader({
				route: {
					sender: target.route,
					receiver: target.receiverRoute
				},
				data: {
					token: target.token,
					action: {
						xtype: xtype
					}
				}
			});
			
			return message;
		}
		
		public function buildLoadAudioDataErrorMessage():FlashSocketMessage
		{
			return build("LOAD_AUDIO_DATA_ERROR");
		}
		
		public function buildStopPlayingMessage():FlashSocketMessage
		{
			return build("STOP_PLAYING");
		}
		
		public function buildCloseConnectionMessage():FlashSocketMessage
		{
			return build("CLOSE_CONNECTION");
		}
		
		public function buildChangeSongMessage(index:int):FlashSocketMessage
		{
			var message:FlashSocketMessage = build("CHANGE_SONG");
			
			if (message)
			{
				message.setJSONBody({
					index: index
				});
			}
			
			return message;
		}
		
		public function buildBroadcastMessage():FlashSocketMessage
		{
			broadcastHeaderObject.route.sender = target.route;
			broadcastHeaderObject.route.receiver = target.receiverRoute;
			broadcastHeaderObject.data.token = target.token;
			
			broadcastMessage.clear();
			broadcastMessage.setJSONHeader(broadcastHeaderObject);
			
			return broadcastMessage;
		}
		
		public function buildSetAudioInfoDataMessage(audioInfoData:Object):FlashSocketMessage
		{
			broadcastSetInfoHeaderObject.route.sender = target.route;
			broadcastSetInfoHeaderObject.route.receiver = target.receiverRoute;
			broadcastSetInfoHeaderObject.data.token = target.token;
			
			broadcastInfoMessage.clear();
			broadcastInfoMessage.setJSONHeader(broadcastSetInfoHeaderObject);
			broadcastInfoMessage.setJSONBody({
				audioInfoData: audioInfoData
			});
			
			return broadcastInfoMessage;
		}
	}
}
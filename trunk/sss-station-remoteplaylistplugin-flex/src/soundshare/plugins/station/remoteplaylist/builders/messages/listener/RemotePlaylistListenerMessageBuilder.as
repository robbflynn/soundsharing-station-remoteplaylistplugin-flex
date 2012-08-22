package soundshare.plugins.station.remoteplaylist.builders.messages.listener
{
	import socket.message.FlashSocketMessage;
	
	import soundshare.sdk.managers.events.SecureClientEventDispatcher;
	
	public class RemotePlaylistListenerMessageBuilder
	{
		protected var target:SecureClientEventDispatcher;
		
		public var broadcastRoute:Array;
		public var broadcastsManagerRoute:Array;
		
		public function RemotePlaylistListenerMessageBuilder(target:SecureClientEventDispatcher)
		{
			this.target = target;
		}
		
		protected function build(xtype:String):FlashSocketMessage
		{
			if (!xtype)
				return null;
			
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
		
		public function buildPlaySongMessage(index:int = 0, order:int = -1):FlashSocketMessage
		{
			var message:FlashSocketMessage = build("PLAY");
			message.setJSONBody({
				index: index,
				order: order
			});
			
			return message;
		}
		
		public function buildStopSongMessage():FlashSocketMessage
		{
			return build("STOP");
		}
		
		public function buildChangePlayOrder(order:int = 0):FlashSocketMessage
		{
			var message:FlashSocketMessage = build("CHANGE_PLAY_ORDER");
			message.setJSONBody({
				order: order
			});
			
			return message;
		}
		
		public function buildPreviousSongMessage():FlashSocketMessage
		{
			return build("PREVIOUS");
		}
		
		public function buildNextSongMessage():FlashSocketMessage
		{
			return build("NEXT");
		}
	}
}
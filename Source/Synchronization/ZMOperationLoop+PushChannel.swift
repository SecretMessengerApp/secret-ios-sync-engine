//

import Foundation

extension ZMOperationLoop: ZMPushChannelConsumer {
    
    public func pushChannel(_ channel: ZMPushChannelConnection, didReceive data: ZMTransportData) {
        Logging.network.info("Push Channel:\n\(data)")
        
        if let events = ZMUpdateEvent.eventsArray(fromPushChannelData: data), !events.isEmpty {
            Logging.eventProcessing.info("Received \(events.count) events from push channel")
            events.forEach({ $0.appendDebugInformation("from push channel (web socket)")})
            let hugeEvents = events.filter {$0.convType == .huge}
            let normalEvents = events.filter {$0.convType != .huge && $0.convType != .iTask}
            if normalEvents.count > 0 {
                syncStrategy.process(updateEvents: normalEvents, ignoreBuffer: false)
            }
            if hugeEvents.count > 0 {
                syncStrategy.processHuge(updateEvents: hugeEvents, ignoreBuffer: false)
            }
        }
    }
    
    public func pushChannelDidClose(_ channel: ZMPushChannelConnection, with response: HTTPURLResponse?, error: Error?) {
        NotificationInContext(name: ZMOperationLoop.pushChannelStateChangeNotificationName,
                              context: syncMOC.notificationContext,
                              object: self,
                              userInfo: [ ZMPushChannelIsOpenKey: false]).post()
        
        syncStrategy.didInterruptUpdateEventsStream()
        RequestAvailableNotification.notifyNewRequestsAvailable(nil)
    }
    
    public func pushChannelDidOpen(_ channel: ZMPushChannelConnection, with response: HTTPURLResponse?) {
        NotificationInContext(name: ZMOperationLoop.pushChannelStateChangeNotificationName,
                              context: syncMOC.notificationContext,
                              object: self,
                              userInfo: [ ZMPushChannelIsOpenKey: true]).post()
        
        syncStrategy.didEstablishUpdateEventsStream()
        RequestAvailableNotification.notifyNewRequestsAvailable(nil)
    }
    
}

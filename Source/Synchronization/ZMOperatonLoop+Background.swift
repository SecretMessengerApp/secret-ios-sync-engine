//

import Foundation

fileprivate enum PushChannelKeys: String {
    case data = "data"
    case identifier = "id"
    case notificationType = "type"
}

fileprivate enum PushNotificationType: String {
    case plain = "plain"
    case cipher = "cipher"
    case notice = "notice"
    case sieNotice = "notice-sie"
}

@objc
public extension ZMOperationLoop {

    @objc(fetchEventsFromPushChannelPayload:completionHandler:)
    func fetchEvents(fromPushChannelPayload payload: [AnyHashable : Any], completionHandler: @escaping () -> Void) {        
        syncMOC.performGroupedBlock {
            guard let nonce = self.messageNonce(fromPushChannelData: payload) else {
                return completionHandler()
            }
            
//            if payload.hugeGroupConversationId() != nil {
//                self.pushHugeNotificationStatus.fetch(eventId: nonce, completionHandler: {
//                     self.callEventStatus.waitForCallEventProcessingToComplete { [weak self] in
//                        guard let strongSelf = self else { return }
//                        strongSelf.syncMOC.performGroupedBlock {
//                            completionHandler()
//                        }
//                    }
//                })
//            } else
            
            if payload.accountId() != nil  {
                self.pushNotificationStatus.fetch(eventId: nonce, completionHandler: {
                     self.callEventStatus.waitForCallEventProcessingToComplete { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.syncMOC.performGroupedBlock {
                            completionHandler()
                        }
                    }
                })
            }
        }
    }
    
    func messageNonce(fromPushChannelData payload: [AnyHashable : Any]) -> UUID? {
        guard let notificationData = payload[PushChannelKeys.data.rawValue] as? [AnyHashable : Any],
              let rawNotificationType = notificationData[PushChannelKeys.notificationType.rawValue] as? String,
              let notificationType = PushNotificationType(rawValue: rawNotificationType) else {
            return nil
        }
        
        switch notificationType {
        case .plain, .notice, .sieNotice:
            if let data = notificationData[PushChannelKeys.data.rawValue] as? [AnyHashable : Any], let rawUUID = data[PushChannelKeys.identifier.rawValue] as? String {
                return UUID(uuidString: rawUUID)
            }
        case .cipher:
            return messageNonce(fromEncryptedPushChannelData: notificationData)
        }
        
        return nil
    }
    
    func messageNonce(fromEncryptedPushChannelData encryptedPayload: [AnyHashable : Any]) -> UUID? {
        //    @"aps" : @{ @"alert": @{@"loc-args": @[],
        //                          @"loc-key"   : @"push.notification.new_message"}
        //              },
        //    @"data": @{ @"data" : @"SomeEncryptedBase64EncodedString",
        //                @"mac"  : @"someMacHashToVerifyTheIntegrityOfTheEncodedPayload",
        //                @"type" : @"cipher"
        //
        
        guard let apsSignalKeyStore = apsSignalKeyStore else {
            Logging.network.debug("Could not initiate APSSignalingKeystore")
            return nil
        }
        
        guard let decryptedPayload = apsSignalKeyStore.decryptDataDictionary(encryptedPayload) else {
            Logging.network.debug("Failed to decrypt data dictionary from push payload: \(encryptedPayload)")
            return nil
        }
        
        if let data = decryptedPayload[PushChannelKeys.data.rawValue] as? [AnyHashable : Any], let rawUUID = data[PushChannelKeys.identifier.rawValue] as? String {
            return UUID(uuidString: rawUUID)
        }
        
        return nil
    }
    
}

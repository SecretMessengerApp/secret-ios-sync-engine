//

import Foundation

private let log = ZMSLog(tag: "UserTranscoder")

extension ZMUserTranscoder {
    
    @objc
    public func processUpdateEvent(_ updateEvent: ZMUpdateEvent) {
        switch updateEvent.type {
        case .userUpdate:
            processUserUpdate(updateEvent)
        case .userDelete:
            processUserDeletion(updateEvent)
        default:
            break
        }
    }
    
    private func processUserUpdate(_ updateEvent: ZMUpdateEvent) {
        guard updateEvent.type == .userUpdate else { return }
        
        guard let userPayload = updateEvent.payload["user"] as? [String: Any],
              let userId = (userPayload["id"] as? String).flatMap(UUID.init)
        else {
            return Logging.eventProcessing.error("Malformed user.update update event, skipping...")
        }
        
        let user = ZMUser.fetchAndMerge(with: userId, createIfNeeded: true, in: managedObjectContext)
        user?.update(withTransportData: userPayload, authoritative: false)
    }
    
    private func processUserDeletion(_ updateEvent: ZMUpdateEvent) {
        guard updateEvent.type == .userDelete else { return }
        
        guard let userId = (updateEvent.payload["id"] as? String).flatMap(UUID.init),
              let user = ZMUser.fetchAndMerge(with: userId, createIfNeeded: false, in: managedObjectContext)
        else {
            return Logging.eventProcessing.error("Malformed user.delete update event, skipping...")
        }
        
        if user.isSelfUser {
            deleteAccount()
        } else {
            user.markAccountAsDeleted(at: updateEvent.timeStamp() ?? Date())
        }
    }
    
    private func deleteAccount() {
        PostLoginAuthenticationNotification.notifyAccountDeleted(context: managedObjectContext)
    }
    
    func dealwithUserNotice(updateEvent: ZMUpdateEvent) {
        guard let data = updateEvent.payload["data"] as? [AnyHashable : Any] else { return }
        
        guard let _type = data["msgType"] as? String, let type = UserNoticeMessageType(rawValue: _type) else {
            log.error("Invalid message type")
            return
        }
        
        if type == .fifthElement {
            if let dict = data["msgData"] as? [AnyHashable : String] {
                dealwith5thElement(info: dict)
            }
        } else {
            log.warn("Unsupported user mesage type")
        }
    }
    
    func dealwith5thElement(info: [AnyHashable : String]) {
        typealias ElementType = [AnyHashable : String]
        
        guard let id = info["id"], let convID = info["conv"] else {
            log.error("Invalid message body")
            return
        }
        
        let userID = ZMUser.selfUser(in: self.managedObjectContext).remoteIdentifier.transportString()
        let key = "5th-\(userID)"
        
        var arr: [ElementType] = []
        if let obj = UserDefaults.standard.array(forKey: key) as? [ElementType] {
            arr = obj
        }
        
        arr = arr.filter { item in
            if let itemID = item["id"], id != itemID {
                return true
            } else {
                return false
            }
        }
        
        arr.insert(info, at: 0)
        UserDefaults.standard.set(arr, forKey: key)
        
        // Pull
        if let remoteID = UUID(uuidString: convID) {
            var conversationCreated: ObjCBool = false
            let conv = ZMConversation(remoteID: remoteID, createIfNeeded: true, in: self.managedObjectContext, created: &conversationCreated)
            conv?.fifth_image = info["img"]
            conv?.fifth_name = info["name"]
            conv?.joinGroupUrl = info["join_url"]
            if conversationCreated.boolValue {
                conv?.conversationType = .invalid
            }
            conv?.needsToBeUpdatedFromBackend = true
        }
        
        if arr.count > 1 {
            return
        }
        
        var shouldSendNotification = false
        if let payload = UserDefaults.standard.value(forKey: userID) as? [AnyHashable : Any] {
            let items: [String] = (payload["ShortcutConversations"] as? [String]) ?? []
            shouldSendNotification = items.count == 0
        } else {
            shouldSendNotification = true
        }
        
        if shouldSendNotification {
            log.info("Send notification to show 5th element")
            NotificationCenter.default.post(name: NSNotification.Name("Show5thElementNotification"), object: nil)
        }
        
    }
}

enum UserNoticeMessageType: String {
    case fifthElement = "20010"
}

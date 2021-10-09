
import Foundation

@objc
public class HugeConversationSetting: NSObject {
    
    static private let HugeConversationSaveID = "HugeConversationSaveID"
    
    @objc(saveWithConversationList:in:)
    public static func save(with conversationList: [ZMConversation], in userId: String) {
        let saveKey = HugeConversationSaveID + "-" + userId
        let noMuteConversations = conversationList.filter { (conversation) -> Bool in
            return conversation.mutedMessageTypes == .none
        }
        let idsSet = Array(Set(noMuteConversations.compactMap {$0.remoteIdentifier?.transportString()}))
        UserDefaults.standard.setValue(idsSet, forKey: saveKey)
    }
    
    
    static func muteHugeConversationInBackground(with cid: UUID, userId: String) -> Bool {
        let saveKey = HugeConversationSaveID + "-" + userId
        guard let ids = UserDefaults.standard.value(forKey: saveKey) as? [String] else { return false }
        return !Set(ids).contains(cid.transportString())
    }
    
}

@objc extension ZMUserSession {
    
    public func saveHugeGroup() {
        if let hugeGroups = ZMConversation.hugeGroupConversations(in: self.managedObjectContext) as? [ZMConversation] {
            guard let context = self.managedObjectContext else {return}
            let uid = ZMUser.selfUser(in: context).remoteIdentifier.transportString()
            HugeConversationSetting.save(with: hugeGroups, in: uid)
        }
    }
    
}

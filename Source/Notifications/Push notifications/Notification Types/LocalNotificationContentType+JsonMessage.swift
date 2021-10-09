//
//  LocalNotificationContentType+JsonMessage.swift
//  WireSyncEngine-ios
//
//  Created by 刘超 on 2021/6/3.
//  Copyright © 2021 Zeta Project Gmbh. All rights reserved.
//

import Foundation


public struct LocalNotificationJsonTextMessage {
    enum `Type`: String {
        case secretHouseInvitation = "20040"
    }
    
    private let type: `Type`
    private let jsonData: [String: Any]
    
    init?(jsonString: String) {
        guard let jsonMessageData = jsonString.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonMessageData, options: JSONSerialization.ReadingOptions.mutableContainers),
            let dict = jsonObject as? [String: Any] else {
            return nil
        }
        guard let msgType = dict["msgType"] as? String,
              let type = Type.init(rawValue: msgType) else { return nil }
        guard let msgData = dict["msgData"] as? [String: Any] else { return nil }
        
        self.type = type
        self.jsonData = msgData
    }
}


extension LocalNotificationJsonTextMessage {
    
    public var baseKey : String {
        switch self.type {
        case .secretHouseInvitation:
            return "secretHouse.invitation" 
        }
    }
    
    public var arguments : [CVarArg] {
        switch self.type {
        case .secretHouseInvitation:
            guard let sender = self.jsonData["sender"] as? [String: Any],
                let senderName = sender["nickname"] as? String else { return [] }
            return [senderName]
        }
    }
    
}


//

import Foundation

extension ZMLocalNotification {
    
    convenience init?(availability: Availability, managedObjectContext moc: NSManagedObjectContext) {
        let builder = AvailabilityNotificationBuilder(availability: availability, managedObjectContext: moc)
        
        self.init(conversation: nil, builder: builder)
    }
    
}

private class AvailabilityNotificationBuilder: NotificationBuilder {
    
    let managedObjectContext: NSManagedObjectContext
    let availability: Availability
    
    
    init(availability: Availability, managedObjectContext: NSManagedObjectContext) {
        self.availability = availability
        self.managedObjectContext = managedObjectContext
    }
    
    var notificationType: LocalNotificationType {
        return .availabilityBehaviourChangeAlert(availability)
    }
    
    func shouldCreateNotification() -> Bool {
        return availability.isOne(of: .away, .busy)
    }
    
    func titleText() -> String? {
        return notificationType.alertTitleText(team: ZMUser.selfUser(in: managedObjectContext).team)
    }
    
    func bodyText() -> String {
        return notificationType.alertMessageBodyText()
    }
    
    func userInfo() -> NotificationUserInfo? {
        return nil
    }
}

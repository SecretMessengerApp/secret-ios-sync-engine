//

import XCTest
@testable import WireSyncEngine

class ZMLocalNotificationTests_Alerts: ZMLocalNotificationTests {
    
    func addSelfUserToTeam() {
        self.syncMOC.performGroupedBlockAndWait {
            let team = Team.insertNewObject(in: self.syncMOC)
            team.name = "Team-A"
            let user = ZMUser.selfUser(in: self.syncMOC)
            _ = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)
            self.syncMOC.saveOrRollback()
            XCTAssertNotNil(user.team)
        }
    }

    func testAvailabilityBehaviourChangeNotification_WhenAway() {
        // given
        addSelfUserToTeam()
        
        // when
        let note = ZMLocalNotification(availability: .away, managedObjectContext: uiMOC)
        
        // then
        XCTAssertEqual(note?.title, "Notifications are disabled in Team-A")
        XCTAssertEqual(note?.body, "Status affects notifications now. You’re set to “Away” and won’t receive any notifications.")
    }
    
    func testAvailabilityBehaviourChangeNotification_WhenBusy() {
        // given
        addSelfUserToTeam()
        
        // when
        let note = ZMLocalNotification(availability: .busy, managedObjectContext: uiMOC)
        
        // then
        XCTAssertEqual(note?.title, "Notifications have changed in Team-A")
        XCTAssertEqual(note?.body, "Status affects notifications now. You’re set to “Busy” and will only receive notifications when someone mentions you or replies to one of your messages.")
    }

}

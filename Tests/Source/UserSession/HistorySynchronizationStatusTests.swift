//


import WireSyncEngine
import XCTest

class HistorySynchronizationStatusTests: MessagingTest {
}

extension HistorySynchronizationStatusTests {

    func testThatItShouldNotDownloadHistoryWhenItStarts() {
        
        // given
        let sut = ForegroundOnlyHistorySynchronizationStatus(managedObjectContext: self.uiMOC, application: self.application)
        
        // then
        XCTAssertFalse(sut.shouldDownloadFullHistory)
    }

    func testThatItShouldDownloadWhenDidCompleteSync() {
        
        // given
        let sut = ForegroundOnlyHistorySynchronizationStatus(managedObjectContext: self.uiMOC, application: self.application)
        
        // when
        sut.didCompleteSync()
        
        // then
        XCTAssertTrue(sut.shouldDownloadFullHistory)
    }
    
    func testThatItShouldNotDownloadWhenDidCompleteSyncAndThenStartSyncAgain() {
        
        // given
        let sut = ForegroundOnlyHistorySynchronizationStatus(managedObjectContext: self.uiMOC, application: self.application)
        
        // when
        sut.didCompleteSync()
        sut.didStartSync()
        
        // then
        XCTAssertFalse(sut.shouldDownloadFullHistory)
    }
    
    func testThatItShouldNotDownloadWhenDidCompleteSyncAndWillResignActive() {
        
        // given
        let sut = ForegroundOnlyHistorySynchronizationStatus(managedObjectContext: self.uiMOC, application: self.application)
        
        // when
        sut.didCompleteSync()
        self.application.simulateApplicationWillResignActive()
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(sut.shouldDownloadFullHistory)
    }

    func testThatItShouldDownloadWhenBecomingActive() {
        
        // given
        let sut = ForegroundOnlyHistorySynchronizationStatus(managedObjectContext: self.uiMOC, application: self.application)
        
        // when
        sut.didCompleteSync()
        self.application.simulateApplicationWillResignActive()
        self.application.simulateApplicationDidBecomeActive()
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(sut.shouldDownloadFullHistory)
    }
    
    func testThatItShouldNotDownloadAfterBecomingActiveIfItIsNotDoneSyncing() {
        
        // given
        let sut = ForegroundOnlyHistorySynchronizationStatus(managedObjectContext: self.uiMOC, application: self.application)
        
        // when
        self.application.simulateApplicationWillResignActive()
        self.application.simulateApplicationDidBecomeActive()
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(sut.shouldDownloadFullHistory)
    }
}

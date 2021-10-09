////

import XCTest

class ZMUserSessionTests_Syncing: ZMUserSessionTestsBase {
    
    // MARK: Helpers
    
    class InitialSyncObserver : NSObject, ZMInitialSyncCompletionObserver {
        
        var didNotify : Bool = false
        var initialSyncToken : Any?
        
        init(context: NSManagedObjectContext) {
            super.init()
            initialSyncToken = ZMUserSession.addInitialSyncCompletionObserver(self, context: context)
        }
        
        func initialSyncCompleted() {
            didNotify = true
        }
    }
    
    
    // MARK: Slow Sync
    
    func testThatObserverSystemIsDisabledDuringSlowSync() {
        
        // given
        sut.didFinishSlowSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertFalse(sut.notificationDispatcher.isDisabled)
        
        // when
        sut.didStartSlowSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(sut.notificationDispatcher.isDisabled)
    }
    
    func testThatObserverSystemIsEnabledAfterSlowSync() {
        
        // given
        sut.didStartSlowSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertTrue(sut.notificationDispatcher.isDisabled)
        
        // when
        sut.didFinishSlowSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(sut.notificationDispatcher.isDisabled)
    }
    
    func testThatInitialSyncIsCompletedAfterSlowSync() {
        
        // given
        sut.didStartSlowSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertFalse(sut.hasCompletedInitialSync)
        
        // when
        sut.didFinishSlowSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(sut.hasCompletedInitialSync)
    }
    
    func testThatItNotifiesObserverWhenInitialIsSyncCompleted(){
        // given
        let observer = InitialSyncObserver(context: uiMOC)
        sut.didStartSlowSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertFalse(observer.didNotify)
        
        // when
        sut.didFinishSlowSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(observer.didNotify)
    }
    
    func testThatPerformingSyncIsStillOngoingAfterSlowSync() {
        
        // given
        sut.didStartSlowSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertTrue(sut.isPerformingSync)
        
        // when
        sut.didFinishSlowSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(sut.isPerformingSync)
    }
    
    // MARK: Quick Sync

    func testThatPerformingSyncIsFinishedAfterQuickSync() {
        
        // given
        sut.didStartQuickSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertTrue(sut.isPerformingSync)
        
        // when
        sut.didFinishQuickSync()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(sut.isPerformingSync)
    }
    
}

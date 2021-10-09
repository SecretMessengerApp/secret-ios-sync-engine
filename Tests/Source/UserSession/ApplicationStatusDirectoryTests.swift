//

import Foundation

@testable import WireSyncEngine

class ApplicationStatusDirectoryTests : MessagingTest {
    
    var sut : ApplicationStatusDirectory!
    
    override func setUp() {
        super.setUp()
        
        let cookieStorage = ZMPersistentCookieStorage()
        let mockApplication = ApplicationMock()
        
        sut = ApplicationStatusDirectory(withManagedObjectContext: syncMOC, cookieStorage: cookieStorage, requestCancellation: self, application: mockApplication, syncStateDelegate: self)
    }
    
    override func tearDown() {
        sut = nil
        
        super.tearDown()
    }
    
    func testThatOperationStatusIsUpdatedWhenCallStarts() {
        // given
        let note = NotificationInContext(name: CallStateObserver.CallInProgressNotification, context:uiMOC.notificationContext, userInfo: [CallStateObserver.CallInProgressKey : true ])
        
        // when
        note.post()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(sut.operationStatus.hasOngoingCall)
    }
    
    func testThatOperationStatusIsUpdatedWhenCallEnds() {
        // given
        sut.operationStatus.hasOngoingCall = true
        let note = NotificationInContext(name: CallStateObserver.CallInProgressNotification, context:uiMOC.notificationContext, userInfo: [CallStateObserver.CallInProgressKey : false ])
        
        // when
        note.post()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(sut.operationStatus.hasOngoingCall)
    }
    
}

extension ApplicationStatusDirectoryTests : ZMRequestCancellation {
    
    func cancelTask(with taskIdentifier: ZMTaskIdentifier) {
        // no-op
    }
    
}

extension ApplicationStatusDirectoryTests : ZMSyncStateDelegate {
    
    func didStartSlowSync() {
        // no-op
    }
    
    func didFinishSlowSync() {
        // no-op
    }
    
    func didStartQuickSync() {
        // no-op
    }
    
    func didFinishQuickSync() {
        // no-op
    }
    
    func didRegister(_ userClient: UserClient!) {
        // no-op
    }
    
    
}

//

import XCTest
import WireTesting

@testable import WireSyncEngine

class TestAVSLogger : AVSLogger {
    
    var messages : [String] = []
    
    func log(message: String) {
        messages.append(message)
    }
    
}

class SessionManagerAVSTests: ZMTBaseTest {
        
    func testLoggersReceiveLogMessages() {
        // given
        let logMessage = "123"
        let logger = TestAVSLogger()
        var token : Any? = SessionManager.addLogger(logger)
        XCTAssertNotNil(token)
        
        // when
        SessionManager.logAVS(message: logMessage)
        
        // then
        XCTAssertEqual(logger.messages, [logMessage])
        
        // cleanup
        token = nil
    }
    
    func testThatLogAVSMessagePostsNotification() {
        // given
        let logMessage = "123"
        
        // expect
        expectation(forNotification: NSNotification.Name("AVSLogMessageNotification"), object: nil) { (note) -> Bool in
            let message = note.userInfo?["message"] as? String
            return message == logMessage
        }
        
        // when
        SessionManager.logAVS(message: logMessage)
        
        // then
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
}

//

import XCTest
import WireTesting

@testable import WireSyncEngine

class BuildTypeTests: ZMTBaseTest {

    func testThatItParsesKnownBundleIDs() {
        // GIVEN
        let bundleIdsToTypes: [String: WireSyncEngine.BuildType] = ["com.wearezeta.zclient.ios": .production,
                                                                    "com.wearezeta.zclient-alpha": .alpha,
                                                                    "com.wearezeta.zclient.ios-development": .development,
                                                                    "com.wearezeta.zclient.ios-internal": .internal]
        
        bundleIdsToTypes.forEach { bundleId, expectedType in
            // WHEN
            let type = WireSyncEngine.BuildType(bundleID: bundleId)
            // THEN
            XCTAssertEqual(type, expectedType)
        }
    }
    
    func testThatItParsesUnknownBundleID() {
        // GIVEN
        let someBundleId = "com.mycompany.myapp"
        // WHEN
        let buildType = WireSyncEngine.BuildType(bundleID: someBundleId)
        // THEN
        XCTAssertEqual(buildType, WireSyncEngine.BuildType.custom(bundleID: someBundleId))
    }
    
    func testThatItReturnsTheCertName() {
        // GIVEN
        let type = WireSyncEngine.BuildType.alpha
        // WHEN
        let certName = type.certificateName
        // THEN
        XCTAssertEqual(certName, "com.wire.ent")
    }
    
    func testThatItReturnsBundleIdForCertNameIfCustom() {
        // GIVEN
        let type = WireSyncEngine.BuildType.custom(bundleID: "com.mycompany.myapp")
        // WHEN
        let certName = type.certificateName
        // THEN
        XCTAssertEqual(certName, "com.mycompany.myapp")
    }

}

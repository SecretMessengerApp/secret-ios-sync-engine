//


import Foundation
import XCTest
import WireTesting
@testable import WireSyncEngine


class RequestLoopAnalyticsTrackerTests: XCTestCase {

    func testThatItSanitizesUUIDsAndClientIDs() {
        let paths = [
            "/notifications?size=500&since=cfb40e1a-1096-11e7-bfff-22000b1081a7&client=95b2471202e2cda9&cancel_fallback=3c41e15a-1098-11e7-bfff-22000b017aef",
            "/notifications?size=500&since=c57202ca-2b28-11e7-bfff-22000ac3020a&client=cf114edfb492c778&cancel_fallback=cfa5f148-2b28-11e7-bfff-22000a568fd1",
            "/assets/07430c64-f376-4ecf-a114-85d04848de85?conv_id=49ca25cf-9181-4735-bfc5-1db26b7a49af",
            "/assets/6a295066-1ca9-43c8-8b9d-8f22c27f292e?conv_id=b453fbe0-d938-4e49-9739-7ea53c74a8ca",
            "/assets/e821d372-0bec-43e3-9c6a-ecfcfa995bdc?conv_id=70021ba4-487a-4967-b73b-aa950ea3b595",
            "/conversations/22df105c-75b5-4b42-8d05-25961bfef285/otr/messages",
            "/conversations/8812f63e-0f88-4249-9758-e8ecf4bf2c42/otr/messages?report_missing=84d29540-8b82-4adb-a4ba-f84adffef7e7",
            "/assets/67feb2f3-3118-4807-9c40-a4c86235c456?conv_id=dcb383ff-def6-47b6-92c8-bfc88075aba8",
            "/assets/85b16732-0617-4dd9-a043-c18123d39ea7?conv_id=cdf377c2-21c9-4649-83cb-c03ef54ba354",
            "/notifications?size=500&since=b610ca0a-0eef-11e7-bfff-22000b1081a7&client=37cbf257edc68492&cancel_fallback=b7b3ac32-0ef0-11e7-bfff-22000b18c377",
            "/conversations/4ec7f78d-92d4-4adc-acef-a5fd1ce2d05d/otr/messages?report_missing=69607340-332f-44b3-af7e-64d5101935d9",
            "/assets/793ed60b-6a6f-41f1-be20-fae17fd83148?conv_id=b98cc1a7-ff98-4376-bdbe-0f806e5c4522",
            "/assets/19ad9766-91e8-4d5a-8f7a-9e9da0a57b19?conv_id=b98cc1a7-ff98-4376-bdbe-0f806e5c4522",
            "/conversations/58128c2d-8181-45d9-91d5-d4aa31a637f8/otr/messages?report_missing=e3cfe44e-f4a9-4c9a-a759-8b718f3dfaf6",
            "/assets/v3/3-2-8db1e0ad-77a0-47c8-ad5d-fa479f40872f",
            "/assets/v3",
            "/users?ids=58128c2d-8181-45d9-91d5-d4aa31a637f8,58128c2d-8181-45d9-91d5-d4aa31a637f8,58128c2d-8181-45d9-91d5-d4aa31a637f8&foo=true"
        ]

        let expected = [
            "/notifications?size=500&since={id}&client={id}&cancel_fallback={id}",
            "/notifications?size=500&since={id}&client={id}&cancel_fallback={id}",
            "/assets/{id}?conv_id={id}",
            "/assets/{id}?conv_id={id}",
            "/assets/{id}?conv_id={id}",
            "/conversations/{id}/otr/messages",
            "/conversations/{id}/otr/messages?report_missing={id}",
            "/assets/{id}?conv_id={id}",
            "/assets/{id}?conv_id={id}",
            "/notifications?size=500&since={id}&client={id}&cancel_fallback={id}",
            "/conversations/{id}/otr/messages?report_missing={id}",
            "/assets/{id}?conv_id={id}",
            "/assets/{id}?conv_id={id}",
            "/conversations/{id}/otr/messages?report_missing={id}",
            "/assets/v3/3-2-{id}",
            "/assets/v3",
            "/users?ids={id}&foo=true"
        ]

        zip(expected, paths.map { $0.sanitizePath() }).forEach { (expected, actual) in
            XCTAssertEqual(actual, expected)
        }
    }


    func testThatItExcludesIsTyping() {
        let analytics = MockAnalytics()
        let sut = RequestLoopAnalyticsTracker(with: analytics)
        let typingPath = "/conversations/58128c2d-8181-45d9-91d5-d4aa31a637f8/typing"
        XCTAssertFalse(sut.tag(with: typingPath))
        XCTAssertTrue(sut.tag(with: "/assets/v3"))
    }

}

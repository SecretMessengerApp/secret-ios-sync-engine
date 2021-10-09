// 


import Foundation
import WireTesting
import WireDataModel


func AssertKeyPathDictionaryHasOptionalValue<T: NSObject>(_ dictionary: @autoclosure () -> [WireDataModel.StringKeyPath: T?], key: @autoclosure () -> WireDataModel.StringKeyPath, expected: @autoclosure () -> T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if let v = dictionary()[key()] {
        AssertOptionalEqual(v, expression2: expected(), message, file: file, line: line)
    } else {
        XCTFail("No value for \(key()). \(message)", file: file, line: line)
    }
}


func AssertKeyPathDictionaryHasOptionalNilValue<T: NSObject>(_ dictionary: @autoclosure () -> [WireDataModel.StringKeyPath: T?], key: @autoclosure () -> WireDataModel.StringKeyPath, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if let v = dictionary()[key()] {
        AssertOptionalNil(v, message , file: file, line: line)
    } else {
        XCTFail("No value for \(key()). \(message)", file: file, line: line)
    }
}

// 


#import <XCTest/XCTest.h>


/// Pass "-XCTestObserverClass MemoryLeaksObserver" as launch arguments to use
///
/// N.B.: XCTestObserver is deprecated.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface MemoryLeaksObserver : XCTestObserver
@end
#pragma clang diagnostic pop

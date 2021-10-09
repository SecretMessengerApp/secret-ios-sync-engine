// 


#import <Foundation/Foundation.h>



@interface NSOperationQueue (ZMTimingTests)

- (void)waitUntilAllOperationsAreFinishedWithTimeout:(NSTimeInterval)timeout;
- (void)waitAndSpinMainLoopUntilAllOperationsAreFinishedWithTimeout:(NSTimeInterval)timeout;
- (void)syncBlockWithReasonableTimeout:(void (^)(void))block;
- (void)syncWithTimeout:(NSTimeInterval)timeout block:(void (^)(void))block;

@end

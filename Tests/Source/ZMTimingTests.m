// 


#import "MessagingTest.h"
#import "ZMTimingTests.h"

@implementation NSOperationQueue (ZMTimingTests)

- (void)waitUntilAllOperationsAreFinishedWithTimeout:(NSTimeInterval)timeout;
{
    timeout = [MessagingTest timeToUseForOriginalTime:timeout];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self waitUntilAllOperationsAreFinished];
        dispatch_semaphore_signal(sem);
    });
    dispatch_time_t t = dispatch_walltime(DISPATCH_TIME_NOW, llround(timeout * NSEC_PER_SEC));
    if (dispatch_semaphore_wait(sem, t) != 0) {
        NSLog(@"Timed out while waiting for queue \"%@\". Call stack:\n%@",
              self.name, [NSThread callStackSymbols]);
        exit(-1);
    }
}

- (void)waitAndSpinMainLoopUntilAllOperationsAreFinishedWithTimeout:(NSTimeInterval)timeout
{
    timeout = [MessagingTest timeToUseForOriginalTime:timeout];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    
    const NSTimeInterval lockInterval = 0.01;
    const NSTimeInterval spinInterval = 0.01;
    
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    while(YES) {
        
        // final deadline
        if([[NSDate dateWithTimeIntervalSinceNow:0] compare:deadline] == NSOrderedDescending) {
            NSLog(@"Timed out while waiting for queue \"%@\". Call stack:\n%@",
                  self.name, [NSThread callStackSymbols]);
            exit(-1);
        }
        
        // wait
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [self waitUntilAllOperationsAreFinished];
            dispatch_semaphore_signal(sem);
        });
        
        // did signal?
        dispatch_time_t t = dispatch_walltime(DISPATCH_TIME_NOW, llround(lockInterval * NSEC_PER_SEC));
        if (dispatch_semaphore_wait(sem, t) != 0) {
            NSDate *end = [NSDate dateWithTimeIntervalSinceNow:spinInterval];
            while ([NSDate timeIntervalSinceReferenceDate] < [end timeIntervalSinceReferenceDate]) {
                [MessagingTest performRunLoopTick];
            }
            continue;
        }
        else {
            break;
        }
    }
}

- (void)syncBlockWithReasonableTimeout:(void (^)(void))block;
{
    [self syncWithTimeout:[MessagingTest timeToUseForOriginalTime:0.2] block:block];
}

- (void)syncWithTimeout:(NSTimeInterval)timeout block:(void (^)(void))block;
{
    [self addOperationWithBlock:block];
    [self waitUntilAllOperationsAreFinishedWithTimeout:timeout];
}

@end

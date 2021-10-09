// 


#import "MemoryLeaksObserver.h"


@interface Leak : NSObject

@property (nonatomic) intptr_t address;
@property (nonatomic) size_t length;
@property (nonatomic, copy) NSString *zoneName;
@property (nonatomic, copy) NSString *information;

@end



@implementation MemoryLeaksObserver

- (void)startObserving;
{
    int canSetABreakpointHere = 4;
    (void) canSetABreakpointHere;
}

#if (!TARGET_OS_IPHONE)
- (void)stopObserving;
{
    [(NSFileHandle *)[NSFileHandle fileHandleWithStandardError] writeData:[[self leaksOutput] dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSDictionary *)environmentForTasks
{
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    NSArray *keys = [[env allKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF BEGINSWITH \"Malloc\""]];
    [env removeObjectsForKeys:keys];
    return env;
}

- (NSString *)leaksOutput
{
    NSLog(@"Running leaks...");
    int const pid = [[NSProcessInfo processInfo] processIdentifier];
    
    NSTask *leaks = [[NSTask alloc] init];
    leaks.environment = [self environmentForTasks];
    leaks.launchPath = @"/usr/bin/xcrun";
    leaks.arguments = @[@"leaks", @"--nocontext", [NSString stringWithFormat:@"%d", pid]];
    NSPipe *pipe = [NSPipe pipe];
    leaks.standardOutput = pipe;
    [leaks launch];
    NSMutableData *leaksOutput = [NSMutableData data];
    while (leaks.isRunning) {
        NSData *d = pipe.fileHandleForReading.availableData;
        if (d != nil) {
            [leaksOutput appendData:d];
        }
    }
    return [[NSString alloc] initWithData:leaksOutput encoding:NSUTF8StringEncoding];
}
#endif

@end

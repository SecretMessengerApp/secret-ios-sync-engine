// 


#import "MessagingTest.h"
#import "ZMBlacklistDownloader.h"
#import "ZMBlacklistVerificator+Testing.h"
#import "WireSyncEngine_iOS_Tests-Swift.h"

@import WireTransport;

@class MockBlacklistDownloader;
static MockBlacklistDownloader *generatedDownloader;

@interface ZMBlacklistVerificatorTest : MessagingTest
@end


@interface MockBlacklistDownloader : NSObject

@property (nonatomic) NSTimeInterval downloadInterval;
@property (nonatomic, copy) void (^completionHandler)(NSString *, NSArray *);

@end


@implementation MockBlacklistDownloader

- (instancetype)initWithDownloadInterval:(NSTimeInterval)downloadInterval
                             environment:(id<BackendEnvironmentProvider>)environment
                            workingGroup:(ZMSDispatchGroup * __unused)group
                             application:(id<ZMApplication>)application
                       completionHandler:(void (^)(NSString *minVersion, NSArray *excludedVersions))completionHandler {
    self = [super init];
    if(self) {
        NOT_USED(application);
        NOT_USED(environment);
        generatedDownloader = self;
        self.downloadInterval = downloadInterval;
        self.completionHandler = completionHandler;
    }
    return self;
}

@end


@implementation ZMBlacklistVerificatorTest

- (void)setUp
{
    [super setUp];
    generatedDownloader = nil;
}

- (void)tearDown
{
    generatedDownloader = nil;
    [super tearDown];
}

- (BOOL)checkVersion:(NSString *)version againstMinVersion:(NSString *)minVersion andExcludedVersions:(NSArray *)excludedVersions
{
    __block BOOL verificationResult = NO;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler called"];
    ZMBlacklistVerificator * sut = [[ZMBlacklistVerificator alloc] initWithCheckInterval:1000
                                                                                 version:version
                                                                             environment:[[MockEnvironment alloc] init]
                                                                            workingGroup:self.syncMOC.dispatchGroup
                                                                             application:self.application
                                                                       blacklistCallback:^(BOOL result) {
        verificationResult = result;
        [expectation fulfill];
    } blacklistClass:MockBlacklistDownloader.class];
    
    XCTAssertNotNil(sut);
    XCTAssertNotNil(generatedDownloader.completionHandler);
    if(generatedDownloader.completionHandler == nil) {
        return NO;
    }
    generatedDownloader.completionHandler(minVersion, excludedVersions);
    XCTAssertTrue([self waitForCustomExpectationsWithTimeout:0.2]);
    generatedDownloader = nil;
    return verificationResult;
}

- (void)testVersionStringsAreComparedInNumericOrder
{
    XCTAssertTrue([self checkVersion:@"11" againstMinVersion:@"111" andExcludedVersions:nil]);
    XCTAssertFalse([self checkVersion:@"111" againstMinVersion:@"111" andExcludedVersions:nil]);
    XCTAssertFalse([self checkVersion:@"112" againstMinVersion:@"111" andExcludedVersions:nil]);
    XCTAssertFalse([self checkVersion:@"1111" againstMinVersion:@"111" andExcludedVersions:nil]);
    XCTAssertTrue([self checkVersion:@"1.1" againstMinVersion:@"1.1.1" andExcludedVersions:nil]);
    XCTAssertTrue([self checkVersion:@"1.1.0" againstMinVersion:@"1.1.1" andExcludedVersions:nil]);
    XCTAssertFalse([self checkVersion:@"1.1.1" againstMinVersion:@"1.1.1" andExcludedVersions:nil]);
    XCTAssertFalse([self checkVersion:@"1.1.2" againstMinVersion:@"1.1.1" andExcludedVersions:nil]);

    XCTAssertTrue([self checkVersion:@"1.0.1" againstMinVersion:@"1.1.1" andExcludedVersions:nil]);
    XCTAssertFalse([self checkVersion:@"1.2.1" againstMinVersion:@"1.1.1" andExcludedVersions:nil]);

    NSArray *versionsWith11 = @[@"abc",@"11",@"fg"];
    NSArray *versionsWithout11 = @[@"111",@"1"];
    NSArray *versionWith11 = @[@"11"];
    NSArray *empty = @[];
    // excluded versions
    XCTAssertFalse([self checkVersion:@"11" againstMinVersion:nil andExcludedVersions:versionsWithout11]);
    XCTAssertTrue([self checkVersion:@"11" againstMinVersion:nil andExcludedVersions:versionsWith11]);
    XCTAssertTrue([self checkVersion:@"11" againstMinVersion:nil andExcludedVersions:versionWith11]);
    XCTAssertFalse([self checkVersion:@"11" againstMinVersion:nil andExcludedVersions:empty]);
    
    // excluded version and min version
    XCTAssertFalse([self checkVersion:@"11" againstMinVersion:@"1" andExcludedVersions:versionsWithout11]);
    XCTAssertTrue([self checkVersion:@"11" againstMinVersion:@"1" andExcludedVersions:versionsWith11]);
    XCTAssertTrue([self checkVersion:@"11" againstMinVersion:@"1" andExcludedVersions:versionWith11]);
    XCTAssertFalse([self checkVersion:@"11" againstMinVersion:@"1" andExcludedVersions:empty]);
    XCTAssertTrue([self checkVersion:@"11" againstMinVersion:@"20" andExcludedVersions:versionsWithout11]);
}


@end

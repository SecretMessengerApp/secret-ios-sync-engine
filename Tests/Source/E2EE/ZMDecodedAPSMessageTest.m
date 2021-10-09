// 


@import WireTesting;
#import <CommonCrypto/CommonCrypto.h>
#import "MessagingTest.h"
#import "ZMAPSMessageDecoder.h"

@interface ZMAPSMessageDecoderTests : MessagingTest
@property (nonatomic) NSData *encryptionKey;
@property (nonatomic) ZMAPSMessageDecoder *sut;

@end

@implementation ZMAPSMessageDecoderTests

- (void)setUp {
    [super setUp];
    self.sut = [[ZMAPSMessageDecoder alloc] initWithEncryptionKey:self.encryptionKey macKey:self.encryptionKey];
}

- (void)tearDown {
    self.sut = nil;
    [super tearDown];
}

- (NSString *)encryptedBase64DataString
{
    return @"0pefteRc9xI/0I0bcWu/2ZsBouVlRL6RFm1+zqKYE9kdDR8pn00abaaHnm4dU1C95ay4/A0/enqDOi8ob6UjLfLLyT5+OtWmuct+SDw9pJche1ma5aPcMjYAnr3hLV0Jc30U/M3yO1j6jx7hP+P3p+ET9XbpVRZE1wyxHGTA36E=";
}

- (NSData *)encryptedData
{
    NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:self.encryptedBase64DataString options:0];
    return encryptedData;
}

- (NSDictionary *)expectedPayload
{
    return @{ @"data" :
                  @{
                      @"id": @"c2ece402-676b-11e5-8001-28cfe91d3c81",
                      @"payload": @[@{@"type": @"test"}],
                      @"transient" : @0
                    }
              };
}

- (NSDictionary *)pushNotificationIsValid:(BOOL)isValid
{
    NSString *macHash = isValid ? @"3dzH+JpcHIQf5mLTJ5cp+aNSLkYCpoaGdaq9i0os9d8=" : @"";
    
    NSDictionary *payload = @{@"aps" : @{@"alert": @{@"loc-args": @[],
                                                     @"loc-key": @"push.notification.new_message"}
                                         },
                              @"data": @{@"data" : self.encryptedBase64DataString,
                                         @"mac": macHash,
                                         @"type": @"cipher"
                                         }
                              };
    return payload;
}

- (NSData *)encryptionKey
{
    NSString *keyString = @"MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=";
    NSData *encryptionKeyData = [[NSData alloc] initWithBase64EncodedString:keyString options:0];
    return encryptionKeyData;
}

- (NSData *)validMacKey
{
    return self.encryptionKey;
}

- (NSData *)invalidMacKey
{
    NSString *invalidKeyString = @"YWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWE=";
    return [[NSData alloc] initWithBase64EncodedString:invalidKeyString options:0];
}

- (void)testThatItDecryptsAMessageCorrectly
{
    // given
    NSData *encodedData = self.encryptedData;

    // when
    NSData *decryptedData = [self.sut decodeData:encodedData];
    
    // then
    XCTAssertNotNil(decryptedData);
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:decryptedData options:NSJSONReadingAllowFragments error:nil];
    XCTAssertEqualObjects(json, self.expectedPayload);
}

- (void)testThatItReturnsNilIfTheHashIsWrong
{
    // given
    NSDictionary *invalidPush = [self pushNotificationIsValid:NO];
    
    // when
    __block NSDictionary *result;
    [self performIgnoringZMLogError:^{
        result = [self.sut decodeAPSPayload:invalidPush[@"data"]];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertNil(result);
}

- (void)testThatItReturnsTheEventPayloadIfTheHashIsCorrect
{
    // given
    NSDictionary *validPush = [self pushNotificationIsValid:YES];
    
    // when
    NSDictionary *result = [self.sut decodeAPSPayload:validPush[@"data"]];
    
    // then
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result, self.expectedPayload);
}





@end

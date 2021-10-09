// 


@import CoreFoundation;
@import WireSystem;
@import WireUtilities;
@import WireTransport;

#import <CommonCrypto/CommonCrypto.h>
#import "ZMAPSMessageDecoder.h"


static NSString * const DataKey = @"data";
static NSString * const MacKey = @"mac";

//static const uint8_t IV_DATA_SIZE = 16;

@interface ZMAPSMessageDecoder ()

@property (nonatomic) NSData *encryptionKey;
@property (nonatomic) NSData *macKey;

@end



@implementation ZMAPSMessageDecoder

- (instancetype)initWithEncryptionKey:(NSData *)encryptionKey macKey:(NSData *)macKey;
{
    self = [super init];
    if(self) {
        RequireString(encryptionKey.length == kCCKeySizeAES256, "Encryption key has wrong length (%lu vs. expected %d)", (unsigned long)encryptionKey.length, kCCKeySizeAES256);

        self.encryptionKey = encryptionKey;
        self.macKey = macKey;
    }
    return self;
}

- (NSDictionary *)decodeAPSPayload:(NSDictionary *)payload
{
    NSString *hashString = [payload optionalStringForKey:MacKey];
    NSString *dataString = [payload optionalStringForKey:DataKey];
    
    NSData *hashData = [[NSData alloc] initWithBase64EncodedString:hashString options:0];
    NSData *encodedData = [[NSData alloc] initWithBase64EncodedString:dataString options:0];
    
    if (![self isValidHash:hashData encodedData:encodedData]) {
        ZMLogError(@"Provided invalid hash: %@ for data: %@ with mac key: %@ encryption key: %@", hashString, dataString, self.macKey, self.encryptionKey);
        return nil;
    }
    
    NSData *decodedData = [self decodeData:encodedData];
    if (decodedData == nil){
        ZMLogError(@"Invalid payload in APS: %@", payload);
        return nil;
    }
    
    NSError *error;
    NSDictionary *eventPayload = [NSJSONSerialization JSONObjectWithData:decodedData options:0 error:&error];
    if (error != nil) {
        ZMLogError(@"Unable to create JSON from payload in APS with error: %@", error);
        return nil;
    }
    return eventPayload;
}

- (BOOL)isValidHash:(NSData *)expectedHash encodedData:(NSData *)encodedData
{
    NSData *calculatedMac = [self hashDataForEncodedData:encodedData];
    if ([calculatedMac isEqualToData:expectedHash]) {
        return YES;
    }
    return NO;
}

- (NSData *)hashDataForEncodedData:(NSData *)encodedData
{
    return [encodedData zmHMACSHA256DigestWithKey:self.macKey];
}

- (NSData *)decodeData:(NSData *)data
{
    return [data zmDecryptPrefixedPlainTextIVWithKey:self.encryptionKey];
}

@end


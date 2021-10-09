// 


#import <Foundation/Foundation.h>

@interface ZMAPSMessageDecoder : NSObject

- (instancetype)initWithEncryptionKey:(NSData *)encryptionKey macKey:(NSData *)macKey;
- (NSData *)decodeData:(NSData *)data;
- (NSDictionary *)decodeAPSPayload:(NSDictionary *)payload;

@end

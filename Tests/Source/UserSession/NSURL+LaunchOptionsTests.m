// 


#import "MessagingTest.h"
#import "NSURL+LaunchOptions.h"

@interface NSURL_LaunchOptionsTests : MessagingTest

@end

@implementation NSURL_LaunchOptionsTests

- (NSString *)validInvitationToConnectToken
{
    return @"YjXsjDOfIEMtKPVnlNwHnzmn8J2R7Aika0LVMl1nCnM";
}

- (NSURL *)appendInvitationToConnectTokenToURLString:(NSString *)string
{
    return [NSURL URLWithString:[string stringByAppendingString:self.validInvitationToConnectToken]];
}

- (void)testThatItDetectsValidURLForPhoneVerification
{
    XCTAssertTrue([[NSURL URLWithString:@"wire://verify-phone/123456"] isURLForPhoneVerification]);
    
}

- (void)testThatItRejectsInvalidURLForPhoneVerification
{
    // wrong schema
    XCTAssertFalse([[NSURL URLWithString:@"http://verify-phone/123456"] isURLForPhoneVerification]);
    XCTAssertFalse([[NSURL URLWithString:@"https://verify-phone/123456"] isURLForPhoneVerification]);
    
    // wrong host
    XCTAssertFalse([[NSURL URLWithString:@"wire://verify-email/123456"] isURLForPhoneVerification]);
    
    // missing code
    XCTAssertFalse([[NSURL URLWithString:@"wire://verify-phone/"] isURLForPhoneVerification]);
    XCTAssertFalse([[NSURL URLWithString:@"wire://verify-phone"] isURLForPhoneVerification]);
}

- (void)testThatItExtractsPhoneVerificationCodeFromAValidURL
{
    // given
    NSString *code = @"123456";
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"wire://verify-phone/%@", code]];
    
    // when
    NSString *extractedCode = [URL codeForPhoneVerification];
    
    // then
    XCTAssertEqualObjects(extractedCode, code);
}

- (void)testThatItExtractsPhoneVerificationCodeFromAValidURLWithQueryString
{
    // given
    NSString *code = @"123456";
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"wire://verify-phone/%@?parameter=1", code]];
    
    // when
    NSString *extractedCode = [URL codeForPhoneVerification];
    
    // then
    XCTAssertEqualObjects(extractedCode, code);
}

- (void)testThatItDoesNotExtractPhoneVerificationCodeFromAInvalidURL
{
    // given
    NSString *code = @"123456";
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"wire://verify-email/%@", code]];
    
    // when
    NSString *extractedCode = [URL codeForPhoneVerification];
    
    // then
    XCTAssertNil(extractedCode);
}

@end

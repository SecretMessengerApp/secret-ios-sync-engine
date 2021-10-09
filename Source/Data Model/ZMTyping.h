// 


@import Foundation;
@import WireUtilities;
@class ZMUser;
@class ZMConversation;


#if DEBUG
extern NSTimeInterval ZMTypingDefaultTimeout;
#else
extern const NSTimeInterval ZMTypingDefaultTimeout;
#endif
/// We only send typing events to the backend every ZMTypingDefaultTimeout / ZMTypingRelativeSendTimeout seconds.
extern const NSTimeInterval ZMTypingRelativeSendTimeout;



@interface ZMTyping : NSObject <TearDownCapable>

@property (nonatomic) NSTimeInterval timeout;

- (instancetype)initWithUserInterfaceManagedObjectContext:(NSManagedObjectContext *)uiMOC syncManagedObjectContext:(NSManagedObjectContext *)syncMOC;

- (void)setIsTyping:(BOOL)isTyping forUser:(ZMUser *)user inConversation:(ZMConversation *)conversation;

- (void)tearDown;

@end

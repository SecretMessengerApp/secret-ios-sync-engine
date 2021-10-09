// 


@import WireDataModel;
@import WireMockTransport;
@import WireTesting;

@implementation ZMConversation (Testing)

- (void)assertMatchesConversation:(MockConversation *)conversation failureRecorder:(ZMTFailureRecorder *)failureRecorder;
{
    if (conversation == nil) {
        [failureRecorder recordFailure:@"ZMConversation is <nil>"];
        return;
    }
    
    __block NSString *mockMame;
    __block NSString *mockCreatorIdentifier;
    __block NSString *mockIdentifier;
    __block NSMutableSet<NSString *> *mockActiveUsersUUID;
    [conversation.managedObjectContext performBlockAndWait:^{
        mockMame = conversation.name;
        mockCreatorIdentifier = conversation.creator.identifier;
        mockIdentifier = conversation.identifier;
        mockActiveUsersUUID = [NSMutableSet setWithArray:[conversation.activeUsers mapWithBlock:^id(MockUser *activeUser) {
            return activeUser.identifier;
        }].array];
        [mockActiveUsersUUID removeObject:conversation.selfIdentifier];
    }];
    
    if (!(self.userDefinedName == mockMame || [self.userDefinedName isEqualToString:mockMame])) {
        [failureRecorder recordFailure:@"Name doesn't match '%@' != '%@'",
         self.userDefinedName, mockMame];
    }
    if (!([self.creator.remoteIdentifier isEqual:[mockCreatorIdentifier UUID]])) {
        [failureRecorder recordFailure:@"Creator doesn't match '%@' != '%@'",
                       self.creator.remoteIdentifier.transportString, mockCreatorIdentifier];
    }

    NSMutableSet *activeUsersUUID = [NSMutableSet set];
    for(ZMUser *user in self.lastServerSyncedActiveParticipants) {
        [activeUsersUUID addObject:user.remoteIdentifier.transportString];
    }
    
    if (![activeUsersUUID isEqual:mockActiveUsersUUID]) {
        [failureRecorder recordFailure:@"Active users don't match {%@} != {%@}",
         [[activeUsersUUID.allObjects valueForKey:@"transportString"] componentsJoinedByString:@", "],
         [[mockActiveUsersUUID.allObjects valueForKey:@"transportString"] componentsJoinedByString:@", "]];
    }
    
    if (![self.remoteIdentifier isEqual:[mockIdentifier UUID]]) {
        [failureRecorder recordFailure:@"Remote ID doesn't match '%@' != '%@'",
         self.remoteIdentifier.transportString, mockIdentifier];
    }
}
- (void)setUnreadCount:(NSUInteger)count;
{
    self.lastServerTimeStamp = [NSDate date];
    self.lastReadServerTimeStamp = self.lastServerTimeStamp;
    
    for (NSUInteger idx = 0; idx < count; idx++) {
        ZMMessage *message = [[ZMMessage alloc] initWithNonce:NSUUID.createUUID managedObjectContext:self.managedObjectContext];
        message.serverTimestamp = [self.lastServerTimeStamp dateByAddingTimeInterval:5];
        self.lastServerTimeStamp = message.serverTimestamp;
    }
}

- (void)addUnreadMissedCall
{
    ZMSystemMessage *systemMessage = [[ZMSystemMessage alloc] initWithNonce:NSUUID.createUUID managedObjectContext:self.managedObjectContext];
    systemMessage.systemMessageType = ZMSystemMessageTypeMissedCall;
    systemMessage.serverTimestamp = self.lastReadServerTimeStamp ?
    [self.lastReadServerTimeStamp dateByAddingTimeInterval:1000] :
    [NSDate dateWithTimeIntervalSince1970:1231234];
    [self appendMessage:systemMessage];
}

- (void)setHasExpiredMessage:(BOOL)hasUnreadUnsentMessage
{
    self.hasUnreadUnsentMessage = hasUnreadUnsentMessage;
}

@end


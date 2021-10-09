// 


@import WireDataModel;


@interface NSManagedObjectContext (TestHelpers)

- (void)performGroupedBlockAndWaitWithReasonableTimeout:(dispatch_block_t)block;

@end

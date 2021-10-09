// 


@import Foundation;
@import WireRequestStrategy;

@class ApplicationStatusDirectory;
@protocol PreviouslyReceivedEventIDsCollection;
@protocol ZMApplication;

@interface ZMMissingUpdateEventsTranscoder : ZMAbstractRequestStrategy <ZMObjectStrategy>

@property (nonatomic, readonly) BOOL hasLastUpdateEventID;
@property (nonatomic, readonly) BOOL isDownloadingMissingNotifications;
@property (nonatomic, readonly) NSUUID *lastUpdateEventID;

- (instancetype)initWithSyncStrategy:(ZMSyncStrategy *)strategy
previouslyReceivedEventIDsCollection:(id<PreviouslyReceivedEventIDsCollection>)eventIDsCollection
                         application:(id <ZMApplication>)application
                   applicationStatus:(ApplicationStatusDirectory *)applicationStatus;

- (void)startDownloadingMissingNotifications;

- (NSUUID *)processUpdateEventsAndReturnLastNotificationIDFromPayload:(id<ZMTransportData>)payload syncStrategy:(ZMSyncStrategy *)syncStrategy;


@end

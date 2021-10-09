// 


@import WireDataModel;

@interface MockEntity : ZMManagedObject

@property (nonatomic) NSUUID *remoteIdentifier;
@property (nonatomic) int64_t modifiedDataFields;

@property (nonatomic) NSUUID *testUUID;
@property (nonatomic) int16_t field;
@property (nonatomic) NSString *field2;
@property (nonatomic) NSString *field3;

@property (nonatomic) NSMutableSet *mockEntities;

@end

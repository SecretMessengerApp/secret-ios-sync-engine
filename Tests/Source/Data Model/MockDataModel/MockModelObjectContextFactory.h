// 



#import <Foundation/Foundation.h>

@class NSManagedObjectContext;
@class NSPersistentStoreCoordinator;
@class NSManagedObjectModel;



@interface MockModelObjectContextFactory : NSObject

+ (NSManagedObjectContext *)alternativeMocForPSC:(NSPersistentStoreCoordinator *)psc;

+ (NSManagedObjectContext *)testContext;

+ (NSManagedObjectModel *)loadManagedObjectModel;

@end

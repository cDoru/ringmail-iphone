//
//  RemoteModel.h
//  linphone
//
//  Created by Mike Frager on 10/30/13.
//
//

#import <Foundation/Foundation.h>

@interface RemoteModel : NSObject {
@private
    NSNumber *contactId;
    NSDate *tsUpdated;
    NSString *primaryUri;
    NSNumber *ringMailuser;
}

@property (copy) NSNumber *contactId;
@property (copy) NSDate *tsUpdated;
@property (copy) NSNumber *ringMailUser;
@property (copy) NSString *primaryUri;

- (void)create;
+ (RemoteModel*)read:(NSNumber*)id;
- (void)update;
- (void)delete;
+ (void)deleteAll;
+ (BOOL)hasContactId:(NSNumber *)num;
+ (BOOL)hasRingMail:(NSNumber *)num;
+ (void)getRingMailContacts:(NSMutableDictionary *)dict;

@end

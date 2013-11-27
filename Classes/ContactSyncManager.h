//
//  ContactSyncManager.h
//  linphone
//
//  Created by Mike Frager on 7/21/13.
//
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

#import "FastAddressBook.h"
#import "Utils.h"

@interface ContactSyncManager : NSObject {
    @private
    ABAddressBookRef addressBook;
    NSArray *contacts;
    NSString *login;
    NSString *pass;
    NSDateFormatter *dateFormatter;
    NSLocale *enUSPOSIXLocale;
}

-(void) syncContacts:(NSString*) username password:(NSString*) password;
-(void) setRemoteContact:(ABRecordRef)lPerson login:(NSString*)username password:(NSString*)password;
-(void) getRemoteData:(NSArray*)contactIds favorites:(NSArray *)favs login:(NSString*) username password:(NSString*) password;
-(void) getRemoteFavorites:(NSArray *)favs login:(NSString*) username password:(NSString*) password;

@end

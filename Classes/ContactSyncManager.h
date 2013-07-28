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
}

-(void) syncContacts:(NSString*) username password:(NSString*) password;

@end

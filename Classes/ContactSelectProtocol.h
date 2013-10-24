//
//  ContactSelectProtocol.h
//  linphone
//
//  Created by Mike Frager on 10/23/13.
//
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

@protocol ContactSelectProtocol <NSObject>

- (void) contactSelected:(ABRecordRef)contact;

@end

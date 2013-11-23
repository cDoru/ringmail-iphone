/* ContactsTableViewController.m
 *
 * Copyright (C) 2012  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or   
 *  (at your option) any later version.                                 
 *                                                                      
 *  This program is distributed in the hope that it will be useful,     
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of      
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       
 *  GNU General Public License for more details.                
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */     

#import "ContactsTableViewController.h"
#import "UIContactCell.h"
#import "LinphoneManager.h"
#import "PhoneMainView.h"
#import "UACellBackgroundView.h"
#import "UILinphone.h"
#import "Utils.h"
#import "SMRotaryImage.h"
#import "RemoteModel.h"
#import "FavoritesModel.h"

@implementation ContactsTableViewController

@synthesize delegate;
@synthesize filter;

static void sync_address_book (ABAddressBookRef addressBook, CFDictionaryRef info, void *context);

#pragma mark - Lifecycle Functions

- (void)initContactsTableViewController {
    addressBookMap  = [[OrderedDictionary alloc] init];
    avatarMap = [[NSMutableDictionary alloc] init];
    ringMailMap = [[NSMutableDictionary alloc] init];
    favMap = [[NSMutableDictionary alloc] init];
    NSError *error = nil;
    addressBook = ABAddressBookCreateWithOptions(NULL, (CFErrorRef *)&error);
    ABAddressBookRegisterExternalChangeCallback(addressBook, sync_address_book, self);
    delegate = nil;
    filter = [[NSString alloc] initWithString:@""];
}

- (id)init {
    self = [super init];
    if (self) {
		[self initContactsTableViewController];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
		[self initContactsTableViewController];
	}
    return self;
}	

- (void)dealloc {
    ABAddressBookUnregisterExternalChangeCallback(addressBook, sync_address_book, self);
    CFRelease(addressBook);
    [addressBookMap release];
    [avatarMap release];
    [ringMailMap release];
    [favMap release];
    [filter release];
    [super dealloc];
}


#pragma mark - 

- (void)setFilter:(NSString *)aFilter {
    if([filter isEqualToString:aFilter]) {
        return;
    }
    filter = aFilter;
    [self loadData];
}


- (void)loadData {
    [LinphoneLogger logc:LinphoneLoggerLog format:"Load contact list"];
    @synchronized (addressBookMap) {
        
        // Read RingMail databases
        [RemoteModel getRingMailContacts:ringMailMap];
        [FavoritesModel getFavoriteContacts:favMap];
        
        // Reset Address book
        [addressBookMap removeAllObjects];
        
        NSArray *lContacts = (NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook);
        for (id lPerson in lContacts) {
            BOOL add = true;
            if([ContactSelection getSipFilter] || [ContactSelection getEmailFilter]) {
                add = false;
            }
            if([ContactSelection getSipFilter]) {
                ABMultiValueRef lMap = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonInstantMessageProperty);
                for(int i = 0; i < ABMultiValueGetCount(lMap); ++i) {
                    CFDictionaryRef lDict = ABMultiValueCopyValueAtIndex(lMap, i);
                    if(CFDictionaryContainsKey(lDict, kABPersonInstantMessageServiceKey)) {
                        CFStringRef serviceKey = CFDictionaryGetValue(lDict, kABPersonInstantMessageServiceKey);
                        if(CFStringCompare((CFStringRef)@"SIP", serviceKey, kCFCompareCaseInsensitive) == 0) {
                            add = true;
                        }
                    } else {
                        NSString* usernameKey = CFDictionaryGetValue(lDict, kABPersonInstantMessageUsernameKey);
                        if([usernameKey hasPrefix:@"sip:"]) {
                            add = true;
                        }
                    }
                    CFRelease(lDict);
                }
            }
            if ((add == false) && [ContactSelection getEmailFilter]) {
                ABMultiValueRef lMap = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonEmailProperty);
                if (ABMultiValueGetCount(lMap) > 0) {
                    add = true;
                }
            }
            
            // Check for filter
            if ([filter length] > 0)
            {
                NSNumber *recordId = [NSNumber numberWithInteger:ABRecordGetRecordID((ABRecordRef)lPerson)];
                if ([filter isEqualToString:@"fav"])
                {
                    NSNumber *rec = [favMap objectForKey:recordId];
                    if (rec == nil)
                    {
                        add = false;
                    }
                }
                else if ([filter isEqualToString:@"ring"])
                {
                    NSNumber *rec = [ringMailMap objectForKey:recordId];
                    if (rec == nil)
                    {
                        add = false;
                    }
                }
            }
            
            if(add) {
                CFStringRef lFirstName = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonFirstNameProperty);
                CFStringRef lLocalizedFirstName = (lFirstName != nil)? ABAddressBookCopyLocalizedLabel(lFirstName): nil;
                CFStringRef lLastName = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonLastNameProperty);
                CFStringRef lLocalizedLastName = (lLastName != nil)? ABAddressBookCopyLocalizedLabel(lLastName): nil;
                CFStringRef lOrganization = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonOrganizationProperty);
                CFStringRef lLocalizedlOrganization = (lOrganization != nil)? ABAddressBookCopyLocalizedLabel(lOrganization): nil;
                NSString *name = nil;
                if(lLocalizedFirstName != nil && lLocalizedLastName != nil) {
                    name=[NSString stringWithFormat:@"%@%@", [(NSString *)lLocalizedFirstName retain], [(NSString *)lLocalizedLastName retain]];
                } else if(lLocalizedLastName != nil) {
                    name=[NSString stringWithFormat:@"%@",[(NSString *)lLocalizedLastName retain]];
                } else if(lLocalizedFirstName != nil) {
                    name=[NSString stringWithFormat:@"%@",[(NSString *)lLocalizedFirstName retain]];
                } else if(lLocalizedlOrganization != nil) {
                    name=[NSString stringWithFormat:@"%@",[(NSString *)lLocalizedlOrganization retain]];
                }
                if(name != nil && [name length] > 0) {
                    // Put in correct subDic
                    NSString *firstChar = [[name substringToIndex:1] uppercaseString];
                    if([firstChar characterAtIndex:0] < 'A' || [firstChar characterAtIndex:0] > 'Z') {
                        firstChar = @"#";
                    }
                    OrderedDictionary *subDic =[addressBookMap objectForKey: firstChar];
                    if(subDic == nil) {
                        subDic = [[[OrderedDictionary alloc] init] autorelease];
                        [addressBookMap insertObject:subDic forKey:firstChar selector:@selector(caseInsensitiveCompare:)];
                    }
                    [subDic insertObject:lPerson forKey:name selector:@selector(caseInsensitiveCompare:)];
                }
                if(lLocalizedlOrganization != nil)
                    CFRelease(lLocalizedlOrganization);
                if(lOrganization != nil)
                    CFRelease(lOrganization);
                if(lLocalizedLastName != nil)
                    CFRelease(lLocalizedLastName);
                if(lLastName != nil)
                    CFRelease(lLastName);
                if(lLocalizedFirstName != nil)
                    CFRelease(lLocalizedFirstName);
                if(lFirstName != nil)
                    CFRelease(lFirstName);
            }
        }
        if (lContacts) CFRelease(lContacts);

    }
    [self.tableView reloadData];
}

static void sync_address_book (ABAddressBookRef addressBook, CFDictionaryRef info, void *context) {
    ContactsTableViewController* controller = (ContactsTableViewController*)context;
    ABAddressBookRevert(addressBook);
    [controller->avatarMap removeAllObjects];
    [controller loadData];
}

#pragma mark - ViewController Functions

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}


#pragma mark - UITableViewDataSource Functions

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [addressBookMap allKeys];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [addressBookMap count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [(OrderedDictionary *)[addressBookMap objectForKey: [addressBookMap keyAtIndex: section]] count];

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *kCellId = @"UIContactCell";   
    UIContactCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellId];
    if (cell == nil) {
        cell = [[[UIContactCell alloc] initWithIdentifier:kCellId] autorelease];
        
        // Background View
        UACellBackgroundView *selectedBackgroundView = [[[UACellBackgroundView alloc] initWithFrame:CGRectZero] autorelease];
        cell.selectedBackgroundView = selectedBackgroundView;
        [selectedBackgroundView setBackgroundColor:LINPHONE_TABLE_CELL_BACKGROUND_COLOR];
    }
    OrderedDictionary *subDic = [addressBookMap objectForKey: [addressBookMap keyAtIndex: [indexPath section]]]; 
    
    NSString *key = [[subDic allKeys] objectAtIndex:[indexPath row]];
    ABRecordRef contact = [subDic objectForKey:key];
    
    // Cached avatar
    UIImage *image = nil;
    NSNumber *contactId = [NSNumber numberWithInt: ABRecordGetRecordID(contact)];
    id data = [avatarMap objectForKey:contactId];
    if(data == nil) {
        image = [FastAddressBook getContactImage:contact thumbnail:true];
        if(image != nil) {
            [avatarMap setObject:image forKey:contactId];
        } else {
            [avatarMap setObject:[NSNull null] forKey:contactId];
        }
    } else if(data != [NSNull null]) {
        image = data;
    }
    if(image == nil) {
        image = [UIImage imageNamed:@"avatar_unknown_small.png"];
    }
    [[cell avatarImage] setImage:image];
    
    NSNumber* recId = [ringMailMap objectForKey:contactId];
    if (recId != nil)
    {
        [cell setHasRingMail:TRUE];
    }
    else
    {
        [cell setHasRingMail:FALSE];
    }
    NSNumber* favId = [favMap objectForKey:contactId];
    if (favId != nil)
    {
        [cell setHasFavorite:TRUE];
    }
    else
    {
        [cell setHasFavorite:FALSE];
    }
    [cell setContact: contact];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
        return [addressBookMap keyAtIndex: section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    OrderedDictionary *subDic = [addressBookMap objectForKey: [addressBookMap keyAtIndex: [indexPath section]]]; 
    ABRecordRef lPerson = [subDic objectForKey: [subDic keyAtIndex:[indexPath row]]];
    
    if (delegate == nil)
    {
        if ([ContactSelection getSelectionMode] == ContactSelectionModeMessage) {
            NSString *address = [FastAddressBook getRingMailURI:lPerson];
            if (address == nil)
            {
                NSArray* phones = [FastAddressBook getPhoneNumbers:lPerson];
                [[PhoneMainView instance].mainViewController selectPhoneAction:@"chat" list:phones];
                return;
            }

            [[PhoneMainView instance] changeCurrentView:[ChatViewController compositeViewDescription]];
            ChatRoomViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[ChatRoomViewController compositeViewDescription] push:TRUE], ChatRoomViewController);
            if(controller != nil) {
                [controller setRemoteAddress:address];
            }
        } else {
            // Go to Contact details view
            ContactDetailsViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[ContactDetailsViewController compositeViewDescription] push:TRUE], ContactDetailsViewController);
            if(controller != nil) {
                if([ContactSelection getSelectionMode] == ContactSelectionModeEdit) {
                    [controller editContact:lPerson address:[ContactSelection getAddAddress]];
                }
                else {
                    [controller setContact:lPerson];
                }
            }
        }
    }
    else
    {
        [delegate contactSelected:lPerson];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	// create the parent view that will hold header Label
	UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 22.0)];
    [customView autorelease];

    customView.backgroundColor = [UIColor colorWithRed:58/255.0f green:137/255.0f blue:201/255.0f alpha:1.0f];
	
	// create the button object
	UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [headerLabel autorelease];
	headerLabel.backgroundColor = [UIColor clearColor];
	headerLabel.opaque = NO;
	headerLabel.textColor = [UIColor whiteColor];
	headerLabel.highlightedTextColor = [UIColor blackColor];
	headerLabel.font = [UIFont boldSystemFontOfSize:18];
	headerLabel.frame = CGRectMake(15.0, 0.0, 305.0, 22.0);
    
	// If you want to align the header text as centered
	// headerLabel.frame = CGRectMake(150.0, 0.0, 300.0, 44.0);
    
	headerLabel.text = [addressBookMap keyAtIndex: section]; // i.e. array element
	[customView addSubview:headerLabel];
    
	return customView;
}


#pragma mark - UITableViewDelegate Functions

- (UITableViewCellEditingStyle)tableView:(UITableView *)aTableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Detemine if it's in editing mode
    if (self.editing) {
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}

@end

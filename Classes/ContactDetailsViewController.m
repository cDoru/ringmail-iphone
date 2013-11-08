/* ContactDetailsViewController.m
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

#import "ContactDetailsViewController.h"
#import "PhoneMainView.h"
#import "DTActionSheet.h"

@implementation ContactDetailsViewController

@synthesize tableController;
@synthesize contact;
@synthesize editButton;
@synthesize backButton;
@synthesize cancelButton;


static void sync_address_book (ABAddressBookRef addressBook, CFDictionaryRef info, void *context);

#pragma mark - Lifecycle Functions

- (id)init  {
    self = [super initWithNibName:@"ContactDetailsViewController" bundle:[NSBundle mainBundle]];
    if(self != nil) {
        inhibUpdate = FALSE;
        addressBook = ABAddressBookCreate();
        ABAddressBookRegisterExternalChangeCallback(addressBook, sync_address_book, self);
    }
    return self;
}

- (void)dealloc {
    ABAddressBookUnregisterExternalChangeCallback(addressBook, sync_address_book, self);
    CFRelease(addressBook);
    [tableController release];
    
    [editButton release];
    [backButton release];
    [cancelButton release];
    
    [super dealloc];
}


#pragma mark - 

- (void)resetData {
    [self disableEdit:FALSE];
    if(contact == NULL) {
        ABAddressBookRevert(addressBook);
        return;
    }
    
    [LinphoneLogger logc:LinphoneLoggerLog format:"Reset data to contact %p", contact];
    ABRecordID recordID = ABRecordGetRecordID(contact);
    ABAddressBookRevert(addressBook);
    contact = ABAddressBookGetPersonWithRecordID(addressBook, recordID);
    if(contact == NULL) {
        [[PhoneMainView instance] popCurrentView];
        return;
    }
    [tableController setContact:contact];
}

static void sync_address_book (ABAddressBookRef addressBook, CFDictionaryRef info, void *context) {
    ContactDetailsViewController* controller = (ContactDetailsViewController*)context;
    if(!controller->inhibUpdate && ![[controller tableController] isEditing]) {
        [controller resetData];
    }
}

- (void)removeContact {
    if(contact == NULL) {
        [[PhoneMainView instance] popCurrentView];
        return;
    }
    
    // Remove contact from book
    if(ABRecordGetRecordID(contact) != kABRecordInvalidID) {
        NSError* error = NULL;
        ABAddressBookRemoveRecord(addressBook, contact, (CFErrorRef*)&error);
        if (error != NULL) {
            [LinphoneLogger log:LinphoneLoggerError format:@"Remove contact %p: Fail(%@)", contact, [error localizedDescription]];
        } else {
            [LinphoneLogger logc:LinphoneLoggerLog format:"Remove contact %p: Success!", contact];
        }
        contact = NULL;
        
        // Save address book
        error = NULL;
        inhibUpdate = TRUE;
        ABAddressBookSave(addressBook, (CFErrorRef*)&error);
        inhibUpdate = FALSE;
        if (error != NULL) {
            [LinphoneLogger log:LinphoneLoggerError format:@"Save AddressBook: Fail(%@)", [error localizedDescription]];
        } else {
            [LinphoneLogger logc:LinphoneLoggerLog format:"Save AddressBook: Success!"];
        }
    }
}

- (void)saveData {
    if(contact == NULL) {
        [[PhoneMainView instance] popCurrentView];
        return;
    }
    
    // Add contact to book
    NSError* error = NULL;
    if(ABRecordGetRecordID(contact) == kABRecordInvalidID) {
        ABAddressBookAddRecord(addressBook, contact, (CFErrorRef*)&error);
        if (error != NULL) {
            [LinphoneLogger log:LinphoneLoggerError format:@"Add contact %p: Fail(%@)", contact, [error localizedDescription]];
        } else {
            [LinphoneLogger logc:LinphoneLoggerLog format:"Add contact %p: Success!", contact];
        }
    }
    
    // Save address book
    error = NULL;
    inhibUpdate = TRUE;
    ABAddressBookSave(addressBook, (CFErrorRef*)&error);
    inhibUpdate = FALSE;
    if (error != NULL) {
        [LinphoneLogger log:LinphoneLoggerError format:@"Save AddressBook: Fail(%@)", [error localizedDescription]];
    } else {
        [LinphoneLogger logc:LinphoneLoggerLog format:"Save AddressBook: Success!"];
    }
    FastAddressBook* book = [[LinphoneManager instance] fastAddressBook];
    [book loadData];
    [book setupWheelContacts];
    [[LinphoneManager instance] setReloadWheels:YES];
}

- (void)newContact {
    [LinphoneLogger logc:LinphoneLoggerLog format:"New contact"];
    contact = NULL;
    [self resetData];
    contact = ABPersonCreate();
    [tableController setContact:contact];
    [self enableEdit:FALSE];
    [[tableController tableView] reloadData];
}

- (void)newContact:(NSString*)address {
    [LinphoneLogger logc:LinphoneLoggerLog format:"New contact: %@", address];
    contact = NULL;
    [self resetData];
    contact = ABPersonCreate();
    [tableController setContact:contact];
    if ([address rangeOfString:@"@"].length > 0) {
        [tableController addEmailField:address];
    } else {
        [tableController addPhoneField:address];
    }
    
/*    if ([[LinphoneManager instance] lpConfigBoolForKey:@"show_contacts_emails_preference"] == true) {
        LinphoneAddress *linphoneAddress = linphone_address_new([address cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        NSString *username = [NSString stringWithUTF8String:linphone_address_get_username(linphoneAddress)];
        if ([username rangeOfString:@"@"].length > 0) {
            [tableController addEmailField:username];
        } else {
            [tableController addSipField:address];
        }
        linphone_address_destroy(linphoneAddress);
    } else {
        [tableController addSipField:address];
    } */
    
    [self enableEdit:FALSE];
    [[tableController tableView] reloadData];
}

- (void)editContact:(ABRecordRef)acontact {
    [LinphoneLogger logc:LinphoneLoggerLog format:"Edit contact %p", acontact];
    contact = NULL;
    [self resetData];
    contact = ABAddressBookGetPersonWithRecordID(addressBook, ABRecordGetRecordID(acontact));
    [tableController setContact:contact];
    [self enableEdit:FALSE];
    [[tableController tableView] reloadData];
}

- (void)editContact:(ABRecordRef)acontact address:(NSString*)address {
    [LinphoneLogger logc:LinphoneLoggerLog format:"Edit contact %p", acontact];
    contact = NULL;
    [self resetData];
    contact = ABAddressBookGetPersonWithRecordID(addressBook, ABRecordGetRecordID(acontact));
    [tableController setContact:contact];
    
    [tableController setContact:contact];
    if ([address rangeOfString:@"@"].length > 0) {
        [tableController addEmailField:address];
    } else {
        [tableController addPhoneField:address];
    }
    
/*    if ([[LinphoneManager instance] lpConfigBoolForKey:@"show_contacts_emails_preference"] == true) {
        LinphoneAddress *linphoneAddress = linphone_address_new([address cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        NSString *username = [NSString stringWithUTF8String:linphone_address_get_username(linphoneAddress)];
        if ([username rangeOfString:@"@"].length > 0) {
            [tableController addEmailField:username];
        } else {
            [tableController addSipField:address];
        }
        linphone_address_destroy(linphoneAddress);
    } else {
        [tableController addSipField:address];
    } */
    
    
    [self enableEdit:FALSE];
    [[tableController tableView] reloadData];
}


#pragma mark - Property Functions

- (void)setContact:(ABRecordRef)acontact {
    [LinphoneLogger logc:LinphoneLoggerLog format:"Set contact %p", acontact];
    contact = NULL;
    [self resetData];
    contact = ABAddressBookGetPersonWithRecordID(addressBook, ABRecordGetRecordID(acontact));
    [tableController setContact:contact];
}


#pragma mark - ViewController Functions

- (void)viewDidLoad{
    [super viewDidLoad];
    
    // Set selected+over background: IB lack !
    [editButton setBackgroundImage:[UIImage imageNamed:@"chat_edit_over.png"]
                forState:(UIControlStateHighlighted | UIControlStateSelected)];
    
    // Set selected+disabled background: IB lack !
    [editButton setBackgroundImage:[UIImage imageNamed:@"chat_edit_over.png"]
                forState:(UIControlStateDisabled | UIControlStateSelected)];
    
    [LinphoneUtils buttonFixStates:editButton];

    [tableController.tableView setBackgroundColor:[UIColor clearColor]]; // Can't do it in Xib: issue with ios4
    [tableController.tableView setBackgroundView:nil]; // Can't do it in Xib: issue with ios4
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
        [tableController viewWillDisappear:animated];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if([ContactSelection getSelectionMode] == ContactSelectionModeEdit ||
       [ContactSelection getSelectionMode] == ContactSelectionModeNone) {
        [editButton setHidden:FALSE];
    } else {
        [editButton setHidden:TRUE];
    }
    if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
        [tableController viewWillAppear:animated];
    }   
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
        [tableController viewDidAppear:animated];
    }   
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
        [tableController viewDidDisappear:animated];
    }  
}


#pragma mark - UICompositeViewDelegate Functions

static UICompositeViewDescription *compositeDescription = nil;

+ (UICompositeViewDescription *)compositeViewDescription {
    if(compositeDescription == nil) {
        compositeDescription = [[UICompositeViewDescription alloc] init:@"ContactDetails" 
                                                                content:@"ContactDetailsViewController" 
                                                               stateBar:nil 
                                                        stateBarEnabled:false 
                                                                 tabBar:@"UIMainBar" 
                                                          tabBarEnabled:true 
                                                             fullscreen:false
                                                          landscapeMode:[LinphoneManager runningOnIpad]
                                                           portraitMode:true];
    }
    return compositeDescription;
}


#pragma mark -

- (void)enableEdit:(BOOL)animated {
    if(![tableController isEditing]) {
        [tableController setEditFlag:TRUE];
        [tableController setEditing:TRUE animated:animated];
    }
    [editButton setOn];
    [cancelButton setHidden:FALSE];
    [backButton setHidden:TRUE];
}

- (void)disableEdit:(BOOL)animated {
    if([tableController isEditing]) {
        [tableController setEditFlag:FALSE];
        [tableController setEditing:FALSE animated:animated];
    }
    [editButton setOff];
    [cancelButton setHidden:TRUE];
    [backButton setHidden:FALSE];
}


#pragma mark - Action Functions

- (IBAction)onCancelClick:(id)event {
    [self disableEdit:TRUE];
    [self resetData];
}

- (IBAction)onBackClick:(id)event {
    if([ContactSelection getSelectionMode] == ContactSelectionModeEdit) {
        [ContactSelection setSelectionMode:ContactSelectionModeNone];
    }
    [[PhoneMainView instance] popCurrentView];
}

- (IBAction)onEditClick:(id)event {
    if([tableController isEditing]) {
        if([tableController isValid]) {
            [self disableEdit:TRUE];
            [self saveData];
        }
    } else {
        [self enableEdit:TRUE];
    }
}

- (void)onRemove:(id)event {
    [self disableEdit:FALSE];
    [self removeContact];
    [[PhoneMainView instance] popCurrentView];
}

- (void)onModification:(id)event {
    if(![tableController isEditing] || [tableController isValid]) {
        [editButton setEnabled:TRUE];
    } else {
        [editButton setEnabled:FALSE];
    }
}

#pragma mark - RingMail Invites

- (void)showInvite:(NSMutableArray *)emailTo phone:(NSMutableArray *)phoneTo {
    int emails = [emailTo count];
    int phones = [phoneTo count];
    
    if(! [MFMessageComposeViewController canSendText])
    {
        phones = 0;
    }
    
    if (emails == 0 && phones == 0)
    {
        UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Invite To RingMail" message:@"An email address or phone number is required to send an invitation." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [warningAlert show];
        return;
    }
    
    if (emails > 0 && phones == 0)
    {
        [self selectInvite:@"email" list:emailTo];
        return;
    }
    else if (phones > 0 && emails == 0)
    {
        [self selectInvite:@"phone" list:phoneTo];
        return;
    }
    
    NSString* title = @"Invite To RingMail";
    DTActionSheet *sheet = [[[DTActionSheet alloc] initWithTitle:title] autorelease];
    [sheet addButtonWithTitle:@"Send Email" block:^() {
        [LinphoneLogger logc:LinphoneLoggerLog format:"Send Invite: Email"];
        [self selectInvite:@"email" list:emailTo];
    }];
    [sheet addButtonWithTitle:@"Send SMS" block:^() {
        [LinphoneLogger logc:LinphoneLoggerLog format:"Send Invite: SMS"];
        [self selectInvite:@"phone" list:phoneTo];
    }];
    DTActionSheetBlock cancelBlock = ^() {
        [LinphoneLogger logc:LinphoneLoggerLog format:"Send Invite: Cancel"];
    };
    [sheet addDestructiveButtonWithTitle:@"Cancel"  block:cancelBlock];
    [sheet showInView:[PhoneMainView instance].view];
}

- (void)selectInvite:(NSString *)type list:(NSMutableArray *)data
{
    if ([data count] == 1)
    {
        if ([type isEqualToString:@"email"])
        {
            [self inviteEmail:[data objectAtIndex:0]];
        }
        else if ([type isEqualToString:@"phone"])
        {
            [self inviteText:[data objectAtIndex:0]];
        }
        return;
    }
    int max = [data count];
    if (max > 5)
    {
        max = 5;
    }
    NSString* title = @"Invite To RingMail";
    if ([type isEqualToString:@"email"])
    {
        title = @"Invite Via Email";
    }
    else if ([type isEqualToString:@"phone"])
    {
        title = @"Invite Via SMS";
    }
    DTActionSheet *sheet = [[[DTActionSheet alloc] initWithTitle:title] autorelease];
    for (int i = 0; i < max; i++)
    {
        NSString *to = [data objectAtIndex:i];
        [sheet addButtonWithTitle:to block:^() {
            [LinphoneLogger logc:LinphoneLoggerLog format:"Send Invite Select: Email"];
            if ([type isEqualToString:@"email"])
            {
                [self inviteEmail:to];
            }
            else if ([type isEqualToString:@"phone"])
            {
                [self inviteText:to];
            }
        }];
    }
    DTActionSheetBlock cancelBlock = ^() {
        [LinphoneLogger logc:LinphoneLoggerLog format:"Send Invite Select: Cancel"];
    };
    [sheet addDestructiveButtonWithTitle:@"Cancel"  block:cancelBlock];
    [sheet showInView:[PhoneMainView instance].view];
}

- (void)inviteText:(NSString *)phoneTo
{
    NSArray *recipents = @[phoneTo];
    NSString *message = [NSString stringWithFormat:@"You're invited to join RingMail!"];
    
    MFMessageComposeViewController *messageController = [[MFMessageComposeViewController alloc] init];
    messageController.messageComposeDelegate = self;
    [messageController setRecipients:recipents];
    [messageController setBody:message];
    
    // Present message view controller on screen
    [self presentViewController:messageController animated:NO completion:nil];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult) result
{
    switch (result) {
        case MessageComposeResultCancelled:
            break;
        case MessageComposeResultFailed:
        {
            UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Failed to send SMS!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [warningAlert show];
            break;
        }
        case MessageComposeResultSent:
            break;
        default:
            break;
    }
    [self dismissViewControllerAnimated:NO completion:nil];
    [controller release];
}

- (void)inviteEmail:(NSString *)emailTo
{
    NSString *emailTitle = @"RingMail Invitation";
    // Email Content
    NSString *messageBody = @"<h1>Register your email with RingMail for FREE Internet calling!</h1>"; // Change the message body to HTML
    // To address
    NSArray *toRecipents = [NSArray arrayWithObject:emailTo];
    
    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    mc.mailComposeDelegate = self;
    [mc setSubject:emailTitle];
    [mc setMessageBody:messageBody isHTML:YES];
    [mc setToRecipients:toRecipents];
    
    // Present mail view controller on screen
    [self presentViewController:mc animated:YES completion:NULL];
}

- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail sent");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            break;
        default:
            break;
    }
    
    // Close the Mail Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
}


@end

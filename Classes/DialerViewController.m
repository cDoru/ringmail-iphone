/* DialerViewController.h
 *
 * Copyright (C) 2009  Belledonne Comunications, Grenoble, France
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

#import <AVFoundation/AVAudioSession.h>
#import <AudioToolbox/AudioToolbox.h>

#import "DialerViewController.h"
#import "IncallViewController.h"
#import "LinphoneManager.h"
#import "PhoneMainView.h"
#import "Utils.h"
#import "SMRotaryWheel.h"
#import "ContactsTableViewController.h"
#import "RemoteModel.h"

#include "linphonecore.h"


@implementation DialerViewController

@synthesize transferMode;

@synthesize addressField;
@synthesize callButton;
@synthesize textButton;

@synthesize backgroundView;
@synthesize videoPreview;
@synthesize videoCameraSwitch;
@synthesize favRotationView;
@synthesize favWheel;
@synthesize contactButton;
@synthesize currentContact;
@synthesize inviteButton;
@synthesize ringMailImage;

#pragma mark - Lifecycle Functions

- (id)init {
    if (IS_IPHONE && IS_IPHONE_5)
    {
        self = [super initWithNibName:@"DialerViewController_iPhone5" bundle:[NSBundle mainBundle]];
    }
    else
    {
        self = [super initWithNibName:@"DialerViewController" bundle:[NSBundle mainBundle]];
    }
    
    if(self) {
        self->transferMode = FALSE;
        [callButton setHiddenAddress:@""];
        //TODO
        //[textButton setHiddenAddress:@""];
        
        favWheel = nil;
        currentContact = nil;
    }
    return self;
}

- (void)dealloc {
	[addressField release];
	[callButton release];
    [textButton release];
    
    [videoPreview release];
    [videoCameraSwitch release];
    [favRotationView release];
    
    [inviteButton release];
    [ringMailImage release];
    
    // Remove all observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	[super dealloc];
}


#pragma mark - UICompositeViewDelegate Functions

static UICompositeViewDescription *compositeDescription = nil;

+ (UICompositeViewDescription *)compositeViewDescription {
    if(compositeDescription == nil) {
        compositeDescription = [[UICompositeViewDescription alloc] init:@"Dialer" 
                                                                content:@"DialerViewController" 
                                                               stateBar:@"UIStateBar" 
                                                        stateBarEnabled:true 
                                                                 tabBar:@"UIMainBar" 
                                                          tabBarEnabled:true 
                                                             fullscreen:false
                                                          landscapeMode:[LinphoneManager runningOnIpad]
                                                           portraitMode:true];
    }
    return compositeDescription;
}


#pragma mark - ViewController Functions

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Set observer
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(callUpdateEvent:) 
                                                 name:kLinphoneCallUpdate
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(coreUpdateEvent:)
                                                 name:kLinphoneCoreUpdate
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(wheelUpdateEvent:)
                                                 name:@"RingMailWheelUpdated"
                                               object:nil];
    
    // Update on show
    if([LinphoneManager isLcReady]) {
        LinphoneCore* lc = [LinphoneManager getLc];
        LinphoneCall* call = linphone_core_get_current_call(lc);
        LinphoneCallState state = (call != NULL)?linphone_call_get_state(call): 0;
        [self callUpdate:call state:state];
        
        if([LinphoneManager runningOnIpad]) {
            if(linphone_core_video_enabled(lc) && linphone_core_video_preview_enabled(lc)) {
                linphone_core_set_native_preview_window_id(lc, (unsigned long)videoPreview);
                [backgroundView setHidden:FALSE];
                [videoCameraSwitch setHidden:FALSE];
            } else {
                linphone_core_set_native_preview_window_id(lc, (unsigned long)NULL);
                [backgroundView setHidden:TRUE];
                [videoCameraSwitch setHidden:TRUE];
            }
        }
    }

    [self wheelUpdateEvent:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Remove observer
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:kLinphoneCallUpdate
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLinphoneCoreUpdate
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"RingMailWheelUpdated"
                                                  object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [addressField setAdjustsFontSizeToFitWidth:TRUE]; // Not put it in IB: issue with placeholder size
    
    if([LinphoneManager runningOnIpad]) {
        if ([LinphoneManager instance].frontCamId != nil) {
            // only show camera switch button if we have more than 1 camera
            [videoCameraSwitch setHidden:FALSE];
        }
    }
    
    favWheel = [[SMRotaryWheel alloc] initWithFrame:CGRectMake(0, 0, 310, 310)
                                     andDelegate:self
                                    withSections:8
                                    withName:@"favorites"];
    
    favWheel.center = [favRotationView convertPoint:favRotationView.center fromView:favRotationView.superview];
    [favRotationView addSubview:favWheel];
    
    [contactButton setImage:[UIImage imageNamed:@"avatar_unknown_small.png"] forState:UIControlStateNormal];
    
    [self setAddress:@""];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [favWheel release];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    CGRect frame = [videoPreview frame];
    switch (toInterfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            [videoPreview setTransform: CGAffineTransformMakeRotation(0)];
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            [videoPreview setTransform: CGAffineTransformMakeRotation(M_PI)];
            break;
        case UIInterfaceOrientationLandscapeLeft:
            [videoPreview setTransform: CGAffineTransformMakeRotation(M_PI / 2)];
            break;
        case UIInterfaceOrientationLandscapeRight:
            [videoPreview setTransform: CGAffineTransformMakeRotation(-M_PI / 2)];
            break;
        default:
            break;
    }
    [videoPreview setFrame:frame];
}

#pragma mark - Event Functions

- (void)callUpdateEvent:(NSNotification*)notif { 
    LinphoneCall *call = [[notif.userInfo objectForKey: @"call"] pointerValue];
    LinphoneCallState state = [[notif.userInfo objectForKey: @"state"] intValue];
    [self callUpdate:call state:state];
}

- (void)coreUpdateEvent:(NSNotification*)notif {
    if([LinphoneManager isLcReady] && [LinphoneManager runningOnIpad]) {
        LinphoneCore* lc = [LinphoneManager getLc];
        if(linphone_core_video_enabled(lc) && linphone_core_video_preview_enabled(lc)) {
            linphone_core_set_native_preview_window_id(lc, (unsigned long)videoPreview);
            [backgroundView setHidden:FALSE];
            [videoCameraSwitch setHidden:FALSE];
        } else {
            linphone_core_set_native_preview_window_id(lc, (unsigned long)NULL);
            [backgroundView setHidden:TRUE];
            [videoCameraSwitch setHidden:TRUE];
        }
    }
}

- (void)wheelUpdateEvent:(NSNotification*)notif {
    LinphoneManager *mgr = [LinphoneManager instance];
    if ([mgr reloadWheels])
    {
        if (favWheel)
        {
            [favWheel updateAll];
        }
        [mgr setReloadWheels:NO];
    }
}

#pragma mark -

- (void)callUpdate:(LinphoneCall*)call state:(LinphoneCallState)state {
    /*if([LinphoneManager isLcReady]) {
        LinphoneCore *lc = [LinphoneManager getLc];
        if(linphone_core_get_calls_nb(lc) > 0) {
            if(transferMode) {
                [addCallButton setHidden:true];
                [transferButton setHidden:false];
            } else {
                [addCallButton setHidden:false];
                [transferButton setHidden:true];
            }
            [callButton setHidden:true];
            [backButton setHidden:false]; 
            [addContactButton setHidden:true];
        } else {
            [addCallButton setHidden:true];
            [callButton setHidden:false];
            [backButton setHidden:true];
            [addContactButton setHidden:false];
            [transferButton setHidden:true];
        }
    }*/
}

- (void)setAddress:(NSString*) address {
    [addressField setText:address];
}

- (void)setTransferMode:(BOOL)atransferMode {
    transferMode = atransferMode;
    LinphoneCall* call = linphone_core_get_current_call([LinphoneManager getLc]);
    LinphoneCallState state = (call != NULL)?linphone_call_get_state(call): 0;
    [self callUpdate:call state:state];
}

- (void)call:(NSString*)address {
    NSString *displayName = nil;
    ABRecordRef contact = [[[LinphoneManager instance] fastAddressBook] getContact:address];
    if(contact) {
        displayName = [FastAddressBook getContactDisplayName:contact];
    }
    [self setAddress:@""];
    [self call:address displayName:displayName];
}

- (void)call:(NSString*)address displayName:(NSString *)displayName {
    [[LinphoneManager instance] call:address displayName:displayName transfer:transferMode];
}


#pragma mark - UITextFieldDelegate Functions

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    //[textField performSelector:@selector() withObject:nil afterDelay:0];
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == addressField) {
        [addressField resignFirstResponder];
    } 
    return YES;
}

#pragma mark - SMRotaryWheel Functions

- (void)wheelDidChangeValue:(NSDictionary *)newValue {
    if (newValue)
    {
        NSNumber *contactId = [newValue objectForKey:@"id"];
        if (contactId != nil)
        {
            ABRecordRef contact = [[[LinphoneManager instance] fastAddressBook] getContactById:contactId];
            if (contact)
            {
                NSString* displayName = [FastAddressBook getContactDisplayName:contact];
                //NSLog(@"Selected: %@", displayName);
                [self setAddress:displayName];
                [callButton setHiddenAddress:[FastAddressBook getPrimaryTarget:contact]];
                //[textButton setHiddenAddress:[FastAddressBook getPrimaryTarget:contact]];
                currentContact = contact;
                UIImage* image = [FastAddressBook getContactImage:contact thumbnail:true];
                if (image == nil)
                {
                    image = [UIImage imageNamed:@"avatar_unknown_small.png"];
                }
                [contactButton setImage:[SMRotaryImage roundedImageWithImage:image] forState:UIControlStateNormal];
                if ([RemoteModel hasRingMail:contactId])
                {
                    ringMailImage.hidden = NO;
                    inviteButton.hidden = YES;
                }
                else
                {
                    ringMailImage.hidden = YES;
                    inviteButton.hidden = NO;
                }
            }
        }
        else
        {
            //NSLog(@"Blank Value 1");
        }
    }
    else
    {
        //NSLog(@"Blank Value 2");
    }
    return;
}

#pragma mark - Action Functions


/*- (IBAction)onSettingsClick:(id)event {
    [[PhoneMainView instance] changeCurrentView:[SettingsViewController compositeViewDescription]];
}*/

- (IBAction)onAddressChange: (id)sender {
    if([[addressField text] length] > 0) {
        [callButton setEnabled:TRUE];
        [textButton setEnabled:TRUE];
    } else {
        [callButton setEnabled:FALSE];
        [textButton setEnabled:FALSE];
    }
}

- (IBAction)onAddressClick: (id)sender {
    NSLog(@"Address Click");
    if ([[callButton hiddenAddress] length] > 0 && [[addressField text] length] > 0)
    {
        [self setAddress:@""];
        [callButton setHiddenAddress:@""];
        [contactButton setImage:[UIImage imageNamed:@"avatar_unknown_small.png"] forState:UIControlStateNormal];
        currentContact = nil;
        ringMailImage.hidden = YES;
        inviteButton.hidden = YES;
    }
}


- (IBAction)onContactClick: (id)sender {
// Go to Contact details view
    if (currentContact == nil)
    {
        return;
    }
    ContactDetailsViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[ContactDetailsViewController compositeViewDescription] push:TRUE], ContactDetailsViewController);
    if(controller != nil) {
        if([ContactSelection getSelectionMode] != ContactSelectionModeEdit) {
            [controller setContact:currentContact];
        } else {
            [controller editContact:currentContact address:[ContactSelection getAddAddress]];
        }
    }
}

- (IBAction)onInviteClick:(id)event
{
    if (currentContact == nil)
    {
        return;
    }
    NSMutableDictionary* inviteData = [FastAddressBook getInviteData:currentContact];
    [[PhoneMainView instance].mainViewController showInvite:[inviteData objectForKey:@"email"] phone:[inviteData objectForKey:@"phone"]];
}

@end

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

#include "linphonecore.h"


@implementation DialerViewController

@synthesize transferMode;

@synthesize addressField;
@synthesize addContactButton;
@synthesize backButton;
@synthesize addCallButton;
@synthesize transferButton;
@synthesize callButton;
@synthesize eraseButton;

@synthesize oneButton;
@synthesize twoButton;
@synthesize threeButton;
@synthesize fourButton;
@synthesize fiveButton;
@synthesize sixButton;
@synthesize sevenButton;
@synthesize eightButton;
@synthesize nineButton;
@synthesize starButton;
@synthesize zeroButton;
@synthesize sharpButton;

@synthesize backgroundView;
@synthesize videoPreview;
@synthesize videoCameraSwitch;
@synthesize contactsView;
@synthesize favRotationView;
@synthesize padView;
@synthesize wheel;
@synthesize favWheel;
@synthesize tableController;
@synthesize tableView;

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
        
        wheel = nil;
    }
    return self;
}

- (void)dealloc {
	[addressField release];
    [addContactButton release];
    [backButton release];
    [eraseButton release];
	[callButton release];
    [addCallButton release];
    [transferButton release];
    
	[oneButton release];
	[twoButton release];
	[threeButton release];
	[fourButton release];
	[fiveButton release];
	[sixButton release];
	[sevenButton release];
	[eightButton release];
	[nineButton release];
	[starButton release];
	[zeroButton release];
	[sharpButton release];
    
    [videoPreview release];
    [videoCameraSwitch release];
    [contactsView release];
    [favRotationView release];
    [padView release];
    
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
    
    if ([[LinphoneManager instance] reloadWheels])
    {
        if (wheel)
        {
            [wheel updateAll];
        }
        if (favWheel)
        {
            [favWheel updateAll];
        }
        [[LinphoneManager instance] setReloadWheels:NO];
    }


    [tableController loadData];
    [tableController.tableView setBackgroundColor:[UIColor clearColor]]; // Can't do it in Xib: issue with ios4
    [tableController.tableView setBackgroundView:nil]; // Can't do it in Xib: issue with ios4
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
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
	[zeroButton    setDigit:'0'];
	[oneButton     setDigit:'1'];
	[twoButton     setDigit:'2'];
	[threeButton   setDigit:'3'];
	[fourButton    setDigit:'4'];
	[fiveButton    setDigit:'5'];
	[sixButton     setDigit:'6'];
	[sevenButton   setDigit:'7'];
	[eightButton   setDigit:'8'];
	[nineButton    setDigit:'9'];
	[starButton    setDigit:'*'];
	[sharpButton   setDigit:'#'];
    
    [addressField setAdjustsFontSizeToFitWidth:TRUE]; // Not put it in IB: issue with placeholder size
    
    if([LinphoneManager runningOnIpad]) {
        if ([LinphoneManager instance].frontCamId != nil) {
            // only show camera switch button if we have more than 1 camera
            [videoCameraSwitch setHidden:FALSE];
        }
    }
    
    [tableController setDelegate:self];
    
    favWheel = [[SMRotaryWheel alloc] initWithFrame:CGRectMake(0, 0, 310, 310)
                                     andDelegate:self
                                    withSections:8
                                    withName:@"favorites"];
    
    favWheel.center = [favRotationView convertPoint:favRotationView.center fromView:favRotationView.superview];
    [favRotationView addSubview:favWheel];
    
    NSArray *itemArray = [NSArray arrayWithObjects: @"Contacts", @"Favorites", @"Dialpad", nil];
    
    SVSegmentedControl* segmentedControl = [[SVSegmentedControl alloc] initWithSectionTitles:itemArray];
    segmentedControl.frame = CGRectMake(20, 415, 280, 40);
    segmentedControl.backgroundTintColor = [UIColor clearColor];
    segmentedControl.cornerRadius = 10;
    segmentedControl.thumb.tintColor = [UIColor colorWithRed:49.0 / 256.0 green:69.0 / 256.0 blue:113.0 / 256.0 alpha:1];
    segmentedControl.thumb.shouldCastShadow = NO;
    currentPanel = 0;
    currentView = contactsView;
    segmentedControl.changeHandler = ^(NSUInteger newIndex) {
        if (currentPanel != newIndex)
        {
            NSLog(@"Changed from: %d to: %d", currentPanel, newIndex);
            if (newIndex == 0)
            {
                CATransition* viewTransition = [CATransition animation];
                [viewTransition setType:kCATransitionPush];
                [viewTransition setDuration:0.5];
                [viewTransition setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
                [viewTransition setSubtype:kCATransitionFromLeft];
                [currentView.layer removeAnimationForKey:@"transition"];
                [currentView.layer addAnimation:viewTransition forKey:@"transition"];
                currentView.hidden = YES;
                CATransition* viewTransition2 = [CATransition animation];
                [viewTransition2 setType:kCATransitionPush];
                [viewTransition2 setDuration:0.5];
                [viewTransition2 setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
                [viewTransition setSubtype:kCATransitionFromRight];
                [contactsView.layer removeAnimationForKey:@"transition"];
                [contactsView.layer addAnimation:viewTransition2 forKey:@"transition"];
                contactsView.hidden = NO;
                currentView = contactsView;
            }
            else if (newIndex == 1)
            {
                CATransition* viewTransition = [CATransition animation];
                [viewTransition setType:kCATransitionPush];
                [viewTransition setDuration:0.5];
                [viewTransition setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
                if (currentPanel == 2)
                {
                    [viewTransition setSubtype:kCATransitionFromLeft];
                }
                else if (currentPanel == 0)
                {
                    [viewTransition setSubtype:kCATransitionFromRight];
                }
                [currentView.layer removeAnimationForKey:@"transition"];
                [currentView.layer addAnimation:viewTransition forKey:@"transition"];
                currentView.hidden = YES;
                CATransition* viewTransition2 = [CATransition animation];
                [viewTransition2 setType:kCATransitionPush];
                [viewTransition2 setDuration:0.5];
                [viewTransition2 setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
                if (currentPanel == 2)
                {
                    [viewTransition2 setSubtype:kCATransitionFromRight];
                }
                else if (currentPanel == 0)
                {
                    [viewTransition2 setSubtype:kCATransitionFromLeft];
                }
                [favRotationView.layer removeAnimationForKey:@"transition"];
                [favRotationView.layer addAnimation:viewTransition forKey:@"transition"];
                favRotationView.hidden = NO;
                currentView = favRotationView;
            }
            else if (newIndex == 2)
            {
                CATransition* viewTransition = [CATransition animation];
                [viewTransition setType:kCATransitionPush];
                [viewTransition setDuration:0.5];
                [viewTransition setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
                [viewTransition setSubtype:kCATransitionFromRight];
                [currentView.layer removeAnimationForKey:@"transition"];
                [currentView.layer addAnimation:viewTransition forKey:@"transition"];
                currentView.hidden = YES;
                CATransition* viewTransition2 = [CATransition animation];
                [viewTransition2 setType:kCATransitionPush];
                [viewTransition2 setDuration:0.5];
                [viewTransition2 setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
                [viewTransition2 setSubtype:kCATransitionFromLeft];
                [padView.layer removeAnimationForKey:@"transition"];
                [padView.layer addAnimation:viewTransition forKey:@"transition"];
                padView.hidden = NO;
                currentView = padView;
            }
            currentPanel = newIndex;
        }
        // respond to index change
    };
	[self.view addSubview:segmentedControl];
    
    [self setAddress:@""];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [wheel release];
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
                [self setAddress:displayName];
                [callButton setHiddenAddress:[FastAddressBook getPrimaryTarget:contact]];
                NSLog(@"Selected: %@", displayName);
            }
        }
        else
        {
            NSLog(@"Blank Value 1");
        }
    }
    else
    {
        NSLog(@"Blank Value 2");
    }
    return;
}

#pragma mark - ContactSelectProtocol Functions

- (void)contactSelected:(ABRecordRef)contact
{
    if (contact)
    {
        NSString* displayName = [FastAddressBook getContactDisplayName:contact];
        [self setAddress:displayName];
        [callButton setHiddenAddress:[FastAddressBook getPrimaryTarget:contact]];
        NSLog(@"Selected: %@", displayName);
    }
}


#pragma mark - Action Functions

- (IBAction)onAddContactClick: (id) event {
    [ContactSelection setSelectionMode:ContactSelectionModeEdit];
    [ContactSelection setAddAddress:[addressField text]];
    [ContactSelection setSipFilter:FALSE];
    [ContactSelection setEmailFilter:FALSE];
    ContactsViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[ContactsViewController compositeViewDescription] push:TRUE], ContactsViewController);
    if(controller != nil) {
        
    }
}

- (IBAction)onSettingsClick:(id)event {
    [[PhoneMainView instance] changeCurrentView:[SettingsViewController compositeViewDescription]];
}

- (IBAction)onBackClick: (id) event {
    [[PhoneMainView instance] changeCurrentView:[InCallViewController compositeViewDescription]];
}

- (IBAction)onAddressChange: (id)sender {
    if([[addressField text] length] > 0) {
        [addContactButton setEnabled:TRUE];
        [eraseButton setEnabled:TRUE];
        [callButton setEnabled:TRUE];
        [addCallButton setEnabled:TRUE];
        [transferButton setEnabled:TRUE];
    } else {
        [addContactButton setEnabled:FALSE];
        [eraseButton setEnabled:FALSE];
        [callButton setEnabled:FALSE];
        [addCallButton setEnabled:FALSE];
        [transferButton setEnabled:FALSE];
    }
}

- (IBAction)onAddressClick: (id)sender {
    NSLog(@"Address Click");
    if ([[callButton hiddenAddress] length] > 0 && [[addressField text] length] > 0)
    {
        [self setAddress:@""];
        [callButton setHiddenAddress:@""];
    }
}

@end

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

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import "UICompositeViewController.h"

#import "UIEraseButton.h"
#import "UICamSwitch.h"
#import "UICallButton.h"
#import "UITransferButton.h"
#import "UIDigitButton.h"
#import "SMRotaryProtocol.h"

@interface DialerViewController : UIViewController <UITextFieldDelegate, UICompositeViewDelegate, SMRotaryProtocol> {
}

- (void)setAddress:(NSString*)address;
- (void)call:(NSString*)address displayName:(NSString *)displayName;
- (void)call:(NSString*)address;

@property (nonatomic, assign) BOOL transferMode;

@property (nonatomic, retain) IBOutlet UITextField* addressField;
@property (nonatomic, retain) IBOutlet UICallButton* callButton;
@property (nonatomic, retain) IBOutlet UIButton* textButton;
@property (nonatomic, retain) IBOutlet UIButton* contactButton;

@property (nonatomic, retain) IBOutlet UIView* backgroundView;
@property (nonatomic, retain) IBOutlet UIView* videoPreview;
@property (nonatomic, retain) IBOutlet UICamSwitch* videoCameraSwitch;
@property (nonatomic, retain) IBOutlet UIView* favRotationView;
@property (nonatomic, retain) IBOutlet UIView* padView;
@property (nonatomic, retain) IBOutlet UIButton* inviteButton;
@property (nonatomic, retain) IBOutlet UIImageView* ringMailImage;

@property (nonatomic, retain) SMRotaryWheel *wheel;
@property (nonatomic, retain) SMRotaryWheel *favWheel;
@property (nonatomic, assign) ABRecordRef currentContact;

- (IBAction)onAddressChange: (id)sender;
- (IBAction)onAddressClick: (id)sender;
- (IBAction)onContactClick: (id)sender;
- (IBAction)onInviteClick: (id)sender;

@end

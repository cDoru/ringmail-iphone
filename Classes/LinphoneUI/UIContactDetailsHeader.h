/* UIContactDetailsHeader.h
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
 *  GNU Library General Public License for more details.                
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */ 

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>

#import "ImagePickerViewController.h"
#import "ContactDetailsDelegate.h"
#import "SMRotaryImage.h"
#import "UICallButton.h"
#import "UIChatButton.h"

@interface UIContactDetailsHeader : UIViewController<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, ImagePickerDelegate> {
    @private
    NSArray *propertyList;
    BOOL editing;
}

@property (nonatomic, assign) ABRecordRef contact;
    
@property (nonatomic, retain) IBOutlet UILabel *addressLabel;
@property (nonatomic, retain) IBOutlet UIImageView *avatarImage;

@property (nonatomic, retain) IBOutlet UIView *normalView;
@property (nonatomic, retain) IBOutlet UIView *editView;
@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) IBOutlet id<ContactDetailsDelegate> contactDetailsDelegate;
@property (nonatomic, retain) IBOutlet UISwitch *favSwitch;
@property (nonatomic, retain) IBOutlet UIView *ringMailView;
@property (nonatomic, retain) IBOutlet UIView *inviteView;
@property (nonatomic, retain) IBOutlet UICallButton *callButton;
@property (nonatomic, retain) IBOutlet UIChatButton *textButton;
@property (nonatomic, retain) IBOutlet UILabel *ringMailURI;

@property(nonatomic,getter=isEditing) BOOL editing;

- (IBAction)onAvatarClick:(id)event;
- (IBAction)onInviteClick:(id)event;

+ (CGFloat)height:(BOOL)editing;

- (void)setEditing:(BOOL)editing animated:(BOOL)animated;
- (void)setEditing:(BOOL)editing;
- (BOOL)isEditing;
- (BOOL)isValid;

@end

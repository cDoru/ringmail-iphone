/* UIChatButton.m
 *
 * Copyright (C) 2011  Belledonne Comunications, Grenoble, France
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

#import "UIChatButton.h"
#import "LinphoneManager.h"
#import "PhoneMainView.h"

#import <CoreTelephony/CTCallCenter.h>

@implementation UIChatButton

@synthesize addressField;
@synthesize hiddenContact;

#pragma mark - Lifecycle Functions

- (void)initUIChatButton {
    [self addTarget:self action:@selector(touchUp:) forControlEvents:UIControlEventTouchUpInside];
}

- (id)init {
    self = [super init];
    if (self) {
		[self initUIChatButton];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		[self initUIChatButton];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
		[self initUIChatButton];
	}
    return self;
}	

- (void)dealloc {
    if (addressField != nil)
    {
        [addressField release];
    }
    
    [super dealloc];
}


#pragma mark -

- (void)touchUp:(id) sender {
    NSString *address = nil;
    if (hiddenContact != nil)
    {
        address = [FastAddressBook getRingMailURI:hiddenContact];
        if (address == nil)
        {
            NSArray* phones = [FastAddressBook getPhoneNumbers:hiddenContact];
            [[PhoneMainView instance].mainViewController selectPhoneAction:@"chat" list:phones];
            return;
        }
    }
    else
    {
        address = [addressField text];
    }
    
    [[PhoneMainView instance] changeCurrentView:[ChatViewController compositeViewDescription]];
    ChatRoomViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[ChatRoomViewController compositeViewDescription] push:TRUE], ChatRoomViewController);
    if(controller != nil) {
        [controller setRemoteAddress:address];
    }
}

- (BOOL) hasHidden
{
    if (hiddenContact == nil)
    {
        return FALSE;
    }
    else
    {
        return TRUE;
    }
}

@end

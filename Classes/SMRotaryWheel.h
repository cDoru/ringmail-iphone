//
//  SMRotaryWheel.h
//  RotaryWheelProject
//
//  Created by cesarerocchi on 2/10/12.
//  Copyright (c) 2012 studiomagnolia.com. All rights reserved.


#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import "SMRotaryProtocol.h"
#import "SMRotaryImage.h"

@interface SMRotaryWheel : UIControl

@property (nonatomic, assign) id <SMRotaryProtocol> delegate;
@property (nonatomic, retain) UIView *container;
@property int numberOfSections;
@property CGAffineTransform startTransform;
@property (nonatomic, retain) NSMutableArray *cloves;
@property (nonatomic, retain) NSMutableArray *cloveImages;
@property (nonatomic, retain) NSMutableArray *spinContacts;
@property int currentValue;
@property CGFloat totalRotate;
@property int totalSpin;
@property int lastRotate;
@property int lastLeft;
@property (nonatomic, retain) NSString *name;

- (id) initWithFrame:(CGRect)frame andDelegate:(id)del withSections:(int)sectionsNumber withName:(NSString *)contactsName;
- (void) updateAll;

@end

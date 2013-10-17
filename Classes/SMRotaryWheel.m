//
//  SMRotaryWheel.m
//  RotaryWheelProject
//
//  Created by cesarerocchi on 2/10/12.
//  Copyright (c) 2012 studiomagnolia.com. All rights reserved.

#import "SMRotaryWheel.h"
#import <QuartzCore/QuartzCore.h>
#import <AddressBook/AddressBook.h>
#import "FastAddressBook.h"
#import "SMCLove.h"

@interface SMRotaryWheel()
    - (void) drawWheel;
    - (float) calculateDistanceFromCenter:(CGPoint)point;
    - (void) buildClovesEven;
    - (void) buildClovesOdd;
    - (UIImageView *) getCloveByValue:(int)value;
    - (NSString *) getCloveName:(int)position;
@end

static float deltaAngle;
static float minAlphavalue = 0.6;
static float maxAlphavalue = 1.0;

@implementation SMRotaryWheel

@synthesize delegate, container, numberOfSections, startTransform, cloves, cloveImages, currentValue, totalRotate, lastRotate, totalSpin, lastLeft, totalItems, contacts;

- (id) initWithFrame:(CGRect)frame andDelegate:(id)del withSections:(int)sectionsNumber {
    
    if ((self = [super initWithFrame:frame]))
    {
        self.currentValue = 0;
        self.totalSpin = 0;
        self.totalItems = 20;
        self.numberOfSections = sectionsNumber;
        self.delegate = del;
        [self setupContacts];
        [self drawWheel];
	}
    return self;
}

- (void) setupContacts
{
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, nil);
    NSArray *contactList = (NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook);
    self.contacts = [NSMutableArray arrayWithCapacity:[contactList count]];
    self.avatarMap = [NSMutableArray arrayWithCapacity:[contactList count]];
    for (id person in contactList)
    {
        CFStringRef lFirstName = ABRecordCopyValue((ABRecordRef)person, kABPersonFirstNameProperty);
        CFStringRef lLocalizedFirstName = (lFirstName != nil) ? ABAddressBookCopyLocalizedLabel(lFirstName) : nil;
        if(lLocalizedFirstName != nil)
        {
            [self.contacts addObject:[NSString stringWithString:(NSString *)lLocalizedFirstName]];
            UIImage* image = [FastAddressBook getContactImage:person thumbnail:true];
            if(image != nil) {
                [self.avatarMap addObject:[self imageWithAlpha:image]];
            } else {
                [self.avatarMap addObject:[UIImage imageNamed:@"avatar_unknown_small.png"]];
            }
            CFRelease(lLocalizedFirstName);
        }
        if(lFirstName != nil)
        {
            CFRelease(lFirstName);
        }
    }
    CFRelease(contactList);
    CFRelease(addressBook);
    self.totalItems = [self.contacts count];
}

- (BOOL)hasAlpha:(UIImage *)img
{
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(img.CGImage);
    return (alpha == kCGImageAlphaFirst ||
            alpha == kCGImageAlphaLast ||
            alpha == kCGImageAlphaPremultipliedFirst ||
            alpha == kCGImageAlphaPremultipliedLast);
}

- (UIImage *)imageWithAlpha:(UIImage *)img
{
    if ([self hasAlpha:img]) {
        return img;
    }
    
    CGFloat scale = MAX(img.scale, 1.0f);
    CGImageRef imageRef = img.CGImage;
    size_t width = CGImageGetWidth(imageRef)*scale;
    size_t height = CGImageGetHeight(imageRef)*scale;
    
    // The bitsPerComponent and bitmapInfo values are hard-coded to prevent an "unsupported parameter combination" error
    CGContextRef offscreenContext = CGBitmapContextCreate(NULL,
                                                          width,
                                                          height,
                                                          8,
                                                          0,
                                                          CGImageGetColorSpace(imageRef),
                                                          kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
    
    // Draw the image into the context and retrieve the new image, which will now have an alpha layer
    CGContextDrawImage(offscreenContext, CGRectMake(0, 0, width, height), imageRef);
    CGImageRef imageRefWithAlpha = CGBitmapContextCreateImage(offscreenContext);
    UIImage *imageWithAlpha = [UIImage imageWithCGImage:imageRefWithAlpha scale:img.scale orientation:UIImageOrientationUp];
    
    // Clean up
    CGContextRelease(offscreenContext);
    CGImageRelease(imageRefWithAlpha);
    
    return imageWithAlpha;
}

- (void) drawWheel {
    container = [[UIView alloc] initWithFrame:self.frame];	
    CGFloat angleSize = 2 * M_PI / numberOfSections;
    self.cloveImages = [NSMutableArray arrayWithCapacity:numberOfSections];
    for (int i = 0; i < numberOfSections; i++)
    {
        //UIImageView *im = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"segment.png"]];
        UIView *im = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 190, 160)];
        im.backgroundColor = [UIColor clearColor];
        //im.text = [NSString stringWithFormat:@"%i", i];
        im.layer.anchorPoint = CGPointMake(1.0f, 0.5f);
        im.layer.position = CGPointMake(container.bounds.size.width/2.0-container.frame.origin.x, 
                                        container.bounds.size.height/2.0-container.frame.origin.y); 
        im.transform = CGAffineTransformMakeRotation(angleSize*i);
        im.alpha = minAlphavalue;
        im.tag = i;
        if (i == 2)
        {
            im.alpha = maxAlphavalue;
        }
        SMRotaryImage *cloveImage = [[SMRotaryImage alloc] initWithFrame:CGRectMake(20, 30, 100, 100) angle:(angleSize * i * -1)];
        [cloveImage updateItem:i newText:[self.contacts objectAtIndex:i] newImage:[self.avatarMap objectAtIndex:i]];
        [self.cloveImages addObject:cloveImage];
        [im addSubview:cloveImage];
        [container addSubview:im];
    }
    container.userInteractionEnabled = NO;
    [self addSubview:container];
    self.cloves = [NSMutableArray arrayWithCapacity:numberOfSections];
    //UIImageView *bg = [[UIImageView alloc] initWithFrame:self.frame];
    //bg.image = [UIImage imageNamed:@"bg.png"];
    //[self addSubview:bg];
    UIImageView *mask = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 58, 58)];
    mask.image = [UIImage imageNamed:@"centerButton.png"];
    mask.center = self.center;
    mask.center = CGPointMake(mask.center.x, mask.center.y+3);
    [self addSubview:mask];
    if (numberOfSections % 2 == 0)
    {
        [self buildClovesEven];
    }
    else
    {
        [self buildClovesOdd];
    }
    [self.delegate wheelDidChangeValue:[self getCloveName:currentValue]];
}

- (UIImageView *) getCloveByValue:(int)value {
    UIImageView *res;
    NSArray *views = [container subviews];
    for (UIImageView *im in views)
    {
        if (im.tag == value)
        {
            res = im;
        }
    }
    return res;
}

- (void) buildClovesEven
{
    CGFloat fanWidth = M_PI*2/numberOfSections;
    CGFloat mid = 0;
    for (int i = 0; i < numberOfSections; i++)
    {
        SMClove *clove = [[SMClove alloc] init];
        clove.midValue = mid;
        clove.minValue = mid - (fanWidth/2);
        clove.maxValue = mid + (fanWidth/2);
        clove.value = i;
        if (clove.maxValue-fanWidth < - M_PI)
        {
            mid = M_PI;
            clove.midValue = mid;
            clove.minValue = fabsf(clove.maxValue);
        }
        mid -= fanWidth;
        NSLog(@"cl is %@", clove);
        [self.cloves addObject:clove];
    }
}

- (void) buildClovesOdd
{
    CGFloat fanWidth = M_PI*2/numberOfSections;
    CGFloat mid = 0;
    for (int i = 0; i < numberOfSections; i++)
    {
        SMClove *clove = [[SMClove alloc] init];
        clove.midValue = mid;
        clove.minValue = mid - (fanWidth/2);
        clove.maxValue = mid + (fanWidth/2);
        clove.value = i;
        mid -= fanWidth;
        if (clove.minValue < - M_PI)
        {
            mid = -mid;
            mid -= fanWidth;
        }
        [self.cloves addObject:clove];
        NSLog(@"cl is %@", clove);
    }
}

- (float) calculateDistanceFromCenter:(CGPoint)point
{
    CGPoint center = CGPointMake(self.bounds.size.width/2.0f, self.bounds.size.height/2.0f);
	float dx = point.x - center.x;
	float dy = point.y - center.y;
	return sqrt(dx*dx + dy*dy);
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint touchPoint = [touch locationInView:self];
    float dist = [self calculateDistanceFromCenter:touchPoint];
    if (dist < 80 || dist > 160)
    {
        // forcing a tap to be on the ferrule
        NSLog(@"ignoring tap (%f,%f)", touchPoint.x, touchPoint.y);
        return NO;
    }
	float dx = touchPoint.x - container.center.x;
	float dy = touchPoint.y - container.center.y;
	deltaAngle = atan2(dy,dx);
    startTransform = container.transform;
    for (SMRotaryImage *img in self.cloveImages)
    {
        [img beginTracking];
    }
    int topValue = currentValue + 2;
    if (topValue >= numberOfSections)
    {
        topValue = topValue - numberOfSections;
    }
    UIImageView *im = [self getCloveByValue:topValue];
    im.alpha = minAlphavalue;
    totalRotate = 0.0f;
    lastRotate = 0;
    lastLeft = currentValue;
    return YES;
}

- (void) updateItem:(int)pos newId:(int)newId
{
    SMRotaryImage *item = [self.cloveImages objectAtIndex:pos];
    int cur = item.imgNum;
    int apply = newId % totalItems;
    if (apply < 0)
    {
        apply = totalItems + apply;
    }
    if (cur != newId)
    {
        [item updateItem:apply newText:[self.contacts objectAtIndex:apply] newImage:[self.avatarMap objectAtIndex:apply]];
    }
}

- (void) updateSpin:(CGFloat)angleDifference newLeft:(int)currentLeft
{
    //NSLog(@"Angle: %f Rotation: %f Last: %i", -angleDifference, totalRotate, lastRotate);
    if (currentLeft == -1)
    {
        totalRotate = (-angleDifference) / ((2 * M_PI) / numberOfSections);
        if ((int)totalRotate != lastRotate)
        {
            lastRotate = (int)totalRotate;
            CGFloat radians = atan2f(container.transform.b, container.transform.a);
            for (SMClove *c in self.cloves)
            {
                //NSLog(@"V: %i Min: %f Max: %f Ang: %f", c.value, c.minValue, c.maxValue, radians);
                if (c.minValue > 0 && c.maxValue < 0)
                { // anomalous case
                    if (c.maxValue > radians || c.minValue < radians)
                    {
                        currentLeft = c.value;
                    }
                }
                else if (radians > c.minValue && radians < c.maxValue)
                {
                    currentLeft = c.value;
                }
            }
        }
    }
    //SMRotaryImage *item = [self.cloveImages objectAtIndex:currentLeft];
    //int newId = item.imgNum;
    int leftDiff = 0;
    if ((currentLeft != -1) && (currentLeft != lastLeft))
    {
        leftDiff = lastLeft - currentLeft;
        //int startNum = lastLeft;
        if (leftDiff == (numberOfSections - 1) || leftDiff == (numberOfSections - 2)) // Left end
        {
            leftDiff = 0 - (numberOfSections - leftDiff);
        }
        else if (leftDiff == (0 - (numberOfSections - 1)) || leftDiff == (0 - (numberOfSections - 2))) // Right end
        {
            leftDiff = numberOfSections + leftDiff;
        }
        lastLeft = currentLeft;
        totalSpin += leftDiff;
        /*if (leftDiff > 0) // turning right (clockwise) - numbers increase
        {
            NSLog(@"Right(%i) Diff: %i Last: %i Current: %i", totalSpin, leftDiff, startNum, currentLeft);
        }
        else
        {
            NSLog(@"Left(%i) Diff: %i Last: %i Current: %i", totalSpin, leftDiff, startNum, currentLeft);
        }*/
        if (totalSpin == 0) // original orientation
        {
            for (int i = 0; i < numberOfSections; i++)
            {
                [self updateItem:i newId:i];
            }
        }
        else
        {
            int rotateSpin = abs(totalSpin / numberOfSections);
            int startSpin;
            int places;
            if (totalSpin < 0)
            {
                startSpin = (rotateSpin + 1) * numberOfSections;
                places = abs(totalSpin % numberOfSections);
            }
            else
            {
                startSpin = rotateSpin * numberOfSections * -1;
                places = numberOfSections - (totalSpin % numberOfSections);

            }
            //NSLog(@"Places: %i Start: %i Rotate: %i", places, startSpin, rotateSpin);
            for (int i = 0; i < places; i++)
            {
                [self updateItem:i newId:startSpin];
                startSpin++;
            }
            startSpin = startSpin - numberOfSections;
            for (int i = places; i < numberOfSections; i++)
            {
                [self updateItem:i newId:startSpin];
                startSpin++;
            }
            
        }

    }
    //NSLog(@"Partial Last: %i Current: %i Num: %i", lastLeft, currentLeft, item.imgNum);
}

- (BOOL)continueTrackingWithTouch:(UITouch*)touch withEvent:(UIEvent*)event
{
	CGPoint pt = [touch locationInView:self];
    float dist = [self calculateDistanceFromCenter:pt];
    if (dist < 80 || dist > 160)
    {
        // a drag path too close to the center
        //NSLog(@"drag path too close to the center (%f,%f)", pt.x, pt.y);
        
        // here you might want to implement your solution when the drag 
        // is too close to the center
        // You might go back to the clove previously selected
        // or you might calculate the clove corresponding to
        // the "exit point" of the drag.

    }
	float dx = pt.x - container.center.x;
	float dy = pt.y - container.center.y;
	float ang = atan2(dy,dx);
    float angleDifference = deltaAngle - ang;
    
    container.transform = CGAffineTransformRotate(startTransform, -angleDifference);
    for (SMRotaryImage *img in self.cloveImages)
    {
        [img rotate:angleDifference];
    }
    
    [self updateSpin:angleDifference newLeft:-1];

    return YES;
}

- (void)endTrackingWithTouch:(UITouch*)touch withEvent:(UIEvent*)event
{
    CGFloat radians = atan2f(container.transform.b, container.transform.a);
    CGFloat newVal = 0.0;
    for (SMClove *c in self.cloves)
    {
        if (c.minValue > 0 && c.maxValue < 0)
        { // anomalous case
            if (c.maxValue > radians || c.minValue < radians)
            {
                if (radians > 0)
                { // we are in the positive quadrant
                    newVal = radians - M_PI;
                }
                else
                { // we are in the negative one
                    newVal = M_PI + radians;                    
                }
                currentValue = c.value;
            }
        }
        else if (radians > c.minValue && radians < c.maxValue)
        {
            newVal = radians - c.midValue;
            currentValue = c.value;
        }
    }
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.2];
    CGAffineTransform t = CGAffineTransformRotate(container.transform, -newVal);
    container.transform = t;
    for (SMRotaryImage *img in self.cloveImages)
    {
        [img finalRotate:newVal];
    }
    [UIView commitAnimations];
    int topValue = currentValue + 2;
    if (topValue >= numberOfSections)
    {
        topValue = topValue - numberOfSections;
    }
    UIImageView *im = [self getCloveByValue:topValue];
    im.alpha = maxAlphavalue;
    
    [self updateSpin:-newVal newLeft:currentValue];
    
    [self.delegate wheelDidChangeValue:[self getCloveName:currentValue]];
}

- (NSString *) getCloveName:(int)position {
    
    NSString *res = @"";
    
    switch (position) {
        case 0:
            res = @"Circles";
            break;
            
        case 1:
            res = @"Flower";
            break;
            
        case 2:
            res = @"Monster";
            break;
            
        case 3:
            res = @"Person";
            break;
            
        case 4:
            res = @"Smile";
            break;
            
        case 5:
            res = @"Sun";
            break;
            
        case 6:
            res = @"Swirl";
            break;
            
        case 7:
            res = @"3 circles";
            break;
            
        case 8:
            res = @"Triangle";
            break;
            
        default:
            break;
    }
    
    return res;
}



@end

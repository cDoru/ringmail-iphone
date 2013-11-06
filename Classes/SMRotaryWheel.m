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
#import "Utils.h"
#import "LinphoneManager.h"

@interface SMRotaryWheel()
    - (void) drawWheel;
    - (float) calculateDistanceFromCenter:(CGPoint)point;
    - (void) buildClovesEven;
    - (void) buildClovesOdd;
    - (UIImageView *) getCloveByValue:(int)value;
    - (NSDictionary *) getCloveName:(int)position;
@end

static float deltaAngle;
static float minAlphavalue = 0.6;
static float maxAlphavalue = 1.0;

@implementation SMRotaryWheel

@synthesize delegate, container, numberOfSections, startTransform, cloves, cloveImages, currentValue, totalRotate, lastRotate, totalSpin, lastLeft, name, spinContacts;

- (id) initWithFrame:(CGRect)frame andDelegate:(id)del withSections:(int)sectionsNumber withName:(NSString *)contactsName
{
    
    if ((self = [super initWithFrame:frame]))
    {
        self.currentValue = 0;
        self.totalSpin = 0;
        self.numberOfSections = sectionsNumber;
        self.delegate = del;
        self.name = contactsName;
        [self drawWheel];
	}
    return self;
}

- (void) drawWheel {
    //NSLog(@"Draw Wheel");
    container = [[UIView alloc] initWithFrame:self.frame];	
    CGFloat angleSize = 2 * M_PI / numberOfSections;
    self.cloveImages = [NSMutableArray arrayWithCapacity:numberOfSections];
    NSMutableArray *contacts = [[[LinphoneManager instance] fastAddressBook] getWheel:self.name];
    for (int i = 0; i < numberOfSections; i++)
    {
        //UIImageView *im = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"segment.png"]];
        UIView *im = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 190, 160)];
        
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
        if ([contacts count] > i)
        {
            NSDictionary *itemData = [contacts objectAtIndex:i];
            UIImage* img = [itemData objectForKey:@"img"];
            if (img == nil)
            {
                img = [UIImage imageNamed:@"avatar_unknown_small.png"];
            }
            [cloveImage updateItem:i newText:[itemData objectForKey:@"name"] newImage:img];
        }
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
    
    if (numberOfSections % 2 == 0)
    {
        [self buildClovesEven];
    }
    else
    {
        [self buildClovesOdd];
    }
    //[self.delegate wheelDidChangeValue:[self getCloveName:currentValue]];
}

- (void) updateAll {
    NSLog(@"*** UPDATE ALL ***");
    NSMutableArray* contacts = [[[LinphoneManager instance] fastAddressBook] getWheel:self.name];
    for (int i = 0; i < numberOfSections; i++)
    {
        SMRotaryImage *item = [self.cloveImages objectAtIndex:i];
        int cur = item.imgNum;
        if (cur != -1)
        {
            if ([contacts count] > cur)
            {
                NSDictionary *itemData = [contacts objectAtIndex:cur];
                UIImage* img = [itemData objectForKey:@"img"];
                if (img == nil)
                {
                    img = [UIImage imageNamed:@"avatar_unknown_small.png"];
                }
                [item updateItem:cur newText:[itemData objectForKey:@"name"] newImage:img];
            }

        }
    }
    container.userInteractionEnabled = NO;
    [self addSubview:container];
    self.cloves = [NSMutableArray arrayWithCapacity:numberOfSections];
    if (numberOfSections % 2 == 0)
    {
        [self buildClovesEven];
    }
    else
    {
        [self buildClovesOdd];
    }
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

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self)
    {
        float dist = [self calculateDistanceFromCenter:point];
        if (dist < 80 || dist > 160)
        {
            return nil;
        }
        else
        {
            return hitView;
        }
    }
    return hitView;
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
    spinContacts = [[[LinphoneManager instance] fastAddressBook] getWheel:self.name];
    return YES;
}

- (void) updateItem:(int)pos newId:(int)newId
{
    SMRotaryImage *item = [self.cloveImages objectAtIndex:pos];
    int totalItems = [spinContacts count];
    int cur = item.imgNum;
    int apply = newId % totalItems;
    if (apply < 0)
    {
        apply = totalItems + apply;
    }
    //NSLog(@"Update Item: %d NewID: %d Apply: %d", pos, newId, apply);
    if (cur != newId)
    {
        NSDictionary *itemData = [spinContacts objectAtIndex:apply];
        UIImage* img = [itemData objectForKey:@"img"];
        if (img == nil)
        {
            img = [UIImage imageNamed:@"avatar_unknown_small.png"];
        }
        [item updateItem:apply newText:[itemData objectForKey:@"name"] newImage:img];
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

- (NSDictionary *) getCloveName:(int)position
{
    NSMutableArray *contacts = [[[LinphoneManager instance] fastAddressBook] getWheel:self.name];
    int totalItems = [contacts count];
    int topValue = currentValue + 2;
    if (topValue >= numberOfSections)
    {
        topValue = topValue - numberOfSections;
    }
    SMRotaryImage *item = [self.cloveImages objectAtIndex:topValue];
    int cur = item.imgNum;
    int apply = cur % totalItems;
    if (apply < 0)
    {
        apply = totalItems + apply;
    }
    if (totalItems > apply)
    {
        NSDictionary *itemData = [contacts objectAtIndex:apply];
        return itemData;
    }
    return nil;
}

@end

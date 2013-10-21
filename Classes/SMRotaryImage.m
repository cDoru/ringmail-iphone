//
//  SMRotaryImage.m
//  linphone
//
//  Created by Mike Frager on 10/5/13.
//
//

#import "Utils.h"
#import "SMRotaryImage.h"

@implementation SMRotaryImage
@synthesize imgTransform, label;

- (id) initWithFrame:(CGRect)frame angle:(CGFloat)angle
{
    if ((self = [super initWithFrame:frame]))
    {
        self.imgNum = -1;
        self.backgroundColor = [UIColor clearColor];
        UIImageView *im = [[UIImageView alloc] initWithImage:[self roundedImageWithImage:[UIImage imageNamed:@"avatar_unknown_small.png"]]];
        self.avatar = im;
        
        UILabel *name;
        if (IS_IPHONE && IS_IPHONE_5)
        {
            im.frame = CGRectMake(15, 15, 70, 70);
            name = [[UILabel alloc] initWithFrame:CGRectMake(15, 85, 70, 15)];
        }
        else
        {
            im.frame = CGRectMake(0, 0, 54, 54);
            name = [[UILabel alloc] initWithFrame:CGRectMake(0, 54, 54, 13)];
        }
        [self addSubview:im];
        name.textAlignment = NSTextAlignmentCenter;
        name.text = [NSString stringWithFormat:@""];
        name.backgroundColor = [UIColor clearColor];
        if (IS_IPHONE && IS_IPHONE_5)
        {
            name.font = [UIFont systemFontOfSize:13.0f];
            
        }
        else
        {
            name.font = [UIFont systemFontOfSize:11.0f];
        }
        name.adjustsFontSizeToFitWidth = YES;
        self.label = name;
        [self addSubview:name];
        self.transform = CGAffineTransformMakeRotation(angle);
	}
    return self;
}

- (void) updateItem:(int)newId newText:(NSString *)newText newImage:(UIImage *)newImage
{
    self.imgNum = newId;
    //self.label.text = [NSString stringWithFormat:@"Label %i", self.imgNum];
    self.label.text = newText;
    self.avatar.image = [self roundedImageWithImage:newImage];
}

- (void) beginTracking
{
    imgTransform = self.transform;
}

- (void) rotate:(CGFloat)angle
{
    self.transform = CGAffineTransformRotate(imgTransform, angle);
}

- (void) finalRotate:(CGFloat)angle
{
    CGAffineTransform t = CGAffineTransformRotate(self.transform, angle);
    self.transform = t;
}

- (UIImage *) roundedImageWithImage:(UIImage *)image
{
    CGContextRef cx = CGBitmapContextCreate(NULL, image.size.width, image.size.height, CGImageGetBitsPerComponent(image.CGImage), 0, CGImageGetColorSpace(image.CGImage), CGImageGetBitmapInfo(image.CGImage));
    
    CGContextBeginPath(cx);
    CGRect pathRect = CGRectMake(0, 0, image.size.width, image.size.height);
    CGContextAddEllipseInRect(cx, pathRect);
    CGContextClosePath(cx);
    CGContextClip(cx);
    
    CGContextDrawImage(cx, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);
    
    CGImageRef clippedImage = CGBitmapContextCreateImage(cx);
    CGContextRelease(cx);
    
    UIImage *roundedImage = [UIImage imageWithCGImage:clippedImage];
    CGImageRelease(clippedImage);
    
    return roundedImage;
}

@end

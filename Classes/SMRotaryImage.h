//
//  SMRotaryImage.h
//  linphone
//
//  Created by Mike Frager on 10/5/13.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SMRotaryImage : UIView

- (id) initWithFrame:(CGRect)frame angle:(CGFloat)angle;
- (void) beginTracking;
- (void) rotate:(CGFloat)angle;
- (void) finalRotate:(CGFloat)angle;
- (UIImage *)roundedImageWithImage:(UIImage *)image;
- (void) updateItem:(int)newId newText:(NSString *)newText newImage:(UIImage *)newImage;

@property CGAffineTransform imgTransform;
@property int imgNum;
@property (nonatomic, retain) UILabel* label;
@property (nonatomic, retain) UIImageView* avatar;

@end

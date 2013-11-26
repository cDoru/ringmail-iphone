//
//  ImageHelper.m
//  Tabris
//
//  Created by Jordi Böhme López on 22.08.12.
//  Copyright (c) 2012 EclipseSource. All rights reserved.
//  Copyright (c) 2012 EclipseSource. All rights reserved.
//  All rights reserved. This program and the accompanying materials
//  are made available under the terms of the Eclipse Public License v1.0
//  which accompanies this distribution, and is available at
//  http://www.eclipse.org/legal/epl-v10.html
//

#import "ImageHelper.h"

@implementation ImageHelper

#pragma mark - API Methods

+(UIImage *)restrictImage:(UIImage *)image toSize:(CGSize)maxSize {
    if( [ImageHelper doesImage:image fitInto:maxSize] ) {
        return image;
    }
    CGFloat ratio = [self computeScaleToFitRatio:image.size forArea:maxSize];
    CGSize newSize = CGSizeMake(floor(image.size.width * ratio), floor(image.size.height * ratio));
    CGContextRef bitmap = CGBitmapContextCreate(NULL,
                                                newSize.width,
                                                newSize.height,
                                                CGImageGetBitsPerComponent(image.CGImage),
                                                0,
                                                CGImageGetColorSpace(image.CGImage),
                                                CGImageGetBitmapInfo(image.CGImage));
    CGContextSetInterpolationQuality( bitmap, kCGInterpolationHigh );

    UIImage *shrinkedImage = [self materialize:image on:bitmap withSize:newSize];
    CGContextRelease(bitmap);
    return shrinkedImage;
}

+(UIImage *)fixOrientation:(UIImage *)image {
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }
    CGAffineTransform transform = CGAffineTransformIdentity;
    [self applyRotationTo:&transform forImage:image];
    [self applyMirroringTo:&transform forImage:image];
    CGContextRef bitmap = CGBitmapContextCreate(NULL,
                                                image.size.width,
                                                image.size.height,
                                                CGImageGetBitsPerComponent(image.CGImage),
                                                0,
                                                CGImageGetColorSpace(image.CGImage),
                                                CGImageGetBitmapInfo(image.CGImage) );
    CGContextConcatCTM(bitmap, transform);
    
    UIImage *rotatedImage = [self materialize:image on:bitmap withSize:image.size];
    CGContextRelease(bitmap);
    return rotatedImage;
}

#pragma mark - Internal Methods

+(CGFloat)computeScaleToFitRatio:(CGSize)size forArea:(CGSize)maxSize {
    CGFloat xRatio = maxSize.width / size.width;
    CGFloat yRatio = maxSize.height / size.height;
    return MIN(xRatio, yRatio);
}

+(BOOL)isTilted:(UIImage *)image {
    BOOL tilted;
    switch (image.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            tilted = YES;
            break;
        default:
            tilted = NO;
    }
    return tilted;
}

+(BOOL)doesImage:(UIImage *)image fitInto:(CGSize)maxSize {
    if( [self isTilted:image] ) {
        return image.size.width <= maxSize.height && image.size.height <= maxSize.width;
    } else {
        return image.size.width <= maxSize.width && image.size.height <= maxSize.height;
    }
}

+ (void)applyRotationTo:(CGAffineTransform *)transform forImage:(UIImage *)originalImage {
    switch (originalImage.imageOrientation) {
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            *transform = CGAffineTransformTranslate(*transform, originalImage.size.width, originalImage.size.height);
            *transform = CGAffineTransformRotate(*transform, M_PI);
            break;
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            *transform = CGAffineTransformTranslate(*transform, originalImage.size.width, 0);
            *transform = CGAffineTransformRotate(*transform, M_PI_2);
            break;
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            *transform = CGAffineTransformTranslate(*transform, 0, originalImage.size.height);
            *transform = CGAffineTransformRotate(*transform, -M_PI_2);
            break;
    }
}

+ (void)applyMirroringTo:(CGAffineTransform *)transform forImage:(UIImage *)originalImage {
    switch (originalImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            *transform = CGAffineTransformTranslate(*transform, originalImage.size.width, 0);
            *transform = CGAffineTransformScale(*transform, -1, 1);
            break;
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            *transform = CGAffineTransformTranslate(*transform, originalImage.size.height, 0);
            *transform = CGAffineTransformScale(*transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }
}

+(UIImage *)materialize:(UIImage *)image on:(CGContextRef)bitmap withSize:(CGSize)size {
    BOOL tilted = [ImageHelper isTilted:image];
    CGRect rect;
    if( tilted ) {
        rect = CGRectMake(0, 0, size.height, size.width);
    } else {
        rect = CGRectMake(0, 0, size.width, size.height);
    }
    CGContextDrawImage(bitmap, rect, image.CGImage);
    CGImageRef newImageRef = CGBitmapContextCreateImage(bitmap);
    UIImage *resultImage = [UIImage imageWithCGImage:newImageRef];
    CGImageRelease(newImageRef);
    return resultImage;
}

@end

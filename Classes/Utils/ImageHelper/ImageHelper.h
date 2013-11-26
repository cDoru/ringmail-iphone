//
//  ImageHelper.h
//  Tabris
//
//  Created by Jordi Böhme López on 22.08.12.
//  Copyright (c) 2012 EclipseSource. All rights reserved.
//  All rights reserved. This program and the accompanying materials
//  are made available under the terms of the Eclipse Public License v1.0
//  which accompanies this distribution, and is available at
//  http://www.eclipse.org/legal/epl-v10.html
//

#import <Foundation/Foundation.h>

@interface ImageHelper : NSObject

+(UIImage *)restrictImage:(UIImage *)image toSize:(CGSize)maxSize;
+(UIImage *)fixOrientation:(UIImage *)image;

@end

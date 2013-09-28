//
//  ChatRoomDelegate.h
//  linphone
//
//  Created by Mike Frager on 8/9/13.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol ChatRoomDelegate <NSObject>

- (BOOL)chatRoomStartImageDownload:(NSURL*)url userInfo:(id)userInfo;
- (BOOL)chatRoomStartImageUpload:(UIImage*)image url:(NSURL*)url;

@end
//
//  FavoritesModel.h
//  linphone
//
//  Created by Mike Frager on 10/23/13.
//
//

#import <Foundation/Foundation.h>

@interface FavoritesModel : NSObject

+ (NSMutableArray *)getFavorites;
+ (BOOL)isFavorite:(NSNumber *)fav;
+ (void)addFavorite:(NSNumber *)fav;
+ (void)removeFavorite:(NSNumber *)fav;

@end

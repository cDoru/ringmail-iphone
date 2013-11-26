//
//  FavoritesModel.m
//  linphone
//
//  Created by Mike Frager on 10/23/13.
//
//

#import "FavoritesModel.h"
#import "LinphoneManager.h"

@implementation FavoritesModel

+ (void)addFavorite:(NSNumber *)fav {
    if ([FavoritesModel isFavorite:fav])
    {
        return;
    }
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return;
    }
    
    const char *sql = "INSERT INTO favorites (id) VALUES (@ID)";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't prepare the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return;
    }
    
    // Prepare statement
    sqlite3_bind_int(sqlStatement, 1, [fav intValue]);
    
    if (sqlite3_step(sqlStatement) != SQLITE_DONE) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Error during execution of query: %s (%s)", sql, sqlite3_errmsg(database)];
        sqlite3_finalize(sqlStatement);
        return;
    }
}

+ (void)removeFavorite:(NSNumber *)fav {
    if (! [FavoritesModel isFavorite:fav])
    {
        return;
    }
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return;
    }
    
    const char *sql = "DELETE FROM favorites WHERE id=@ID";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't prepare the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return;
    }
    
    // Prepare statement
    sqlite3_bind_int(sqlStatement, 1, [fav intValue]);
    
    if (sqlite3_step(sqlStatement) != SQLITE_DONE) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Error during execution of query: %s (%s)", sql, sqlite3_errmsg(database)];
        sqlite3_finalize(sqlStatement);
        return;
    }
}

+ (BOOL)isFavorite:(NSNumber *)fav {
    BOOL found = NO;
    
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return found;
    }
    
    const char *sql = "SELECT COUNT(id) FROM favorites WHERE id=@ID";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't execute the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return found;
    }
    
    // Prepare statement
    sqlite3_bind_int(sqlStatement, 1, [fav intValue]);
    
    int err;
    err = sqlite3_step(sqlStatement);
    if (err == SQLITE_ROW)
    {
        NSNumber* res = [NSNumber numberWithInt:sqlite3_column_int(sqlStatement, 0)];
        if ([res intValue] > 0)
        {
            found = YES;
        }
    }
    else
    {
        [LinphoneLogger logc:LinphoneLoggerError format:"Error during execution of query: %s (%s)", sql, sqlite3_errmsg(database)];
        return found;
    }

    sqlite3_finalize(sqlStatement);
    
    return found;
}

+ (NSMutableArray *)getFavorites {
    NSMutableArray *array = [NSMutableArray array];
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return array;
    }
    
    const char *sql = "SELECT id FROM favorites";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't execute the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return array;
    }
    
    int err;
    while ((err = sqlite3_step(sqlStatement)) == SQLITE_ROW) {
        NSNumber* fav = [NSNumber numberWithInt:sqlite3_column_int(sqlStatement, 0)];
        [array addObject:fav];
    }
    
    if (err != SQLITE_DONE) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Error during execution of query: %s (%s)", sql, sqlite3_errmsg(database)];
        return array;
    }
    
    sqlite3_finalize(sqlStatement);
    
    return array;
}

+ (void)getFavoriteContacts:(NSMutableDictionary *)dict
{
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return;
    }
    
    const char *sql = "SELECT id FROM favorites";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't execute the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return;
    }
    
    [dict removeAllObjects];
    
    int err;
    while ((err = sqlite3_step(sqlStatement)) == SQLITE_ROW) {
        NSNumber* ringId = [NSNumber numberWithInt:sqlite3_column_int(sqlStatement, 0)];
        [dict setObject:ringId forKey:ringId];
    }
    
    if (err != SQLITE_DONE) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Error during execution of query: %s (%s)", sql, sqlite3_errmsg(database)];
        return;
    }
    
    sqlite3_finalize(sqlStatement);
    
    return;
}

+ (void)deleteAll {
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return;
    }
    
    const char *sql = "DELETE FROM favorites";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't prepare the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return;
    }
    
    if (sqlite3_step(sqlStatement) != SQLITE_DONE) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Error during execution of query: %s (%s)", sql, sqlite3_errmsg(database)];
        sqlite3_finalize(sqlStatement);
        return;
    }
    
    sqlite3_finalize(sqlStatement);
    
}

@end

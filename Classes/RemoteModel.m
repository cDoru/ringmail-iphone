//
//  RemoteModel.m
//  linphone
//
//  Created by Mike Frager on 10/30/13.
//
//

#import "RemoteModel.h"
#import "LinphoneManager.h"

@implementation RemoteModel

@synthesize contactId;
@synthesize tsUpdated;
@synthesize primaryUri;
@synthesize ringMailUser;

#pragma mark - Lifecycle Functions

- (id)initWithData:(sqlite3_stmt *)sqlStatement {
    self = [super init];
    if (self != nil) {
        self->contactId = [[NSNumber alloc] initWithInt: sqlite3_column_int(sqlStatement, 0)];
        self.tsUpdated = [NSDate dateWithTimeIntervalSince1970:sqlite3_column_int(sqlStatement, 1)];
        self.primaryUri = [NSString stringWithUTF8String: (const char*) sqlite3_column_text(sqlStatement, 2)];
        self.ringMailUser = [NSNumber numberWithInt:sqlite3_column_int(sqlStatement, 3)];
    }
    return self;
}

- (void)dealloc {
    [contactId release];
    [tsUpdated release];
    [primaryUri release];
    [ringMailUser release];
    [super dealloc];
}

#pragma mark - CRUD Functions

- (void)create {
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return;
    }
    
    const char *sql = "INSERT INTO remote_data (id, tsUpdated, primaryUri, ringMailUser) VALUES (@ID, @TSUPDATED, @PRIMARYURI, @RINGMAILUSER)";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't prepare the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return;
    }
    
    // Prepare statement
    sqlite3_bind_int(sqlStatement, 1, [contactId intValue]);
    sqlite3_bind_double(sqlStatement, 2, [tsUpdated timeIntervalSince1970]);
    sqlite3_bind_text(sqlStatement, 3, [primaryUri UTF8String], -1, SQLITE_STATIC);
    sqlite3_bind_int(sqlStatement, 4, [ringMailUser intValue]);
    
    if (sqlite3_step(sqlStatement) != SQLITE_DONE) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Error during execution of query: %s (%s)", sql, sqlite3_errmsg(database)];
        sqlite3_finalize(sqlStatement);
    }
    
    sqlite3_finalize(sqlStatement);
}

+ (RemoteModel*)read:(NSNumber*)contactId {
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return nil;
    }
    
    const char *sql = "SELECT id, tsUpdated, primaryUri, ringMailUser FROM remote_data WHERE id=@ID";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't prepare the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return nil;
    }
    
    // Prepare statement
    sqlite3_bind_int(sqlStatement, 1, [contactId intValue]);
    
    RemoteModel* line = nil;
    int err = sqlite3_step(sqlStatement);
    if (err == SQLITE_ROW) {
        line = [[[RemoteModel alloc] initWithData:sqlStatement] autorelease];
    } else if (err != SQLITE_DONE) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Error during execution of query: %s (%s)", sql, sqlite3_errmsg(database)];
        sqlite3_finalize(sqlStatement);
        return nil;
    }
    
    sqlite3_finalize(sqlStatement);
    return line;
}

- (void)update {
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return;
    }
    
    const char *sql = "UPDATE remote_data SET tsUpdated=@TSUPDATED, primaryUri=@PRIMARYURI, ringMailUser=@RINGMAILUSER WHERE id=@ID";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't prepare the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return;
    }
    
    // Prepare statement
    sqlite3_bind_double(sqlStatement, 1, [tsUpdated timeIntervalSince1970]);
    sqlite3_bind_text(sqlStatement, 2, [primaryUri UTF8String], -1, SQLITE_STATIC);
    sqlite3_bind_int(sqlStatement, 3, [ringMailUser intValue]);
    sqlite3_bind_int(sqlStatement, 4, [contactId intValue]);
    
    if (sqlite3_step(sqlStatement) != SQLITE_DONE) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Error during execution of query: %s (%s)", sql, sqlite3_errmsg(database)];
        sqlite3_finalize(sqlStatement);
        return;
    }
    
    sqlite3_finalize(sqlStatement);
}

- (void)delete {
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return;
    }
    
    const char *sql = "DELETE FROM remote_data WHERE id=@ID";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't prepare the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return;
    }
    
    // Prepare statement
    sqlite3_bind_int(sqlStatement, 1, [contactId intValue]);
    
    if (sqlite3_step(sqlStatement) != SQLITE_DONE) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Error during execution of query: %s (%s)", sql, sqlite3_errmsg(database)];
        sqlite3_finalize(sqlStatement);
        return;
    }
    
    sqlite3_finalize(sqlStatement);

}

+ (void)deleteAll {
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return;
    }
    
    const char *sql = "DELETE FROM remote_data";
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

+(BOOL)hasContactId:(NSNumber *)num
{
    BOOL found = NO;
    
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return found;
    }
    
    const char *sql = "SELECT COUNT(id) FROM remote_data WHERE id=@ID";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't execute the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return found;
    }
    
    // Prepare statement
    sqlite3_bind_int(sqlStatement, 1, [num intValue]);
    
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

+(BOOL)hasRingMail:(NSNumber *)num
{
    BOOL found = NO;
    
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return found;
    }
    
    const char *sql = "SELECT COUNT(id) FROM remote_data WHERE id=@ID AND ringMailUser=1";
    sqlite3_stmt *sqlStatement;
    if (sqlite3_prepare_v2(database, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Can't execute the query: %s (%s)", sql, sqlite3_errmsg(database)];
        return found;
    }
    
    // Prepare statement
    sqlite3_bind_int(sqlStatement, 1, [num intValue]);
    
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

+ (void)getRingMailContacts:(NSMutableDictionary *)dict
{
    sqlite3* database = [[LinphoneManager instance] database];
    if(database == NULL) {
        [LinphoneLogger logc:LinphoneLoggerError format:"Database not ready"];
        return;
    }
    
    const char *sql = "SELECT id FROM remote_data WHERE ringMailUser=1";
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

@end

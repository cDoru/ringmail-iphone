//
//  ContactSyncManager.m
//  linphone
//
//  Created by Mike Frager on 7/21/13.
//
//

#import "ContactSyncManager.h"
#import "LinphoneManager.h"

#import <AddressBook/AddressBook.h>

#import <XMLRPCConnection.h>
#import <XMLRPCConnectionManager.h>
#import <XMLRPCResponse.h>
#import <XMLRPCRequest.h>
#import "JSONKit.h"
#import "RemoteModel.h"
#import "FavoritesModel.h"

@implementation ContactSyncManager

#pragma mark - Lifecycle Functions

-(id) init
{
    self = [super init];
    addressBook = ABAddressBookCreateWithOptions(NULL, nil);
    contacts = (NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook);
    return self;
}

-(void) dealloc
{
    CFRelease(contacts);
    CFRelease(addressBook);
    [super dealloc];
}

#pragma mark - Contact Syncing

-(void) syncContacts:(NSString*) username password:(NSString*) password
{
    login = username;
    pass = password;
    NSMutableDictionary *stats = [self getAddressBookStats];
    [stats setObject:username forKey:@"login"];
    [stats setObject:password forKey:@"password"];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:stats options:0 error:nil];
    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSURL *URL = [NSURL URLWithString: [[LinphoneManager instance] lpConfigStringForKey:@"service_url" forSection:@"wizard"]];
    //[LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC %@ check_sync %@", URL, result];
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithURL: URL];
    [request setMethod: @"check_sync" withParameters:[NSArray arrayWithObjects:result, nil]];
    NSError* error = nil;
    XMLRPCResponse *xmlrpc = [XMLRPCConnection sendSynchronousXMLRPCRequest:request error:&error];
    if (xmlrpc != nil)
    {
        [self processResponse:xmlrpc request:request];
    }
    [request release];
    [result release];
}

-(NSMutableDictionary *) getAddressBookStats
{
    NSMutableDictionary *result = [[[NSMutableDictionary alloc] init] autorelease];
    NSString *lastMod = NULL;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    CFDateRef maxDate = NULL;
    int counter = 0;
    for (id person in contacts)
    {
        counter++;
        CFDateRef modDate = ABRecordCopyValue((ABRecordRef)person, kABPersonModificationDateProperty);
        if (maxDate)
        {
            if ([(NSDate*)maxDate compare:(NSDate*) modDate] == NSOrderedAscending)
            {
                if (maxDate)
                {
                    CFRelease(maxDate);
                }
                maxDate = modDate;
            }
            else
            {
                CFRelease(modDate);
            }
        }
        else
        {
            maxDate = modDate;
        }
    }
    if (maxDate)
    {
        lastMod = [dateFormatter stringFromDate:(NSDate*)maxDate];
        CFRelease(maxDate);
    }
    else
    {
        lastMod = @"";
    }
    [result setObject:lastMod forKey:@"ts_update"];
    [dateFormatter release];
    [enUSPOSIXLocale release];
    NSString *count = [NSString stringWithFormat:@"%i", counter];
    [result setObject:count forKey:@"count"];
    return result;
}

- (NSString*)contactsToJSON {
    NSMutableArray *contactsArray = [NSMutableArray array];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    for (id lPerson in contacts) {
        ABMultiValueRef emailMap = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonEmailProperty);
        NSMutableArray *emailArray = [NSMutableArray array];
        if (emailMap) {
            for(int i = 0; i < ABMultiValueGetCount(emailMap); ++i) {
                CFStringRef valueRef = ABMultiValueCopyValueAtIndex(emailMap, i);
                if (valueRef) {
                    NSString* val = (NSString *)valueRef;
                    [emailArray addObject:val];
                    CFRelease(valueRef);
                }
            }
            CFRelease(emailMap);
        }
        ABMultiValueRef phoneMap = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonPhoneProperty);
        NSMutableArray *phoneArray = [NSMutableArray array];
        if (phoneMap) {
            for(int i = 0; i < ABMultiValueGetCount(phoneMap); ++i) {
                CFStringRef valueRef = ABMultiValueCopyValueAtIndex(phoneMap, i);
                if (valueRef) {
                    NSString* val = (NSString *)valueRef;
                    [phoneArray addObject:val];
                    CFRelease(valueRef);
                }
            }
            CFRelease(phoneMap);
        }
        CFDateRef modDate= ABRecordCopyValue((ABRecordRef)lPerson, kABPersonModificationDateProperty);
        NSString *modDateGMT = [dateFormatter stringFromDate: (NSDate*)modDate];
        CFRelease(modDate);
        NSNumber *recordId = [NSNumber numberWithInteger:ABRecordGetRecordID((ABRecordRef)lPerson)];
        NSString *recordStr = [NSString stringWithFormat:@"%@", recordId];
        NSDictionary *contactBase = @{ @"em": emailArray, @"ph": phoneArray, @"ts": modDateGMT, @"id": recordStr };
        NSMutableDictionary *contact = [NSMutableDictionary dictionaryWithDictionary:contactBase];
        CFStringRef lFirstName = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonFirstNameProperty);
        CFStringRef lLocalizedFirstName = (lFirstName != nil)? ABAddressBookCopyLocalizedLabel(lFirstName): nil;
        CFStringRef lLastName = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonLastNameProperty);
        CFStringRef lLocalizedLastName = (lLastName != nil)? ABAddressBookCopyLocalizedLabel(lLastName): nil;
        CFStringRef lOrganization = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonOrganizationProperty);
        CFStringRef lLocalizedlOrganization = (lOrganization != nil)? ABAddressBookCopyLocalizedLabel(lOrganization): nil;
        if (lLocalizedFirstName != nil)
        {
            [contact setObject:(NSString*)lLocalizedFirstName forKey:@"fn"];
        }
        if (lLocalizedLastName != nil)
        {
            [contact setObject:(NSString*)lLocalizedLastName forKey:@"ln"];
        }
        if (lLocalizedlOrganization != nil)
        {
            [contact setObject:(NSString*)lLocalizedlOrganization forKey:@"co"];
        }
        if(lLocalizedlOrganization != nil)
            CFRelease(lLocalizedlOrganization);
        if(lOrganization != nil)
            CFRelease(lOrganization);
        if(lLocalizedLastName != nil)
            CFRelease(lLocalizedLastName);
        if(lLastName != nil)
            CFRelease(lLastName);
        if(lLocalizedFirstName != nil)
            CFRelease(lLocalizedFirstName);
        if(lFirstName != nil)
            CFRelease(lFirstName);
        [contactsArray addObject:contact];
    }
    [dateFormatter release];
    [enUSPOSIXLocale release];
    NSDictionary *final = @{ @"contacts":contactsArray, @"login":login, @"password":pass };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:final options:0 error:nil];
    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [result autorelease];
    return result;
}

- (void)sendContacts
{
    NSString* result = [self contactsToJSON];
    //[LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC sync_contacts %@", result];
    NSURL *URL = [NSURL URLWithString: [[LinphoneManager instance] lpConfigStringForKey:@"service_url" forSection:@"wizard"]];
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithURL: URL];
    [request setMethod: @"sync_contacts" withParameters:[NSArray arrayWithObjects:result, nil]];
    NSError* error = nil;
    XMLRPCResponse *xmlrpc = [XMLRPCConnection sendSynchronousXMLRPCRequest:request error:&error];
    if (xmlrpc != nil)
    {
        [self processResponse:xmlrpc request:request];
    }
    [request release];
}

- (void)getRemoteData:(NSArray *)contactIds favorites:(NSArray *)favs login:(NSString*) username password:(NSString*) password
{
    if (contactIds == nil)
    {
        contactIds = [NSArray array];
    }
    NSMutableDictionary *reqstruct = [NSMutableDictionary dictionary];
    [reqstruct setObject:username forKey:@"login"];
    [reqstruct setObject:password forKey:@"password"];
    [reqstruct setObject:contactIds forKey:@"contacts"];
    if (favs != nil)
    {
        NSDate* favUpdated = [RemoteModel getUpdated:RemoteItemFavorites];
        if (favUpdated != nil)
        {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            [dateFormatter setLocale:enUSPOSIXLocale];
            [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
            [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
            [reqstruct setObject:[dateFormatter stringFromDate:favUpdated] forKey:@"favorites_ts"];
            [dateFormatter release];
            [enUSPOSIXLocale release];
            [reqstruct setObject:favs forKey:@"favorites"];
        }
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:reqstruct options:0 error:nil];
    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    //[LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC get_remote_data %@", result];
    NSURL *URL = [NSURL URLWithString: [[LinphoneManager instance] lpConfigStringForKey:@"service_url" forSection:@"wizard"]];
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithURL: URL];
    [request setMethod: @"get_remote_data" withParameters:[NSArray arrayWithObjects:result, nil]];
    NSError* error = nil;
    XMLRPCResponse *xmlrpc = [XMLRPCConnection sendSynchronousXMLRPCRequest:request error:&error];
    if (xmlrpc != nil)
    {
        [self processResponse:xmlrpc request:request];
    }
    [request release];
}

- (void)getRemoteFavorites:(NSArray *)favs login:(NSString*) username password:(NSString*) password
{
    NSMutableDictionary *reqstruct = [NSMutableDictionary dictionary];
    [reqstruct setObject:username forKey:@"login"];
    [reqstruct setObject:password forKey:@"password"];
    if (favs != nil)
    {
        NSDate* favUpdated = [RemoteModel getUpdated:RemoteItemFavorites];
        if (favUpdated != nil)
        {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            [dateFormatter setLocale:enUSPOSIXLocale];
            [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
            [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
            [reqstruct setObject:[dateFormatter stringFromDate:favUpdated] forKey:@"favorites_ts"];
            [dateFormatter release];
            [enUSPOSIXLocale release];
            [reqstruct setObject:favs forKey:@"favorites"];
        }
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:reqstruct options:0 error:nil];
    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    //[LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC get_remote_data (favorites) %@", result];
    NSURL *URL = [NSURL URLWithString: [[LinphoneManager instance] lpConfigStringForKey:@"service_url" forSection:@"wizard"]];
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithURL: URL];
    [request setMethod: @"get_remote_data" withParameters:[NSArray arrayWithObjects:result, nil]];
    NSError* error = nil;
    XMLRPCResponse *xmlrpc = [XMLRPCConnection sendSynchronousXMLRPCRequest:request error:&error];
    if (xmlrpc != nil)
    {
        [self processResponse:xmlrpc request:request];
    }
    [request release];
}

- (void)processResponse:(XMLRPCResponse *)response request:(XMLRPCRequest *)request {
    //[LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC %@: %@", [request method], [response body]];
    if ([response isFault]) {
        [LinphoneLogger logc:LinphoneLoggerLog format:"XMLRPC Failure: $@", [response faultString]];
    } else if([response object] != nil) { //Don't handle if not object: HTTP/Communication Error
        if([[request method] isEqualToString:@"check_sync"]) {
            if([response object] == [NSNumber numberWithInt:2]) {  // 2 = Need to sync
                [LinphoneLogger logc:LinphoneLoggerLog format:"RingMail Contacts Need Sync"];
                [self sendContacts];
            }
            else
            {
                [LinphoneLogger logc:LinphoneLoggerLog format:"RingMail Contact Not Changed"];
            }
        }
        else if([[request method] isEqualToString:@"get_remote_data"]) {
            NSString *jsonResult = [response object];
            //[LinphoneLogger logc:LinphoneLoggerLog format:"RingMail Remote Data: %@", jsonResult];
            NSDictionary *result = [jsonResult objectFromJSONString];
            
            //[LinphoneLogger logc:LinphoneLoggerLog format:"RingMail Remote Object: %@", result];
            //NSLog(@"RingMail Remote Object: %@", result);
            
            NSArray *ringmail = [result objectForKey:@"ringmail"];
            if (ringmail != nil)
            {
                [RemoteModel deleteAll];
                for (id remoteData in ringmail)
                {
                    RemoteModel *rmod = [[RemoteModel alloc] init];
                    [rmod setContactId:[(NSDictionary *)remoteData objectForKey:@"id"]];
                    [rmod setTsUpdated:[NSDate date]];
                    [rmod setPrimaryUri:[(NSDictionary *)remoteData objectForKey:@"uri"]];
                    [rmod setRingMailUser:[(NSDictionary *)remoteData objectForKey:@"reg"]];
                    if ([RemoteModel hasContactId:[rmod contactId]])
                    {
                        [rmod update];
                        //NSLog(@"Updated Remote: %@", [rmod contactId]);
                    }
                    else
                    {
                        [rmod create];
                        //NSLog(@"Created Remote: %@", [rmod contactId]);
                    }
                }
            }
            
            NSArray* favList = [result objectForKey:@"favorites"];
            if (favList != nil)
            {
                NSLog(@"Updating Favorites: %@", favList);
                [FavoritesModel deleteAll];
                for (id favData in favList)
                {
                    NSNumber *favId = [NSNumber numberWithInt:[(NSString *)favData intValue]];
                    [FavoritesModel addFavorite:favId];
                }
                NSDate* remoteDate = [NSDate dateWithTimeIntervalSince1970:[[result objectForKey:@"favorites_ts"] doubleValue]];
                [RemoteModel updateRemote:RemoteItemFavorites date:remoteDate];
                LinphoneManager* mgr = [LinphoneManager instance];
                FastAddressBook* book = [mgr fastAddressBook];
                [book setupWheelContacts];
                [mgr setReloadWheels:YES];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RingMailWheelUpdated" object:self userInfo:nil];
            }
        }
    }
}

@end

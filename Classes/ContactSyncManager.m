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
    [LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC %@ check_sync %@", URL, result];
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
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    NSString *lastMod = NULL;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    NSDate *maxDate = NULL;
    int counter = 0;
    for (id person in contacts)
    {
        counter++;
        CFDateRef modDate = ABRecordCopyValue((ABRecordRef)person, kABPersonModificationDateProperty);
        if (maxDate)
        {
            if ([maxDate compare:(NSDate*) modDate] == NSOrderedAscending)
            {
                maxDate = (NSDate*)modDate;
            }
            else
            {
                CFRelease(modDate);
            }
        }
        else
        {
            maxDate = (NSDate*)modDate;
        }

    }
    if (maxDate)
    {
        lastMod = [dateFormatter stringFromDate: maxDate];
        [maxDate release];
    }
    else
    {
        lastMod = @"";
    }
    [result setObject:lastMod forKey:@"ts_update"];
    [dateFormatter release];
    [enUSPOSIXLocale release];
    [lastMod release];
    NSString *count = [NSString stringWithFormat:@"%i", counter];
    [result setObject:count forKey:@"count"];
    return result;
}

- (NSString*)contactsToJSON {
    NSMutableArray *contactsArray = [NSMutableArray array];
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
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [dateFormatter setLocale:enUSPOSIXLocale];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
        [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        CFDateRef modDate= ABRecordCopyValue((ABRecordRef)lPerson, kABPersonModificationDateProperty);
        NSString *modDateGMT = [dateFormatter stringFromDate: (NSDate*)modDate];
        [dateFormatter release];
        [enUSPOSIXLocale release];
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
    NSDictionary *final = @{ @"contacts":contactsArray, @"login":login, @"password":pass };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:final options:0 error:nil];
    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return result;
}

- (void)sendContacts
{
    NSString* result = [self contactsToJSON];
    [LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC sync_contacts %@", result];
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
    [result release];
}

- (void)processResponse:(XMLRPCResponse *)response request:(XMLRPCRequest *)request {
    [LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC %@: %@", [request method], [response body]];
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
    }
}

@end
 /* FastAddressBook.h
 *
 * Copyright (C) 2011  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or   
 *  (at your option) any later version.                                 
 *                                                                      
 *  This program is distributed in the hope that it will be useful,     
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of      
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       
 *  GNU General Public License for more details.                
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */   

#import "FastAddressBook.h"
#import "LinphoneManager.h"
#import "FavoritesModel.h"
#import "NBPhoneNumberUtil.h"

@implementation FastAddressBook

static void sync_address_book (ABAddressBookRef addressBook, CFDictionaryRef info, void *context);

+ (NSString*)getContactDisplayName:(ABRecordRef)contact {
    NSString *retString = nil;
    if (contact) {
        CFStringRef lDisplayName = ABRecordCopyCompositeName(contact);
        if(lDisplayName != NULL) {
            retString = [NSString stringWithString:(NSString*)lDisplayName];
            CFRelease(lDisplayName);
        }
    }
    return retString;
}

+ (UIImage*)getContactImage:(ABRecordRef)contact thumbnail:(BOOL)thumbnail {
    UIImage* retImage = nil;
    if (contact && ABPersonHasImageData(contact)) {
        CFDataRef imgData = ABPersonCopyImageDataWithFormat(contact, thumbnail? 
                                                            kABPersonImageFormatThumbnail: kABPersonImageFormatOriginalSize);
        
        retImage = [UIImage imageWithData:(NSData *)imgData];
        if(imgData != NULL) {
            CFRelease(imgData);
        }
    }
    return retImage;
}

- (ABRecordRef)getContact:(NSString*)address {
    @synchronized (addressBookMap){
        return (ABRecordRef)[addressBookMap objectForKey:address];   
    } 
}

- (ABRecordRef)getContactById:(NSNumber*)itemId {
    @synchronized (addressBookMap){
        return (ABRecordRef)[addressBookIds objectForKey:itemId];
    }
}

+ (BOOL)isSipURI:(NSString*)address {
    return [address hasPrefix:@"sip:"];
}

+ (NSString*)appendCountryCodeIfPossible:(NSString*)number {
    if (![number hasPrefix:@"+"] && ![number hasPrefix:@"00"]) {
        NSString* lCountryCode = [[LinphoneManager instance] lpConfigStringForKey:@"countrycode_preference"];
        if (lCountryCode && [lCountryCode length]>0) {
            //append country code
            return [lCountryCode stringByAppendingString:number];
        }
    }
    return number;
}

+ (NSString*)normalizeSipURI:(NSString*)address {
    NSString *normalizedSipAddress = nil;
	LinphoneAddress* linphoneAddress = linphone_core_interpret_url([LinphoneManager getLc], [address UTF8String]);
    if(linphoneAddress != NULL) {
        char *tmp = linphone_address_as_string_uri_only(linphoneAddress);
        if(tmp != NULL) {
            normalizedSipAddress = [NSString stringWithUTF8String:tmp];
            ms_free(tmp);
        }
        linphone_address_destroy(linphoneAddress);
    }
    return normalizedSipAddress;
}

+ (NSString*)normalizePhoneNumber:(NSString*)address {
    NSMutableString* lNormalizedAddress = [NSMutableString stringWithString:address];
    [lNormalizedAddress replaceOccurrencesOfString:@" " 
                                        withString:@"" 
                                           options:0
                                             range:NSMakeRange(0, [lNormalizedAddress length])];
    [lNormalizedAddress replaceOccurrencesOfString:@"(" 
                                        withString:@"" 
                                           options:0
                                             range:NSMakeRange(0, [lNormalizedAddress length])];
    [lNormalizedAddress replaceOccurrencesOfString:@")" 
                                        withString:@"" 
                                           options:0
                                             range:NSMakeRange(0, [lNormalizedAddress length])];
    [lNormalizedAddress replaceOccurrencesOfString:@"-" 
                                        withString:@"" 
                                           options:0
                                             range:NSMakeRange(0, [lNormalizedAddress length])];
    return [FastAddressBook appendCountryCodeIfPossible:lNormalizedAddress];
}

+ (BOOL)isAuthorized {
    return !ABAddressBookGetAuthorizationStatus || ABAddressBookGetAuthorizationStatus() ==  kABAuthorizationStatusAuthorized;
}

- (FastAddressBook*)init {
    if ((self = [super init]) != nil) {
        addressBookMap  = [[NSMutableDictionary alloc] init];
        addressBookIds  = [[NSMutableDictionary alloc] init];
        addressBookWheels  = [[NSMutableDictionary alloc] init];
        [self reload];
        [self setupWheelContacts];
    }
    return self;
}

- (void)reload {
    if(addressBook != nil) {
        ABAddressBookUnregisterExternalChangeCallback(addressBook, sync_address_book, self);
        CFRelease(addressBook);
        addressBook = nil;
    }
    NSError *error = nil;
    if(ABAddressBookCreateWithOptions) {
        addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    } else {
        addressBook = ABAddressBookCreate();
    }
    if(addressBook != NULL) {
        if(ABAddressBookGetAuthorizationStatus) {
            ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
                ABAddressBookRegisterExternalChangeCallback (addressBook, sync_address_book, self);
                [self loadData];
            });
        } else {
            ABAddressBookRegisterExternalChangeCallback (addressBook, sync_address_book, self);
            [self loadData];
        }
    } else {
        [LinphoneLogger log:LinphoneLoggerError format:@"Create AddressBook: Fail(%@)", [error localizedDescription]];
    }
}

- (void)loadData {
    ABAddressBookRevert(addressBook);
    @synchronized (addressBookMap) {
        [addressBookIds removeAllObjects];
        [addressBookMap removeAllObjects];
        [addressBookWheels removeAllObjects];
        
        NSArray *lContacts = (NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook);
        for (id lPerson in lContacts) {
            // Ids
            {
                NSNumber *recordId = [NSNumber numberWithInteger:ABRecordGetRecordID((ABRecordRef)lPerson)];
                [addressBookIds setObject:lPerson forKey:recordId];
            }
            
            // Phone
            {
                ABMultiValueRef lMap = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonPhoneProperty);
                if(lMap) {
                    for (int i=0; i<ABMultiValueGetCount(lMap); i++) {
                        CFStringRef lValue = ABMultiValueCopyValueAtIndex(lMap, i);
                        //CFStringRef lLabel = ABMultiValueCopyLabelAtIndex(lMap, i);
                        //CFStringRef lLocalizedLabel = ABAddressBookCopyLocalizedLabel(lLabel);
                        //NSString* lNormalizedKey = [FastAddressBook normalizePhoneNumber:(NSString*)lValue];
                        NSString* lNormalizedKey = [FastAddressBook e164number:(NSString*)lValue];
                        if (lNormalizedKey != nil)
                        {
                            [addressBookMap setObject:lPerson forKey:lNormalizedKey];
                        }
                        CFRelease(lValue);
                        //if (lLabel) CFRelease(lLabel);
                        //if (lLocalizedLabel) CFRelease(lLocalizedLabel);
                    }
                    CFRelease(lMap);
                }
            }
            
            // Email
            {
                
                ABMultiValueRef lMap = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonEmailProperty);
                if(lMap) {
                    for(int i = 0; i < ABMultiValueGetCount(lMap); i++) {
                        CFStringRef valueRef = ABMultiValueCopyValueAtIndex(lMap, i);
                        if (valueRef) {
                            [addressBookMap setObject:lPerson forKey:(NSString *)valueRef];
                            CFRelease(valueRef);
                        }
                    }
                    CFRelease(lMap);
                }
            }
            
            // SIP
            /*{
                ABMultiValueRef lMap = ABRecordCopyValue((ABRecordRef)lPerson, kABPersonInstantMessageProperty);
                if(lMap) {
                    for(int i = 0; i < ABMultiValueGetCount(lMap); ++i) {
                        CFDictionaryRef lDict = ABMultiValueCopyValueAtIndex(lMap, i);
                        BOOL add = false;
                        if(CFDictionaryContainsKey(lDict, kABPersonInstantMessageServiceKey)) {
                            if(CFStringCompare((CFStringRef)kContactSipField, CFDictionaryGetValue(lDict, kABPersonInstantMessageServiceKey), kCFCompareCaseInsensitive) == 0) {
                                add = true;
                            }
                        } else {
                            add = true;
                        }
                        if(add) {
                            CFStringRef lValue = CFDictionaryGetValue(lDict, kABPersonInstantMessageUsernameKey);
                            NSString* lNormalizedKey = [FastAddressBook normalizeSipURI:(NSString*)lValue];
                            if(lNormalizedKey != NULL) {
                                [addressBookMap setObject:lPerson forKey:lNormalizedKey];
                            } else {
                                [addressBookMap setObject:lPerson forKey:(NSString*)lValue];
                            }
                        }
                        CFRelease(lDict);
                    }
                    CFRelease(lMap);   
                }
            }*/
        }
        CFRelease(lContacts);
        NSLog(@"Contact Map: %@", [addressBookMap allKeys]);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kLinphoneAddressBookUpdate object:self];
}

void sync_address_book (ABAddressBookRef addressBook, CFDictionaryRef info, void *context) {
    FastAddressBook* fastAddressBook = (FastAddressBook*)context;
    [fastAddressBook loadData];
}

- (void)dealloc {
    ABAddressBookUnregisterExternalChangeCallback(addressBook, sync_address_book, self);
    CFRelease(addressBook);
    [addressBookMap release];
    [addressBookIds release];
    [addressBookWheels release];
    [super dealloc];
}

#pragma mark - RingMail

+ (NSString *) getPrimaryTarget:(ABRecordRef)contact {
    NSString *res = nil;
    if (contact)
    {
        ABMultiValueRef emailMap = ABRecordCopyValue((ABRecordRef)contact, kABPersonEmailProperty);
        if (emailMap)
        {
            CFStringRef valueRef = ABMultiValueCopyValueAtIndex(emailMap, 0);
            if (valueRef)
            {
                res = (NSString *)valueRef;
                CFRelease(valueRef);
            }
            CFRelease(emailMap);
        }
        if (! res)
        {
            ABMultiValueRef phoneMap = ABRecordCopyValue((ABRecordRef)contact, kABPersonPhoneProperty);
            if (phoneMap)
            {
                CFStringRef valueRef = ABMultiValueCopyValueAtIndex(phoneMap, 0);
                if (valueRef)
                {
                    res = (NSString *)valueRef;
                    CFRelease(valueRef);
                }
                CFRelease(phoneMap);
            }
        }
    }
    if (! res)
    {
        res = @"";
    }
    return res;
}

- (NSMutableArray*) getWheel:(NSString*)name
{
    return [addressBookWheels objectForKey:name];
}

- (void) setupWheelContacts
{
    NSLog(@"Setup Wheel Contacts");
    ABAddressBookRef addressBookList = ABAddressBookCreateWithOptions(NULL, nil);
    NSArray *contactList = (NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBookList);
    NSMutableDictionary* contactLookup = [NSMutableDictionary dictionaryWithCapacity:[contactList count]];
    for (id person in contactList)
    {
        CFStringRef lFirstName = ABRecordCopyValue((ABRecordRef)person, kABPersonFirstNameProperty);
        CFStringRef lLocalizedFirstName = (lFirstName != nil) ? ABAddressBookCopyLocalizedLabel(lFirstName) : nil;
        NSString *shortName = nil;
        if(lLocalizedFirstName != nil)
        {
            shortName = [NSString stringWithString:(NSString *)lLocalizedFirstName];
            CFRelease(lLocalizedFirstName);
        }
        if(shortName != nil)
        {
            NSNumber *recordId = [NSNumber numberWithInteger:ABRecordGetRecordID((ABRecordRef)person)];
            NSMutableDictionary *ctItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:shortName, @"name", recordId, @"id", nil];
            [contactLookup setObject:ctItem forKey:recordId];
            UIImage* image = [FastAddressBook getContactImage:person thumbnail:true];
            if(image != nil) {
                [ctItem setObject:[self imageWithAlpha:image] forKey:@"img"];
            }
        }
        if(lFirstName != nil)
        {
            CFRelease(lFirstName);
        }
    }
    CFRelease(contactList);

    NSMutableArray* favorites = [FavoritesModel getFavorites];
    NSMutableArray* favList = [NSMutableArray arrayWithCapacity:[favorites count]];
    for (id favId in favorites)
    {
        NSNumber* fav = (NSNumber*)favId;
        NSMutableDictionary* ctItem = [contactLookup objectForKey:fav];
        if (ctItem != nil)
        {
            [favList addObject:ctItem];
        }
    }
    // sort favorites
    NSArray *sortedFavorites = [favList sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *first = [(NSMutableDictionary*)a objectForKey:@"name"];
        NSString *second = [(NSMutableDictionary*)b objectForKey:@"name"];
        return [first compare:second];
    }];
    NSMutableArray *favArray = [NSMutableArray arrayWithArray:sortedFavorites];
    int favCount = [favArray count];
    if (favCount < 8)
    {
        for (int i = 0; i < (8 - favCount); i++)
        {
            [favArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:@"", @"name", nil]];
        }
    }
    [addressBookWheels setObject:favArray forKey:@"favorites"];
}

- (UIImage *)imageWithAlpha:(UIImage *)img
{
    if ([self hasAlpha:img]) {
        return img;
    }
    
    CGFloat scale = MAX(img.scale, 1.0f);
    CGImageRef imageRef = img.CGImage;
    size_t width = CGImageGetWidth(imageRef)*scale;
    size_t height = CGImageGetHeight(imageRef)*scale;
    
    // The bitsPerComponent and bitmapInfo values are hard-coded to prevent an "unsupported parameter combination" error
    CGContextRef offscreenContext = CGBitmapContextCreate(NULL,
                                                          width,
                                                          height,
                                                          8,
                                                          0,
                                                          CGImageGetColorSpace(imageRef),
                                                          kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
    
    // Draw the image into the context and retrieve the new image, which will now have an alpha layer
    CGContextDrawImage(offscreenContext, CGRectMake(0, 0, width, height), imageRef);
    CGImageRef imageRefWithAlpha = CGBitmapContextCreateImage(offscreenContext);
    UIImage *imageWithAlpha = [UIImage imageWithCGImage:imageRefWithAlpha scale:img.scale orientation:UIImageOrientationUp];
    
    // Clean up
    CGContextRelease(offscreenContext);
    CGImageRelease(imageRefWithAlpha);
    
    return imageWithAlpha;
}

- (BOOL)hasAlpha:(UIImage *)img
{
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(img.CGImage);
    return (alpha == kCGImageAlphaFirst ||
            alpha == kCGImageAlphaLast ||
            alpha == kCGImageAlphaPremultipliedFirst ||
            alpha == kCGImageAlphaPremultipliedLast);
}

+ (NSString *)e164number:(NSString *)numberIn
{
    NBPhoneNumberUtil *phoneUtil = [NBPhoneNumberUtil sharedInstance];
    NSError *aError = nil;
    NSString *numberOut = nil;
    NBPhoneNumber *myNumber = [phoneUtil parse:numberIn defaultRegion:@"US" error:&aError];
    if (aError == nil)
    {
        numberOut = [phoneUtil format:myNumber numberFormat:NBEPhoneNumberFormatE164 error:&aError];
    }
    if (aError != nil)
    {
        NSLog(@"PhoneNumberUtil Error: %@", [aError localizedDescription]);
    }
    return numberOut;
}

+ (NSString *)getTargetFromSIP:(NSString *)sipURI
{
    NSError *error = NULL;
    NSRegularExpression *regex1 = [NSRegularExpression regularExpressionWithPattern:@"^sip\\:" options:NSRegularExpressionCaseInsensitive error:&error];
    NSString *str1 = [regex1 stringByReplacingMatchesInString:sipURI options:0 range:NSMakeRange(0, [sipURI length]) withTemplate:@""];
    NSRegularExpression *regex2 = [NSRegularExpression regularExpressionWithPattern:@"\\@sip\\.ringmail\\.com$" options:NSRegularExpressionCaseInsensitive error:&error];
    NSString *str2 = [regex2 stringByReplacingMatchesInString:str1 options:0 range:NSMakeRange(0, [str1 length]) withTemplate:@""];
    NSRegularExpression *regex3 = [NSRegularExpression regularExpressionWithPattern:@"\\%40" options:NSRegularExpressionCaseInsensitive error:&error];
    NSString *str3 = [regex3 stringByReplacingMatchesInString:str2 options:0 range:NSMakeRange(0, [str2 length]) withTemplate:@"@"];
    return str3;
}

@end

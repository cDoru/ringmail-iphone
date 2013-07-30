/* DirectoryViewController.m
 *
 * Copyright (C) 2013 DYL
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

#import "DirectoryViewController.h"
#import "PhoneMainView.h"

#include "linphonecore.h"

@implementation DirectoryViewController

@synthesize webview;

#pragma mark - Lifecycle Functions

- (id)init {
    self = [super initWithNibName:@"DirectoryViewController" bundle:[NSBundle mainBundle]];
    if (self != nil)
    {
        loaded = 0;
        locationManager = [[CLLocationManager alloc] init];
        locationManager.delegate = self;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [webview release];
    [locationManager release];
    [super dealloc];
}

#pragma mark - ViewController Functions

- (void)viewDidLoad {
    webview.delegate = self;
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [locationManager startUpdatingLocation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}


#pragma mark - Event Functions


#pragma mark - UICompositeViewDelegate Functions

static UICompositeViewDescription *compositeDescription = nil;

+ (UICompositeViewDescription *)compositeViewDescription {
    if(compositeDescription == nil) {
        compositeDescription = [[UICompositeViewDescription alloc] init:@"Directory" 
                                                                content:@"DirectoryViewController" 
                                                               stateBar:nil 
                                                        stateBarEnabled:false 
                                                                 tabBar: @"UIMainBar" 
                                                          tabBarEnabled:true 
                                                             fullscreen:false
                                                          landscapeMode:[LinphoneManager runningOnIpad]
                                                           portraitMode:true];
    }
    return compositeDescription;
}

#pragma mark - CLLocationManagerDelegate Functions

CLLocationManager *locationManager;

- (void) discardLocationManager
{
    locationManager.delegate = nil;
}

- (void) locationManagerDone
{
    [locationManager stopUpdatingLocation];
    [self performSelector:@selector(discardLocationManager) onThread:[NSThread currentThread] withObject:nil waitUntilDone:NO];
}

- (void) loadDirectory:(NSString*)latitude longitude:(NSString*)longitude
{
    if (loaded)
    {
        // Update location
    }
    else
    {
        LinphoneCore* lc = [LinphoneManager getLc];
        LinphoneProxyConfig *cfg=NULL;
        linphone_core_get_default_proxy(lc,&cfg);
        NSString *login = NULL;
        NSString *password = NULL;
        if (cfg)
        {
            const char *identity=linphone_proxy_config_get_identity(cfg);
            LinphoneAddress *addr=linphone_address_new(identity);
            if (addr)
            {
                const char *username = linphone_address_get_username(addr);
                login = [[NSString alloc] initWithCString:username encoding:[NSString defaultCStringEncoding]];
                [login autorelease];
                linphone_address_destroy(addr);
                {
                    LinphoneAuthInfo *ai;
                    const MSList *elem=linphone_core_get_auth_info_list(lc);
                    if (elem && (ai=(LinphoneAuthInfo*)elem->data)){
                        const char *pass = linphone_auth_info_get_passwd(ai);
                        password = [[NSString alloc] initWithCString:pass encoding:[NSString defaultCStringEncoding]];
                        [password autorelease];
                    }
                }
            }
        }
        NSMutableString *fullURL = [[NSMutableString alloc] initWithString: @"https://app.ringmail.com/dir/cat?v=1"];
        if (login && password)
        {
            [fullURL appendFormat:@"&l=%@&p=%@", [self URLEncodedString_ch:login], [self URLEncodedString_ch:password]];
        }
        if (longitude && latitude)
        {
            [fullURL appendFormat:@"&la=%@&lo=%@", latitude, longitude];
        }
        [LinphoneLogger logc:LinphoneLoggerLog format:"RingMail Directory URL: %@", fullURL];
        NSURL *url = [NSURL URLWithString:fullURL];
        NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
        [fullURL release];
        [webview loadRequest:requestObj];
        loaded = 1;
    }
}

- (NSString *) URLEncodedString_ch:(NSString*)input {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[input UTF8String];
    int sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    NSString *longitude;
    NSString *latitude;
    longitude = [NSString stringWithFormat:@"%.8f", newLocation.coordinate.longitude];
    latitude = [NSString stringWithFormat:@"%.8f", newLocation.coordinate.latitude];
    [LinphoneLogger logc:LinphoneLoggerLog format:"Location Found: %@ x %@", latitude, longitude];
    [self locationManagerDone];
    [self loadDirectory:latitude longitude:longitude];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [LinphoneLogger logc:LinphoneLoggerLog format:"Location Error: %@", error];
    [self locationManagerDone];
    [self loadDirectory:NULL longitude:NULL];
}

#pragma mark - Action Functions

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        NSString *url = [[request URL] absoluteString];
        //[LinphoneLogger logc:LinphoneLoggerLog format:"Clicked Link: %@", url];
        NSPredicate *check = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^https://app\\.ringmail\\.com.*"];
        if ([check evaluateWithObject:url])
        {
            return YES;
        }
        else
        {
            [[UIApplication sharedApplication] openURL:[request URL]];
            return NO;
        }
    }
    return YES;
}

@end

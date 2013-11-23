/* WizardViewController.m
 *
 * Copyright (C) 2012  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or   
 *  (at your option) any later version.                                 
 *                                                                      
 *  This program is distributed in the hope that it will be useful,     
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of      
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       
 *  GNU Library General Public License for more details.                
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */ 

#import "WizardViewController.h"
#import "LinphoneManager.h"
#import "PhoneMainView.h"
#import "ChatModel.h"
#import "ValidationModel.h"

#import <XMLRPCConnection.h>
#import <XMLRPCConnectionManager.h>
#import <XMLRPCResponse.h>
#import <XMLRPCRequest.h>

typedef enum _ViewElement {
    ViewElement_Name = 100,
    ViewElement_Username = 101, // Unused
    ViewElement_Email = 102,
    ViewElement_Phone = 103,
    ViewElement_Password = 104,
    ViewElement_Password2 = 105,
    ViewElement_PhoneVerify = 106,
    ViewElement_Domain = 104, // Unused
    ViewElement_Label = 200,
    ViewElement_Error = 201
} ViewElement;

@implementation WizardViewController

@synthesize contentView;

@synthesize welcomeView;
@synthesize choiceView;
@synthesize createAccountView;
@synthesize connectAccountView;
@synthesize externalAccountView;
@synthesize validateAccountView;
@synthesize validatePhoneView;

@synthesize waitView;

@synthesize backButton;
@synthesize startButton;
@synthesize createAccountButton;
@synthesize connectAccountButton;
@synthesize externalAccountButton;

@synthesize choiceViewLogoImageView;
// @synthesize createAccountViewEmailField;

@synthesize viewTapGestureRecognizer;


#pragma mark - Lifecycle Functions

- (id)init {
    self = [super initWithNibName:@"WizardViewController" bundle:[NSBundle mainBundle]];
    if (self != nil) {
        [[NSBundle mainBundle] loadNibNamed:@"WizardViews"
                                      owner:self
                                    options:nil];
        self->historyViews = [[NSMutableArray alloc] init];
        self->currentView = nil;
        self->viewTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onViewTap:)];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [contentView release];
    
    [welcomeView release];
    [choiceView release];
    [createAccountView release];
    [connectAccountView release];
    [externalAccountView release];
    [validateAccountView release];
    
    [waitView release];
    
    [backButton release];
    [startButton release];
    [createAccountButton release];
    [connectAccountButton release];
    [externalAccountButton release];

    [choiceViewLogoImageView release];
//    [createAccountViewEmailField release];
    
    [historyViews release];
    
    [viewTapGestureRecognizer release];
    
    [super dealloc];
}


#pragma mark - UICompositeViewDelegate Functions

static UICompositeViewDescription *compositeDescription = nil;

+ (UICompositeViewDescription *)compositeViewDescription {
    if(compositeDescription == nil) {
        compositeDescription = [[UICompositeViewDescription alloc] init:@"Wizard" 
                                                                content:@"WizardViewController" 
                                                               stateBar:nil 
                                                        stateBarEnabled:false 
                                                                 tabBar:nil 
                                                          tabBarEnabled:false 
                                                             fullscreen:false
                                                          landscapeMode:[LinphoneManager runningOnIpad]
                                                           portraitMode:true];
    }
    return compositeDescription;
}


#pragma mark - ViewController Functions

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(registrationUpdateEvent:)
                                                 name:kLinphoneRegistrationUpdate
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:kLinphoneRegistrationUpdate
                                               object:nil];
    
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [viewTapGestureRecognizer setCancelsTouchesInView:FALSE];
    [viewTapGestureRecognizer setDelegate:self];
    [contentView addGestureRecognizer:viewTapGestureRecognizer];
    
    if([LinphoneManager runningOnIpad]) {
        [LinphoneUtils adjustFontSize:welcomeView mult:2.22f];
        [LinphoneUtils adjustFontSize:choiceView mult:2.22f];
        [LinphoneUtils adjustFontSize:createAccountView mult:2.22f];
        [LinphoneUtils adjustFontSize:connectAccountView mult:2.22f];
        [LinphoneUtils adjustFontSize:externalAccountView mult:2.22f];
        [LinphoneUtils adjustFontSize:validateAccountView mult:2.22f];
        [LinphoneUtils adjustFontSize:validatePhoneView mult:2.22f];
    }
}


#pragma mark -

+ (void)cleanTextField:(UIView*)view {
    if([view isKindOfClass:[UITextField class]]) {
        [(UITextField*)view setText:@""];
    } else {
        for(UIView *subview in view.subviews) {
            [WizardViewController cleanTextField:subview];
        }
    }
}

- (void)reset {
    [self clearProxyConfig];
    [[LinphoneManager instance] lpConfigSetBool:FALSE forKey:@"pushnotification_preference"];
    
    LinphoneCore *lc = [LinphoneManager getLc];
    LCSipTransports transportValue={0};
    transportValue.udp_port=5060;
    transportValue.tls_port=0;
    transportValue.tcp_port=0;
    
    if (linphone_core_set_sip_transports(lc, &transportValue)) {
        [LinphoneLogger logc:LinphoneLoggerError format:"cannot set transport"];
    }
    
    [[LinphoneManager instance] lpConfigSetBool:TRUE forKey:@"debugenable_preference"];
    [[LinphoneManager instance] lpConfigSetString:@"" forKey:@"sharing_server_preference"];
    [[LinphoneManager instance] lpConfigSetBool:FALSE forKey:@"ice_preference"];
    [[LinphoneManager instance] lpConfigSetString:@"" forKey:@"stun_preference"];
    linphone_core_set_stun_server(lc, NULL);
    linphone_core_set_firewall_policy(lc, LinphonePolicyNoFirewall);
    [WizardViewController cleanTextField:welcomeView];
    [WizardViewController cleanTextField:choiceView];
    [WizardViewController cleanTextField:createAccountView];
    [WizardViewController cleanTextField:connectAccountView];
    [WizardViewController cleanTextField:externalAccountView];
    [WizardViewController cleanTextField:validateAccountView];
    [self changeView:choiceView back:FALSE animation:FALSE];
    
    // Remove database file
    linphone_core_clear_call_logs(lc);
    [ChatModel removeConversation:nil];
    LinphoneManager* mgr = [LinphoneManager instance];
    [mgr closeDatabase];
    [mgr removeDatabase];
    [mgr openDatabase];
    
    if ([ValidationModel hasData])
    {
        NSDictionary *res = [ValidationModel readData];
        NSString *phoneValid = [res objectForKey:@"valid_phone"];
        if ([phoneValid isEqualToString:@"yes"] || [phoneValid isEqualToString:@"skip"])
        {
            // Go to email validation
            [self changeView:validateAccountView back:FALSE animation:FALSE];
        }
        else
        {
            [self changeView:validatePhoneView back:FALSE animation:FALSE];
        }
    }
    
    [waitView setHidden:TRUE];
}

+ (UIView*)findView:(ViewElement)tag view:(UIView*)view {
    for(UIView *child in [view subviews]) {
        if([child tag] == tag){
            return (UITextField*)child;
        } else {
            UIView *o = [WizardViewController findView:tag view:child];
            if(o)
                return o;
        }
    }
    return nil;
}

+ (UITextField*)findTextField:(ViewElement)tag view:(UIView*)view {
    UIView *aview = [WizardViewController findView:tag view:view];
    if([aview isKindOfClass:[UITextField class]])
        return (UITextField*)aview;
    return nil;
}

+ (UILabel*)findLabel:(ViewElement)tag view:(UIView*)view {
    UIView *aview = [WizardViewController findView:tag view:view];
    if([aview isKindOfClass:[UILabel class]])
        return (UILabel*)aview;
    return nil;
}

- (void)clearHistory {
    [historyViews removeAllObjects];
}

- (void)changeView:(UIView *)view back:(BOOL)back animation:(BOOL)animation {
    // Change toolbar buttons following view
    if (view == welcomeView) {
        [startButton setHidden:false];
        [backButton setHidden:true];
    } else {
        [startButton setHidden:true];
        [backButton setHidden:false];
    }
    
    if (view == validateAccountView ||
        view == validatePhoneView ||
        view == choiceView
    ) {
        [backButton setEnabled:FALSE];
    } else {
        [backButton setEnabled:TRUE];
    }

    /*if (view == choiceView) {
        if ([[LinphoneManager instance] lpConfigBoolForKey:@"show_wizard_logo_in_choice_view_preference"] == true) {
            [choiceViewLogoImageView setHidden:FALSE];
        }
        if ([[LinphoneManager instance] lpConfigBoolForKey:@"hide_wizard_custom_account_button_preference"] == true) {
            [externalAccountButton setHidden:TRUE];
            if ([externalAccountButton center].y != [connectAccountButton center].y) {
                if ([[LinphoneManager instance] lpConfigBoolForKey:@"show_wizard_logo_in_choice_view_preference"] == true) {
                    [createAccountButton setCenter: [connectAccountButton center]];
                }
                [connectAccountButton setCenter: [externalAccountButton center]];
            }
        }
    }*/

    // Animation
    if(animation && [[LinphoneManager instance] lpConfigBoolForKey:@"animations_preference"] == true) {
      CATransition* trans = [CATransition animation];
      [trans setType:kCATransitionPush];
      [trans setDuration:0.35];
      [trans setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
      if(back) {
          [trans setSubtype:kCATransitionFromLeft];
      }else {
          [trans setSubtype:kCATransitionFromRight];
      }
      [contentView.layer addAnimation:trans forKey:@"Transition"];
    }
    
    // Stack current view
    if(currentView != nil) {
        if(!back)
            [historyViews addObject:currentView];
        [currentView removeFromSuperview];
    }
    
    // Set current view
    currentView = view;
    [contentView insertSubview:view atIndex:0];
    [view setFrame:[contentView bounds]];
    [contentView setContentSize:[view bounds].size];
}

- (void)clearProxyConfig {
	linphone_core_clear_proxy_config([LinphoneManager getLc]);
	linphone_core_clear_all_auth_info([LinphoneManager getLc]);
}

- (void)setDefaultSettings:(LinphoneProxyConfig*)proxyCfg {
    BOOL pushnotification = [[LinphoneManager instance] lpConfigBoolForKey:@"push_notification" forSection:@"wizard"];
    [[LinphoneManager instance] lpConfigSetBool:pushnotification forKey:@"pushnotification_preference"];
    if(pushnotification) {
        [[LinphoneManager instance] addPushTokenToProxyConfig:proxyCfg];
    }
    int expires = [[LinphoneManager instance] lpConfigIntForKey:@"expires" forSection:@"wizard"];
    linphone_proxy_config_expires(proxyCfg, expires);
    
    NSString* transport = [[LinphoneManager instance] lpConfigStringForKey:@"transport" forSection:@"wizard"];
    LinphoneCore *lc = [LinphoneManager getLc];
    LCSipTransports transportValue={0};
	if (transport!=nil) {
		if (linphone_core_get_sip_transports(lc, &transportValue)) {
			[LinphoneLogger logc:LinphoneLoggerError format:"cannot get current transport"];
		}
		// Only one port can be set at one time, the others's value is 0
		if ([transport isEqualToString:@"tcp"]) {
			transportValue.tcp_port=transportValue.tcp_port|transportValue.udp_port|transportValue.tls_port;
			transportValue.udp_port=0;
            transportValue.tls_port=0;
		} else if ([transport isEqualToString:@"udp"]){
			transportValue.udp_port=transportValue.tcp_port|transportValue.udp_port|transportValue.tls_port;
			transportValue.tcp_port=0;
            transportValue.tls_port=0;
		} else if ([transport isEqualToString:@"tls"]){
			transportValue.tls_port=transportValue.tcp_port|transportValue.udp_port|transportValue.tls_port;
			transportValue.tcp_port=0;
            transportValue.udp_port=0;
		} else {
			[LinphoneLogger logc:LinphoneLoggerError format:"unexpected transport [%s]",[transport cStringUsingEncoding:[NSString defaultCStringEncoding]]];
		}
		if (linphone_core_set_sip_transports(lc, &transportValue)) {
			[LinphoneLogger logc:LinphoneLoggerError format:"cannot set transport"];
		}
	}
    
    NSString* sharing_server = [[LinphoneManager instance] lpConfigStringForKey:@"sharing_server" forSection:@"wizard"];
    [[LinphoneManager instance] lpConfigSetString:sharing_server forKey:@"sharing_server_preference"];
    
    BOOL ice = [[LinphoneManager instance] lpConfigBoolForKey:@"ice" forSection:@"wizard"];
    [[LinphoneManager instance] lpConfigSetBool:ice forKey:@"ice_preference"];
    
    NSString* stun = [[LinphoneManager instance] lpConfigStringForKey:@"stun" forSection:@"wizard"];
    [[LinphoneManager instance] lpConfigSetString:stun forKey:@"stun_preference"];
    
    if ([stun length] > 0){
        linphone_core_set_stun_server(lc, [stun UTF8String]);
        if(ice) {
            linphone_core_set_firewall_policy(lc, LinphonePolicyUseIce);
        } else {
            linphone_core_set_firewall_policy(lc, LinphonePolicyUseStun);
        }
    } else {
        linphone_core_set_stun_server(lc, NULL);
        linphone_core_set_firewall_policy(lc, LinphonePolicyNoFirewall);
    }
}

- (void)addProxyConfig:(NSString*)username password:(NSString*)password domain:(NSString*)domain server:(NSString*)server {
    [self clearProxyConfig];
    if(server == nil) {
        server = domain;
    }
    char normalizedUserName[256];
    LinphoneAddress* linphoneAddress = linphone_address_new("sip:user@domain.com");
    linphone_proxy_config_normalize_number(NULL, [username cStringUsingEncoding:[NSString defaultCStringEncoding]], normalizedUserName, sizeof(normalizedUserName));
    linphone_address_set_username(linphoneAddress, normalizedUserName);
    linphone_address_set_domain(linphoneAddress, [domain UTF8String]);
    const char* identity = linphone_address_as_string_uri_only(linphoneAddress);
	LinphoneProxyConfig* proxyCfg = linphone_core_create_proxy_config([LinphoneManager getLc]);
	NSString* addressSipUri = [NSString stringWithUTF8String:linphone_address_as_string_uri_only(linphoneAddress)];
	NSString* addressSipScheme = [NSString stringWithUTF8String:linphone_address_get_scheme(linphoneAddress)];
	addressSipUri = [addressSipUri substringFromIndex:([addressSipScheme length] + 1)];
	NSRange range = [addressSipUri rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"@"]];
	addressSipUri = [addressSipUri substringToIndex:range.location];
	LinphoneAuthInfo* info = linphone_auth_info_new([username UTF8String], [addressSipUri cStringUsingEncoding:[NSString defaultCStringEncoding]], [password UTF8String], NULL, NULL);
	linphone_proxy_config_set_identity(proxyCfg, identity);
	linphone_proxy_config_set_server_addr(proxyCfg, [server UTF8String]);
    if([server compare:domain options:NSCaseInsensitiveSearch] != 0) {
        linphone_proxy_config_set_route(proxyCfg, [server UTF8String]);
    }
    int defaultExpire = [[LinphoneManager instance] lpConfigIntForKey:@"default_expires"];
    if (defaultExpire >= 0)
        linphone_proxy_config_expires(proxyCfg, defaultExpire);
    if([domain compare:[[LinphoneManager instance] lpConfigStringForKey:@"domain" forSection:@"wizard"] options:NSCaseInsensitiveSearch] == 0) {
        [self setDefaultSettings:proxyCfg];
    }
    linphone_proxy_config_enable_register(proxyCfg, true);
    linphone_core_add_proxy_config([LinphoneManager getLc], proxyCfg);
	linphone_core_set_default_proxy([LinphoneManager getLc], proxyCfg);
	linphone_core_add_auth_info([LinphoneManager getLc], info);
}

- (void)configureCodecs: (const MSList *)codecs {
    LinphoneCore *lc = [LinphoneManager getLc];
 	const MSList *elem = codecs;
	for(;elem != NULL; elem = elem->next) {
		PayloadType *pt = (PayloadType*)elem->data;
        if (
            (strcmp(pt->mime_type, "PCMU") == 0) ||
            (strcmp(pt->mime_type, "opus") == 0) ||
            (strcmp(pt->mime_type, "H264") == 0)
        ) {
            linphone_core_enable_payload_type(lc, pt, true);
        } else {
            linphone_core_enable_payload_type(lc, pt, false);
        }
    }
}

- (void)setCodecsConfig {
    LinphoneCore *lc = [LinphoneManager getLc];
    [self configureCodecs: linphone_core_get_audio_codecs(lc)];
    [self configureCodecs: linphone_core_get_video_codecs(lc)];
}

- (NSString*)identityFromUsername:(NSString*)username {
    char normalizedUserName[256];
    LinphoneAddress* linphoneAddress = linphone_address_new("sip:user@domain.com");
    linphone_proxy_config_normalize_number(NULL, [username cStringUsingEncoding:[NSString defaultCStringEncoding]], normalizedUserName, sizeof(normalizedUserName));
    linphone_address_set_username(linphoneAddress, normalizedUserName);
    linphone_address_set_domain(linphoneAddress, [[[LinphoneManager instance] lpConfigStringForKey:@"domain" forSection:@"wizard"] UTF8String]);
    NSString* uri = [NSString stringWithUTF8String:linphone_address_as_string_uri_only(linphoneAddress)];
    NSString* scheme = [NSString stringWithUTF8String:linphone_address_get_scheme(linphoneAddress)];
    return [uri substringFromIndex:[scheme length] + 1];
}

- (void)checkUserExist:(NSString*)email phone:(NSString*)phone {
    [LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC check_account %@", email];
    
    NSURL *URL = [NSURL URLWithString:[[LinphoneManager instance] lpConfigStringForKey:@"service_url" forSection:@"wizard"]];
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithURL: URL];
    [request setMethod: @"check_account_with_phone" withParameters:[NSArray arrayWithObjects:email, phone,  nil]];
    
    XMLRPCConnectionManager *manager = [XMLRPCConnectionManager sharedManager];
    [manager spawnConnectionWithXMLRPCRequest: request delegate: self];
    
    [request release];
    [waitView setHidden:false];
}

- (NSString*)contactsToJSON {
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, nil);
    NSArray *lContacts = (NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook);
    NSMutableArray *contactsArray = [NSMutableArray array];
    for (id lPerson in lContacts) {
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
    CFRelease(lContacts);
    CFRelease(addressBook);
    NSDictionary *final = @{ @"contacts":contactsArray };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:final options:0 error:nil];
    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [result autorelease];
    return result;
}

- (void)createAccount:(NSString*)identity password:(NSString*)password email:(NSString*)email phone:(NSString*)phone name:(NSString*)name{
    NSString *useragent = [LinphoneManager getUserAgent];
    NSString *contacts = NULL;
    if ([FastAddressBook isAuthorized])
    {
        contacts = [self contactsToJSON];
    }
    else
    {
        contacts = @"{\"contacts\":[]}";
    }
    [LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC create_account_with_contacts %@ %@ %@ %@ %@", email, password, useragent, phone, contacts];
    
    NSURL *URL = [NSURL URLWithString: [[LinphoneManager instance] lpConfigStringForKey:@"service_url" forSection:@"wizard"]];
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithURL: URL];

    [request setMethod: @"create_account_with_contacts" withParameters:[NSArray arrayWithObjects:email, password, useragent, phone, name, contacts, nil]];
    
    XMLRPCConnectionManager *manager = [XMLRPCConnectionManager sharedManager];
    [manager spawnConnectionWithXMLRPCRequest: request delegate: self];
    
    [request release];
    [waitView setHidden:false];
}

- (void)checkAccountValidation:(NSString*)username {
    [LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC check_account_validated %@", username];
    
    NSURL *URL = [NSURL URLWithString: [[LinphoneManager instance] lpConfigStringForKey:@"service_url" forSection:@"wizard"]];
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithURL: URL];
    [request setMethod: @"check_account_validated" withParameters:[NSArray arrayWithObjects:username, nil]];
    
    XMLRPCConnectionManager *manager = [XMLRPCConnectionManager sharedManager];
    [manager spawnConnectionWithXMLRPCRequest: request delegate: self];
    
    [request release];
    [waitView setHidden:false];
}

- (void)checkPhoneValidation:(NSString*)username phone:(NSString*)phone code:(NSString*)code {
    [LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC validate_phone %@ %@ %@", username, phone, code];
    
    NSURL *URL = [NSURL URLWithString: [[LinphoneManager instance] lpConfigStringForKey:@"service_url" forSection:@"wizard"]];
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithURL: URL];
    [request setMethod: @"validate_phone" withParameters:[NSArray arrayWithObjects:username, phone, code, nil]];
    
    XMLRPCConnectionManager *manager = [XMLRPCConnectionManager sharedManager];
    [manager spawnConnectionWithXMLRPCRequest: request delegate: self];
    
    [request release];
    [waitView setHidden:false];
}

- (void)registrationUpdate:(LinphoneRegistrationState)state {
    switch (state) {
        case LinphoneRegistrationOk: {
            [waitView setHidden:true];
            [[LinphoneManager instance] syncRemote];
            [[PhoneMainView instance] changeCurrentView:[DialerViewController compositeViewDescription]];
            break;
        }
        case LinphoneRegistrationNone:
        case LinphoneRegistrationCleared:  {
            [waitView setHidden:true];
            break;
        }
        case LinphoneRegistrationFailed: {
            [waitView setHidden:true];
            break;
        }
        case LinphoneRegistrationProgress: {
            [waitView setHidden:false];
            break;
        }
        default:
            break;
    }
}


#pragma mark - UITextFieldDelegate Functions

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    activeTextField = textField;
}


#pragma mark - Action Functions

- (IBAction)onStartClick:(id)sender {
    [self changeView:choiceView back:FALSE animation:TRUE];
}

- (IBAction)onBackClick:(id)sender {
    if ([historyViews count] > 0) {
        UIView * view = [historyViews lastObject];
        [historyViews removeLastObject];
        [self changeView:view back:TRUE animation:TRUE];
    }
}

- (IBAction)onCancelClick:(id)sender {
    [[PhoneMainView instance] changeCurrentView:[DialerViewController compositeViewDescription]];
}

- (IBAction)onCreateAccountClick:(id)sender {
    [self changeView:createAccountView back:FALSE animation:TRUE];
}

- (IBAction)onConnectAccountClick:(id)sender {
    [self changeView:connectAccountView back:FALSE animation:TRUE];
}

- (IBAction)onExternalAccountClick:(id)sender {
    [self changeView:externalAccountView back:FALSE animation:TRUE];
}

- (IBAction)onCheckValidationClick:(id)sender {
    NSDictionary *res = [ValidationModel readData];
    NSString *email = [res objectForKey:@"email"];
    [self checkAccountValidation:email];
}

- (IBAction)onSignInExternalClick:(id)sender {
    NSString *username = [WizardViewController findTextField:ViewElement_Email  view:contentView].text;
    NSString *password = [WizardViewController findTextField:ViewElement_Password  view:contentView].text;
    NSString *domain = [WizardViewController findTextField:ViewElement_Domain  view:contentView].text;
    
    
    NSMutableString *errors = [NSMutableString string];
    if ([username length] == 0) {
        
        [errors appendString:[NSString stringWithFormat:NSLocalizedString(@"Please enter a username.\n", nil)]];
    }
    
    if ([domain length] == 0) {
        [errors appendString:[NSString stringWithFormat:NSLocalizedString(@"Please enter a domain.\n", nil)]];
    }
    
    if([errors length]) {
        UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check error(s)",nil)
                                                            message:[errors substringWithRange:NSMakeRange(0, [errors length] - 1)]
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                  otherButtonTitles:nil,nil];
        [errorView show];
        [errorView release];
    } else {
        [self.waitView setHidden:false];
        [self addProxyConfig:username password:password domain:domain server:nil];
        [self setCodecsConfig];
    }
}

- (IBAction)onSignInClick:(id)sender {
    NSString *username = [WizardViewController findTextField:ViewElement_Email  view:contentView].text;
    NSString *password = [WizardViewController findTextField:ViewElement_Password  view:contentView].text;
    
    NSMutableString *errors = [NSMutableString string];

    int username_length = [[LinphoneManager instance] lpConfigIntForKey:@"username_length" forSection:@"wizard"];
    int password_length = [[LinphoneManager instance] lpConfigIntForKey:@"password_length" forSection:@"wizard"];

    if ([username length] < username_length) {
        [errors appendString:[NSString stringWithFormat:NSLocalizedString(@"The login is too short (minimum %d characters).\n", nil), username_length]];
    }
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @".+@.+\\.[A-Za-z]{2}[A-Za-z]*"];
    if(![emailTest evaluateWithObject:username]) {
        [errors appendString:NSLocalizedString(@"The login is invalid.\n", nil)];
    }
    
    if ([password length] < password_length) {
        [errors appendString:[NSString stringWithFormat:NSLocalizedString(@"The password is too short (minimum %d characters).\n", nil), password_length]];
    }

    if([errors length]) {
        UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check error(s)",nil)
                                                            message:[errors substringWithRange:NSMakeRange(0, [errors length] - 1)]
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                  otherButtonTitles:nil,nil];
        [errorView show];
        [errorView release];
    } else {
        [self.waitView setHidden:false];
        [self addProxyConfig:username password:password
                      domain:[[LinphoneManager instance] lpConfigStringForKey:@"domain" forSection:@"wizard"]
                      server:[[LinphoneManager instance] lpConfigStringForKey:@"proxy" forSection:@"wizard"]];
        [self setCodecsConfig];
    }
}

- (IBAction)onRegisterClick:(id)sender {
    NSString *email = [WizardViewController findTextField:ViewElement_Email  view:contentView].text;
    NSString *phone = [WizardViewController findTextField:ViewElement_Phone  view:contentView].text;
    NSString *password = [WizardViewController findTextField:ViewElement_Password  view:contentView].text;
    NSString *password2 = [WizardViewController findTextField:ViewElement_Password2  view:contentView].text;
    NSMutableString *errors = [NSMutableString string];
    
    int password_length = [[LinphoneManager instance] lpConfigIntForKey:@"password_length" forSection:@"wizard"];
    
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @".+@.+\\.[A-Za-z]{2}[A-Za-z]*"];
    if(![emailTest evaluateWithObject:email]) {
        [errors appendString:NSLocalizedString(@"The email is invalid.\n", nil)];
    }

    if ([password length] < password_length) {
        [errors appendString:[NSString stringWithFormat:NSLocalizedString(@"The password is too short (minimum %d characters).\n", nil), password_length]];
    }
    
    if (![password2 isEqualToString:password]) {
        [errors appendString:NSLocalizedString(@"The passwords are different.\n", nil)];
    }
    
    if([errors length]) {
        UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check error(s)",nil)
                                                        message:[errors substringWithRange:NSMakeRange(0, [errors length] - 1)]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                              otherButtonTitles:nil,nil];
        [errorView show];
        [errorView release];
    } else {
        [self checkUserExist:email phone:phone];
    }
}

- (IBAction)onViewTap:(id)sender {
    [LinphoneUtils findAndResignFirstResponder:currentView];
}

- (IBAction)onCheckPhoneClick:(id)sender {
    NSString *code = [WizardViewController findTextField:ViewElement_PhoneVerify view:contentView].text;
    NSLog(@"Check Phone Validation Code: %@", code);
    
    // Validate code
    NSPredicate *codeTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^\\d{4}$"];
    if(![codeTest evaluateWithObject:code])
    {
        UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check error(s)",nil)
                                                            message:@"Invalid verification code"
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                  otherButtonTitles:nil,nil];
        [errorView show];
        [errorView release];
    }
    else
    {
        NSMutableDictionary* res = [ValidationModel readData];
        [self checkPhoneValidation:[res objectForKey:@"email"] phone:[res objectForKey:@"phone"] code:code];
    }
}

- (IBAction)onSkipPhoneClick:(id)sender {
    NSMutableDictionary* res = [ValidationModel readData];
    [res setObject:@"skip" forKey:@"valid_phone"];
    [ValidationModel storeData:res];
    [self changeView:validateAccountView back:FALSE animation:FALSE];
}


#pragma mark - Event Functions

- (void)registrationUpdateEvent:(NSNotification*)notif {
    int state = [[notif.userInfo objectForKey: @"state"] intValue];
    [self registrationUpdate:state];
}


#pragma mark - Keyboard Event Functions

- (void)keyboardWillHide:(NSNotification *)notif {
    //CGRect beginFrame = [[[notif userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    //CGRect endFrame = [[[notif userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIViewAnimationCurve curve = [[[notif userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
    NSTimeInterval duration = [[[notif userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView beginAnimations:@"resize" context:nil];
    [UIView setAnimationDuration:duration];
    [UIView setAnimationCurve:curve];
    [UIView setAnimationBeginsFromCurrentState:TRUE];
    
    // Move view
    UIEdgeInsets inset = {0, 0, 0, 0};
    [contentView setContentInset:inset];
    [contentView setScrollIndicatorInsets:inset];
    [contentView setShowsVerticalScrollIndicator:FALSE];
    
    [UIView commitAnimations];
}

- (void)keyboardWillShow:(NSNotification *)notif {
    //CGRect beginFrame = [[[notif userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGRect endFrame = [[[notif userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIViewAnimationCurve curve = [[[notif userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
    NSTimeInterval duration = [[[notif userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView beginAnimations:@"resize" context:nil];
    [UIView setAnimationDuration:duration];
    [UIView setAnimationCurve:curve];
    [UIView setAnimationBeginsFromCurrentState:TRUE];
    
    if(UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        int width = endFrame.size.height;
        endFrame.size.height = endFrame.size.width;
        endFrame.size.width = width;
    }
    
    // Change inset
    {
        UIEdgeInsets inset = {0,0,0,0};
        CGRect frame = [contentView frame];
        CGRect rect = [PhoneMainView instance].view.bounds;
        CGPoint pos = {frame.size.width, frame.size.height};
        CGPoint gPos = [contentView convertPoint:pos toView:[UIApplication sharedApplication].keyWindow.rootViewController.view]; // Bypass IOS bug on landscape mode
        inset.bottom = -(rect.size.height - gPos.y - endFrame.size.height);
        if(inset.bottom < 0) inset.bottom = 0;
        
        [contentView setContentInset:inset];
        [contentView setScrollIndicatorInsets:inset];
        CGRect fieldFrame = activeTextField.frame;
        fieldFrame.origin.y += fieldFrame.size.height;
        [contentView scrollRectToVisible:fieldFrame animated:TRUE];
        [contentView setShowsVerticalScrollIndicator:TRUE];
    }
    [UIView commitAnimations];
}


#pragma mark - XMLRPCConnectionDelegate Functions

- (void)request:(XMLRPCRequest *)request didReceiveResponse:(XMLRPCResponse *)response {
    [LinphoneLogger log:LinphoneLoggerLog format:@"XMLRPC %@: %@", [request method], [response body]];
    [waitView setHidden:true];
    if ([response isFault]) {
        NSString *errorString = [NSString stringWithFormat:NSLocalizedString(@"Communication issue (%@)", nil), [response faultString]];
        UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Communication issue",nil)
                                                            message:errorString
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                  otherButtonTitles:nil,nil];
        [errorView show];
        [errorView release];
    } else if([response object] != nil) { //Don't handle if not object: HTTP/Communication Error
        if([[request method] isEqualToString:@"check_account_with_phone"]) {
            if([response object] == [NSNumber numberWithInt:1]) {
                UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check issue",nil)
                                                                message:NSLocalizedString(@"Email already exists", nil)
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                      otherButtonTitles:nil,nil];
                [errorView show];
                [errorView release];
            }
            else if([response object] == [NSNumber numberWithInt:2]) {
                UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check issue",nil)
                                                                    message:NSLocalizedString(@"Username not valid", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                          otherButtonTitles:nil,nil];
                [errorView show];
                [errorView release];
            }
            else if([response object] == [NSNumber numberWithInt:3]) {
                UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check issue",nil)
                                                                    message:NSLocalizedString(@"Username already registered", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                          otherButtonTitles:nil,nil];
                [errorView show];
                [errorView release];
            }
            else if([response object] == [NSNumber numberWithInt:4]) {
                UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check issue",nil)
                                                                    message:NSLocalizedString(@"Phone number not valid", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                          otherButtonTitles:nil,nil];
                [errorView show];
                [errorView release];
            }
            else if([response object] == [NSNumber numberWithInt:5]) {
                UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check issue",nil)
                                                                    message:NSLocalizedString(@"Phone number already registered", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                          otherButtonTitles:nil,nil];
                [errorView show];
                [errorView release];
            }
            else {
                NSString *name = [WizardViewController findTextField:ViewElement_Name view:contentView].text;
                NSString *email = [WizardViewController findTextField:ViewElement_Email view:contentView].text;
                NSString *phone = [WizardViewController findTextField:ViewElement_Phone view:contentView].text;
                NSString *password = [WizardViewController findTextField:ViewElement_Password view:contentView].text;
                NSString* identity = [self identityFromUsername:email];
                [self createAccount:identity password:password email:email phone:phone name:name];
            }
        } else if([[request method] isEqualToString:@"create_account_with_contacts"]) {
            if([response object] == [NSNumber numberWithInt:0]) {
                NSString *name = [WizardViewController findTextField:ViewElement_Name view:contentView].text;
                NSString *email = [WizardViewController findTextField:ViewElement_Email view:contentView].text;
                NSString *phone = [WizardViewController findTextField:ViewElement_Phone view:contentView].text;
                NSString *password = [WizardViewController findTextField:ViewElement_Password view:contentView].text;
                NSString *validPhone;
                if ([phone length])
                {
                    validPhone = @"no";
                }
                else
                {
                    validPhone = @"skip";
                }
                [ValidationModel storeData:[NSDictionary dictionaryWithObjectsAndKeys:
                                            email, @"email",
                                            password, @"password",
                                            phone, @"phone",
                                            name, @"name",
                                            validPhone, @"valid_phone",
                                            nil]];
                if ([phone length])
                {
                    [self changeView:validatePhoneView back:FALSE animation:TRUE];
                }
                else
                {
                    [self changeView:validateAccountView back:FALSE animation:TRUE];
                }
            } else {
                UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Account creation issue",nil)
                                                                    message:NSLocalizedString(@"Can't create the account. Please try again.", nil)
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                          otherButtonTitles:nil,nil];
                [errorView show];
                [errorView release];
            }
        }
        else if([[request method] isEqualToString:@"validate_phone"]) {
            if([response object] == [NSNumber numberWithInt:1]) {
                UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Check issue",nil)
                                                                    message:@"Wrong validation code"
                                                                   delegate:nil
                                                          cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                          otherButtonTitles:nil,nil];
                [errorView show];
                [errorView release];
            }
            else {
                NSMutableDictionary* res = [ValidationModel readData];
                [res setObject:@"yes" forKey:@"valid_phone"];
                [ValidationModel storeData:res];
                [self changeView:validateAccountView back:FALSE animation:TRUE];
            }
        } else if([[request method] isEqualToString:@"check_account_validated"]) {
             if([response object] == [NSNumber numberWithInt:1]) {
                 NSDictionary *res = [ValidationModel readData];
                 NSString *email = [res objectForKey:@"email"];
                 NSString *password = [res objectForKey:@"password"];
                 [ValidationModel removeData]; // Email validated
                 [self addProxyConfig:email password:password
                              domain:[[LinphoneManager instance] lpConfigStringForKey:@"domain" forSection:@"wizard"]
                              server:[[LinphoneManager instance] lpConfigStringForKey:@"proxy" forSection:@"wizard"]];
                 [self setCodecsConfig];
             } else {
                 UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Account validation issue",nil)
                                                                     message:NSLocalizedString(@"Your account is not validate yet.", nil)
                                                                    delegate:nil
                                                           cancelButtonTitle:NSLocalizedString(@"Continue",nil)
                                                           otherButtonTitles:nil,nil];
                 [errorView show];
                 [errorView release];
             }
        }
    }
}

- (void)request:(XMLRPCRequest *)request didFailWithError:(NSError *)error {
    NSString *errorString = [NSString stringWithFormat:NSLocalizedString(@"Communication issue (%@)", nil), [error localizedDescription]];
    UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Communication issue", nil)
                                                    message:errorString
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"Continue", nil)
                                          otherButtonTitles:nil,nil];
    [errorView show];
    [errorView release];
    [waitView setHidden:true];
}

- (BOOL)request:(XMLRPCRequest *)request canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return FALSE;
}

- (void)request:(XMLRPCRequest *)request didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
}

- (void)request:(XMLRPCRequest *)request didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
}


#pragma mark - TPMultiLayoutViewController Functions

- (NSDictionary*)attributesForView:(UIView*)view {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSValue valueWithCGRect:view.frame] forKey:@"frame"];
    [attributes setObject:[NSValue valueWithCGRect:view.bounds] forKey:@"bounds"];
    if([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        [LinphoneUtils buttonMultiViewAddAttributes:attributes button:button];
    }
    [attributes setObject:[NSNumber numberWithInteger:view.autoresizingMask] forKey:@"autoresizingMask"];
    return attributes;
}

- (void)applyAttributes:(NSDictionary*)attributes toView:(UIView*)view {
    view.frame = [[attributes objectForKey:@"frame"] CGRectValue];
    view.bounds = [[attributes objectForKey:@"bounds"] CGRectValue];
    if([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        [LinphoneUtils buttonMultiViewApplyAttributes:attributes button:button];
    }
    view.autoresizingMask = [[attributes objectForKey:@"autoresizingMask"] integerValue];
}


#pragma mark - UIGestureRecognizerDelegate Functions

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIButton class]]) { //Avoid tap gesture on Button
        if([LinphoneUtils findAndResignFirstResponder:currentView]) {
            [(UIButton*)touch.view sendActionsForControlEvents:UIControlEventTouchUpInside];
            return NO;
        }
    }
    return YES;
}

@end

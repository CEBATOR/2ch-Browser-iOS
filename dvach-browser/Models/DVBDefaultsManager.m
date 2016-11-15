//
//  DVBDefaultsManager.m
//  dvach-browser
//
//  Created by Andrey Konstantinov on 30/09/16.
//  Copyright © 2016 8of. All rights reserved.
//

#import "DVBDefaultsManager.h"

@interface DVBDefaultsManager ()

@property (nonatomic, strong, nonnull) DVBNetworking *networking;

@end

@implementation DVBDefaultsManager

- (void)dealloc
{
    [self observeDefaults:NO];
}

- (void)initApp
{
    [Fabric with:@[[Crashlytics class]]];

    _networking = [[DVBNetworking alloc] init];
    NSString *userAgent = [_networking userAgent];
    // Prevent Clauda shitting on my network queries
    [[SDWebImageManager sharedManager].imageDownloader setValue:userAgent
                                             forHTTPHeaderField:NETWORK_HEADER_USERAGENT_KEY];

    // User defaults
    NSDictionary* defaults = @{
                               USER_AGREEMENT_ACCEPTED : @NO,
                               SETTING_ENABLE_DARK_THEME : @NO,
                               SETTING_ENABLE_LITTLE_BODY_FONT : @NO,
                               SETTING_ENABLE_INTERNAL_WEBM_PLAYER : @YES,
                               SETTING_ENABLE_TRAFFIC_SAVINGS : @NO,
                               SETTING_CLEAR_THREADS : @NO,
                               SETTING_BASE_DOMAIN : DVACH_DOMAIN,
                               PASSCODE : @"",
                               USERCODE : @"",
                               DEFAULTS_REVIEW_STATUS : @NO,
                               DEFAULTS_USERAGENT_KEY : userAgent
                               };

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Turn off Shake to Undo because of tags on post screen
    [UIApplication sharedApplication].applicationSupportsShakeToEdit = NO;



    [self managePasscode];
    [self manageAFNetworking];
    [self manageDb];
    [self appearanceTudeUp];
    [self observeDefaults:YES];
}

- (void)observeDefaults:(BOOL)enable
{
    if (enable) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(defaultsChanged)
                                                     name:NSUserDefaultsDidChangeNotification
                                                   object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void)managePasscode
{
    NSString *passcode = [[NSUserDefaults standardUserDefaults] objectForKey:PASSCODE];
    NSString *usercode = [[NSUserDefaults standardUserDefaults] objectForKey:USERCODE];

    BOOL isPassCodeNotEmpty = ![passcode isEqualToString:@""];
    BOOL isUserCodeEmpty = [usercode isEqualToString:@""];

    if (isPassCodeNotEmpty && isUserCodeEmpty) {
        [_networking getUserCodeWithPasscode:passcode
                               andCompletion:^(NSString *completion)
         {
             if (completion) {
                 [[NSUserDefaults standardUserDefaults] setObject:completion forKey:USERCODE];
                 [[NSUserDefaults standardUserDefaults] synchronize];

                 NSString *usercode = completion;
                 [self setUserCodeCookieWithUsercode:usercode];
             }
         }];
    } else if (!isPassCodeNotEmpty) {
        [self deleteUsercodeOldData];
    } else if (!isUserCodeEmpty) {
        [self setUserCodeCookieWithUsercode:usercode];
    }
}



/// Execute all AFNetworking methods that need to be executed one time for entire app.
- (void)manageAFNetworking
{
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
}

/// Create cookies for later posting with super csecret usercode
- (void)setUserCodeCookieWithUsercode:(NSString *)usercode
{
    NSDictionary *usercodeCookieDictionary = @{
                                               @"name" : @"usercode_nocaptcha",
                                               @"value" : usercode
                                               };
    NSHTTPCookie *usercodeCookie = [[NSHTTPCookie alloc] initWithProperties:usercodeCookieDictionary];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:usercodeCookie];
}

- (void)deleteUsercodeOldData
{
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:USERCODE];
    [[NSUserDefaults standardUserDefaults] synchronize];
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        if ([cookie.name isEqualToString:@"usercode_nocaptcha"]) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
            break;
        }
    }
}

- (void)manageDb
{
    BOOL shouldClearDB = [[NSUserDefaults standardUserDefaults] boolForKey:SETTING_CLEAR_THREADS];

    if (shouldClearDB) {
        [self clearDB];
    }
}

- (void)clearDB
{
    [self clearAllCaches];
    DVBDatabaseManager *dbManager = [DVBDatabaseManager sharedDatabase];
    [dbManager clearAll];

    // Disable observing to prevent dead lock because of notificaitons
    [self observeDefaults:NO];

    // Disable setting
    [[NSUserDefaults standardUserDefaults] setBool:NO
                                            forKey:SETTING_CLEAR_THREADS];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Re-enable Defaults observing
    [self observeDefaults:YES];
}

- (void)clearAllCaches
{
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[SDImageCache sharedImageCache] clearDisk];
}

/// Tuning appearance for entire app.
- (void)appearanceTudeUp
{
    [UIView appearance].tintColor = DVACH_COLOR;
    [UIActivityIndicatorView appearance].color = DVACH_COLOR;
    [UIButton appearanceWhenContainedIn:[DVBPostPhotoContainerView class], nil].tintColor = [UIColor whiteColor];
    
    UIView *colorView = [[UIView alloc] init];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SETTING_ENABLE_DARK_THEME]) {
        colorView.backgroundColor = CELL_SEPARATOR_COLOR_BLACK;
    } else {
        colorView.backgroundColor = CELL_SEPARATOR_COLOR;
    }
    [UITableViewCell appearance].selectedBackgroundView = colorView;
}

- (void)defaultsChanged
{
    [DVBUrls reset];
    [self clearDB];
    [self appearanceTudeUp];
}

@end
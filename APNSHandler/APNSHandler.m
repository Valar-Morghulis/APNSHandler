//
//  APNSHandler.m
//
//  Created by Kien on 5/2/15.
//  Copyright (c) 2015 Thkeen. All rights reserved.
//

#import "APNSHandler.h"

#define APNSHandler_Identifier_NullValue @"APNSHandler_Null_IdentifierValue"
#define APNSHandler_Identifier_Key @"APNSHandler_Identifier_Key"

#define IS_IOS8_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)

@interface APNSHandler ()
{
    int _newType;
}
@property(nonatomic,retain) NSMutableArray * _array;
@property(nonatomic,readwrite) int _registedNotificationType;//之前注册过的类型
@property(nonatomic,readwrite) NSString * _deviceToken;//

@end

@implementation APNSHandler
@synthesize _array;
@synthesize _isRegistedNotification;
@synthesize _delegate = _delegate;
@synthesize _registedNotificationType;
@synthesize _deviceToken = _deviceToken;
-(void)dealloc
{
    self._delegate = 0;//
    [NSKeyedArchiver archiveRootObject:self._array  toFile:[self filePath]];
    self._array = 0;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}
-(NSString *)filePath
{
    NSArray*paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    NSString*documentsDirectory =[paths objectAtIndex:0];
    
    NSString *filePath  = [documentsDirectory stringByAppendingPathComponent:@"APNSHandler.cache"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:filePath])
    {
        [fileManager createFileAtPath:filePath contents:0 attributes:0];
    }
    return filePath;
}
+ (APNSHandler *)instance
{
    static APNSHandler * _sharedInstance = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[APNSHandler alloc] init];
    });
    return _sharedInstance;
}
- (id)init
{
    if (self = [super init])
    {
        _newType = -1;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        //
        self._array = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePath]];
        if(!self._array)
        {
            self._array = [NSMutableArray array];
        }
    }
    return self;
}

-(int)_registedNotificationType
{
    return [[[NSUserDefaults standardUserDefaults]  objectForKey:@"APNSHandler_registedNotificationType"] intValue];
}
-(void)set_registedNotificationType:(int)type
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:type] forKey:@"APNSHandler_registedNotificationType"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
-(NSString *)_deviceToken
{
    return [[NSUserDefaults standardUserDefaults]  objectForKey:@"APNSHandler_deviceToken"];
}
-(void)set_deviceToken:(NSString *)deviceToken
{
    [[NSUserDefaults standardUserDefaults] setObject:deviceToken forKey:@"APNSHandler_deviceToken"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (BOOL)_isRegistedNotification
{
    if(IS_IOS8_OR_LATER)
    {
        return [[UIApplication sharedApplication] isRegisteredForRemoteNotifications] && self._deviceToken;
    }
    else
    {
        return [[UIApplication sharedApplication] enabledRemoteNotificationTypes] != UIRemoteNotificationTypeNone && self._deviceToken;
    }
}
-(int)_supportedNotificationType
{
    if(IS_IOS8_OR_LATER)
    {
        return [[UIApplication sharedApplication] currentUserNotificationSettings].types;
    }
    else
    {
        return [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    }
}

- (void)set_delegate:(id<APNSHandlerDelegate>)delegate
{
    if(_delegate)
    {
        [(id)_delegate removeObserver:self forKeyPath:@"isReadyForHandleNotification"];
    }
    _delegate = delegate;
    if(_delegate)
    {
        [(id)_delegate addObserver:self forKeyPath:@"isReadyForHandleNotification" options:NSKeyValueObservingOptionNew context:0];
    }
    [self dispatchNotifications];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if([keyPath isEqualToString:@"isReadyForHandleNotification"])
    {
        BOOL newValue = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if(newValue)
            [self dispatchNotifications];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
-(void)dispatchNotifications
{
    if(self._delegate && [self._array count] > 0)
    {
        NSDictionary * info = [self._array objectAtIndex:0];
        if([self._delegate isReadyForHandleNotification])
        {
             [info retain];
            [self._array removeObjectAtIndex:0];
            NSString * identifier = [info objectForKey:APNSHandler_Identifier_Key];
            if(identifier)
            {
                if([identifier isEqualToString:APNSHandler_Identifier_NullValue])
                    identifier = nil;
                NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:info];
                [dic removeObjectForKey:APNSHandler_Identifier_Key];
                [self._delegate APNSHandler:self handleActionWithIdentifier:identifier forRemoteNotification:dic];
            }
            else
            {
                [self._delegate APNSHandler:self handleRemoteNotification:info];
            }
            [info release];
        }
    }//fi
}

- (void)registerForRemoteNotificationsIfNecessary:(int)newType
{
    _newType = newType;
    BOOL canRegist = (self._registedNotificationType != newType && newType >= 0);
    
    if(canRegist)
    {
        if(IS_IOS8_OR_LATER)
        {
            if(self._delegate)
            {
                UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:newType categories:[self._delegate UserNotificationCategories]];
                [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
            }
        }
        else
        {
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:newType];
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        }
    }
}

//
- (void)handleApplication:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSDictionary * dic = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if(dic)
    {
        [dic retain];
        [self._array removeObject:dic];
        [self._array insertObject:dic atIndex:0];//移到首位
        [dic release];
        
        [self dispatchNotifications];
    }
}

- (void)handleApplication:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    [application registerForRemoteNotifications];
}

- (void)handleApplication:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    if(self._delegate)
    {
        NSString *token = [deviceToken description];
        token = [token stringByReplacingOccurrencesOfString:@"<" withString:@""];
        token = [token stringByReplacingOccurrencesOfString:@">" withString:@""];
        token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
        self._deviceToken = token;
        self._registedNotificationType = _newType;//只有在有delegeate的情况下才改写。防止下次注册失败。
        [self._delegate APNSHandler:self didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }
}
- (void)handleApplication:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    if(self._delegate)
    {
        [self._delegate APNSHandler:self didFailToRegisterForRemoteNotificationsWithError:error];
    }
}
//
- (void)handleApplication:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    [self._array addObject:userInfo];
    [self dispatchNotifications];
}
- (void)handleApplication:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))handler
{
    [self._array addObject:userInfo];
    [self dispatchNotifications];
    handler(UIBackgroundFetchResultNewData);
}
- (void)handleApplication:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler
{
    NSMutableDictionary  * dic = [NSMutableDictionary dictionaryWithDictionary:userInfo];
    NSString * identifierValue = identifier ? identifier : APNSHandler_Identifier_NullValue;
    [dic setObject:identifierValue forKey:APNSHandler_Identifier_Key];
    
    [self._array removeObject:userInfo];
    [self._array insertObject:dic atIndex:0];//移到首位
    [self dispatchNotifications];
     completionHandler();
}
- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if(!self._isRegistedNotification)
        [self registerForRemoteNotificationsIfNecessary:_newType];
    else
    {
        [self dispatchNotifications];
    }
}

@end

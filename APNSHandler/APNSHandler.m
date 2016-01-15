//
//  APNSHandler.m
//
//  Created by Kien on 5/2/15.
//  Copyright (c) 2015 Thkeen. All rights reserved.
//

#import "APNSHandler.h"

#define IS_IOS8_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)

@interface APNSHandler ()
{
    int _newType;
}
@property(nonatomic,retain) NSMutableArray * _array;
@property(nonatomic,readwrite) int _registedNotificationType;//之前注册过的类型
@end

@implementation APNSHandler
@synthesize _array;
@synthesize _isRegistedNotification;
@synthesize _inactiveDelegate = _inactiveDelegate;
@synthesize _activeDelegate = _activeDelegate;
@synthesize _registedNotificationType;
-(void)dealloc
{
    self._inactiveDelegate = 0;//
    self._activeDelegate = 0;
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
        
        NSMutableArray * emptyArray = [NSMutableArray array];
        [NSKeyedArchiver archiveRootObject:emptyArray  toFile:[self filePath]];//清空文件
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
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:_registedNotificationType] forKey:@"APNSHandler_registedNotificationType"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)_isRegistedNotification
{
    if(IS_IOS8_OR_LATER)
    {
        return [[UIApplication sharedApplication] isRegisteredForRemoteNotifications];
    }
    else
    {
        return [[UIApplication sharedApplication] enabledRemoteNotificationTypes] != UIRemoteNotificationTypeNone;
    }
}
-(int)_currentSupportedNotificationType
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

- (void)set_inactiveDelegate:(id<APNSHandler_InactiveDelegate>)inactiveDelegate
{
    if(_inactiveDelegate)
    {
        [(id)_inactiveDelegate removeObserver:self forKeyPath:@"isReadyForHandleNotification"];
    }
    _inactiveDelegate = inactiveDelegate;
    if(_inactiveDelegate)
    {
        [(id)_inactiveDelegate addObserver:self forKeyPath:@"isReadyForHandleNotification" options:NSKeyValueObservingOptionNew context:0];
    }
    [self distributeNotifications];
}

- (void)set_activeDelegate:(id<APNSHandler_ActiveDelegate>)activeDelegate
{
    if(_activeDelegate)
    {
        [(id)_activeDelegate removeObserver:self forKeyPath:@"isReadyForHandleNotification"];
    }
    _activeDelegate = activeDelegate;
    if(_activeDelegate)
    {
        [(id)_activeDelegate addObserver:self forKeyPath:@"isReadyForHandleNotification" options:NSKeyValueObservingOptionNew context:0];
    }
    [self distributeNotifications];
}
//
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if([keyPath isEqualToString:@"isReadyForHandleNotification"])
    {
        BOOL newValue = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if(newValue)
            [self distributeNotifications];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
-(void)distributeNotifications
{
    if([self._array count] > 0)
    {
        NSDictionary * info = [self._array objectAtIndex:0];
        BOOL handled = FALSE;
        if(self._activeDelegate)
        {
            if([self._activeDelegate isReadyForHandleNotification])
            {
                [self._activeDelegate APNSHandler:self handleRemoteNotification:info];
                handled = TRUE;
            }
        }
        else if (self._inactiveDelegate)
        {
            if([self._inactiveDelegate isReadyForHandleNotification])
            {
                [self._inactiveDelegate APNSHandler:self handleRemoteNotification:info];
                handled = TRUE;
            }
        }//else
        if(handled)
        {
            [self._array removeObjectAtIndex:0];
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
            if(self._activeDelegate)
            {
                UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:newType categories:[self._activeDelegate UserNotificationCategories]];
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
        [self._array addObject:dic];
        [self distributeNotifications];
    }
}

- (void)handleApplication:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    [application registerForRemoteNotifications];
}

- (void)handleApplication:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    self._registedNotificationType = _newType;
    if(self._activeDelegate)
    {
        [self._activeDelegate APNSHandler:self didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }
}
- (void)handleApplication:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    if(self._activeDelegate)
    {
        [self._activeDelegate APNSHandler:self didFailToRegisterForRemoteNotificationsWithError:error];
    }
}
//
- (void)handleApplication:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    [self._array addObject:userInfo];
    [self distributeNotifications];
}
- (void)handleApplication:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))handler
{
    [self._array addObject:userInfo];
    [self distributeNotifications];
    handler(UIBackgroundFetchResultNewData);
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self registerForRemoteNotificationsIfNecessary:_newType];
}

@end

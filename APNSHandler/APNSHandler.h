//
//  APNSHandler.h
//
//  Created by Kien on 5/2/15.
//  Copyright (c) 2015 Thkeen. All rights reserved.
//

#import <UIKit/UIKit.h>

@class APNSHandler;

@protocol APNSHandler_InactiveDelegate <NSObject>//
//处理收到的通知
- (void)APNSHandler:(APNSHandler*)manager handleRemoteNotification:(NSDictionary *)userInfo;//
@property(nonatomic) BOOL isReadyForHandleNotification;//是否可以处理收到的通知
@end

@protocol APNSHandler_ActiveDelegate <APNSHandler_InactiveDelegate>

-(NSSet *)UserNotificationCategories;//获取各种category
//注册成功
- (void)APNSHandler:(APNSHandler*)manager didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken;
//注册失败
- (void)APNSHandler:(APNSHandler*)manager didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
@end


@interface APNSHandler : NSObject

+ (APNSHandler *)instance;

@property (nonatomic,readonly) BOOL _isRegistedNotification;//系统是否注册过通知
@property(nonatomic,readonly) int _currentSupportedNotificationType;//当前系统设置支持的类型
@property (nonatomic, assign) id<APNSHandler_InactiveDelegate> _inactiveDelegate;
@property (nonatomic, assign) id<APNSHandler_ActiveDelegate> _activeDelegate;
@property(nonatomic,readonly) int _registedNotificationType;//之前注册过的类型

- (void)registerForRemoteNotificationsIfNecessary:(int)newType;//注册 -->类型不同时会调用注册程序

//
- (void)handleApplication:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;

- (void)handleApplication:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings;

- (void)handleApplication:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleApplication:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
//
- (void)handleApplication:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;
- (void)handleApplication:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))handler;
@end

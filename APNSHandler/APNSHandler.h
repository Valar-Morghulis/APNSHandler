//
//  APNSHandler.h
//
//  Created by Kien on 5/2/15.
//  Copyright (c) 2015 Thkeen. All rights reserved.
//

#import <UIKit/UIKit.h>

@class APNSHandler;
@protocol APNSHandlerDelegate <NSObject>

-(NSSet *)UserNotificationCategories;//获取各种category
//注册成功
- (void)APNSHandler:(APNSHandler*)handler didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken;
//注册失败
- (void)APNSHandler:(APNSHandler*)handler didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;

//处理收到的通知
- (void)APNSHandler:(APNSHandler*)handler handleRemoteNotification:(NSDictionary *)userInfo;//
- (void)APNSHandler:(APNSHandler*)handler handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;
@property(nonatomic) BOOL isReadyForHandleNotification;//是否可以处理收到的通知

@end


@interface APNSHandler : NSObject

+ (APNSHandler *)instance;
@property (nonatomic, assign) id<APNSHandlerDelegate> _delegate;

@property (nonatomic,readonly) BOOL _isRegistedNotification;//系统是否注册过通知
@property(nonatomic,readonly) int _supportedNotificationType;//当前系统设置支持的类型
@property(nonatomic,readonly) NSData * _deviceToken;//deviceTokenData
@property(nonatomic,readonly) int _registedNotificationType;//之前注册过的类型

-(NSString *)deviceTokenString;

- (void)registerForRemoteNotificationsIfNecessary:(int)newType;//注册 -->类型不同时会调用注册程序

//
- (void)handleApplication:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;

- (void)handleApplication:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings;

- (void)handleApplication:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleApplication:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
//
- (void)handleApplication:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;
- (void)handleApplication:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))handler;
- (void)handleApplication:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler;
@end

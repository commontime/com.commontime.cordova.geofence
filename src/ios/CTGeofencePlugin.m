//
//  CTGeofencePlugin.m
//  GeofenceTest
//
//  Created by Gary Meehan on 12/04/2016.
//
//

#import "CTGeofencePlugin.h"

#import "CTGeofenceManager.h"

@interface CTGeofencePlugin()

@property (nonatomic, readwrite, strong) CTGeofenceManager* manager;

@end

@implementation CTGeofencePlugin

- (void) pluginInitialize
{
  [super pluginInitialize];
  
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(didReceiveLocalNotification:)
                                               name: @"CDVLocalNotification"
                                             object: nil];
  
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(didReceiveTransition:)
                                               name: @"handleTransition"
                                             object: nil];
}

- (void) promptForNotificationPermission
{
  UIApplication* application = [UIApplication sharedApplication];
  
  [application registerUserNotificationSettings: [UIUserNotificationSettings settingsForTypes: UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound
                                                                                   categories: nil]];
}

- (void) didReceiveLocalNotification: (NSNotification*) notification
{
  NSLog(@"did receive local notification");
  
  if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
  {
    if ([notification.object isKindOfClass: [UILocalNotification class]])
    {
      id notificationData = notification.userInfo[@"geofence.notification.data"];
      
      if ([notificationData isKindOfClass: [NSString class]])
      {
        NSString* javascript = [NSString stringWithFormat: @"setTimeout(function() { geofence.onNotificationClicked(%@); }, 0)", notificationData];
        
        NSLog(@"Executing: %@", javascript);

        [(UIWebView*) self.webView stringByEvaluatingJavaScriptFromString: javascript];
      }
    }
  }
}

- (void) didReceiveTransition: (NSNotification*) notification
{
  NSLog(@"did receive transition");
  
  if ([notification.object isKindOfClass: [NSString class]])
  {
    NSString* javascript = [NSString stringWithFormat: @"setTimeout(function() { window.geofence.onTransitionReceived([%@]); }, 0);", notification.object];
    
    NSLog(@"Executing: %@", javascript);
    
    [(UIWebView*) self.webView stringByEvaluatingJavaScriptFromString: javascript];
  }
}

#pragma mark - Plugin public functions

- (void) initialize: (CDVInvokedUrlCommand*) command
{
  NSLog(@"plugin initialization");

  [self promptForNotificationPermission];

  self.manager = [[CTGeofenceManager alloc] init];
  [self.manager registerPermissions];
  
  CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
  
  [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
}

- (void) deviceReady: (CDVInvokedUrlCommand*) command
{
  CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
  
  [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
}

- (void) ping: (CDVInvokedUrlCommand*) command
{
  NSLog(@"ping");
  
  CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
  
  [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
}

- (void) addOrUpdate: (CDVInvokedUrlCommand*) command
{
  @try
  {
    for (id argument in command.arguments)
    {
      if ([argument isKindOfClass: [NSDictionary class]])
      {
        [self.manager addOrUpdateNotification: argument];
      }
      else
      {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                    messageAsString: @"expected identifier"];
        
        [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
        
        return;
      }
    }
    
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) getWatched: (CDVInvokedUrlCommand*) command
{
  @try
  {
    NSArray* allNotifications = [self.manager allWatchedNotifications];
    
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                 messageAsArray: allNotifications];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) remove: (CDVInvokedUrlCommand*) command
{
  @try
  {
    for (id argument in command.arguments)
    {
      if ([argument isKindOfClass: [NSString class]])
      {
        [self.manager removeNotificationForIdentifier: argument];
      }
      else
      {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                    messageAsString: @"expected identifier"];
        
        [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
        
        return;
      }
    }
    
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) removeAll: (CDVInvokedUrlCommand*) command
{
  @try
  {
    [self.manager removeAllNotifications];
    
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

@end

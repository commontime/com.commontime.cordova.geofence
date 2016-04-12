//
//  CTGeofencePlugin.h
//  GeofenceTest
//
//  Created by Gary Meehan on 12/04/2016.
//
//

#import <Foundation/Foundation.h>

#import <Cordova/CDV.h>

@interface CTGeofencePlugin : CDVPlugin

- (void) initialize: (CDVInvokedUrlCommand*) command;

- (void) deviceReady: (CDVInvokedUrlCommand*) command;

- (void) ping: (CDVInvokedUrlCommand*) command;

- (void) addOrUpdate: (CDVInvokedUrlCommand*) command;

- (void) getWatched: (CDVInvokedUrlCommand*) command;

- (void) remove: (CDVInvokedUrlCommand*) command;

- (void) removeAll: (CDVInvokedUrlCommand*) command;

@end

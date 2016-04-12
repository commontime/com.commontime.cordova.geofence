//
//  CTGeofenceManager.h
//  GeofenceTest
//
//  Created by Gary Meehan on 12/04/2016.
//
//

#import <Foundation/Foundation.h>

#import <CoreLocation/CoreLocation.h>

@interface CTGeofenceManager : NSObject<CLLocationManagerDelegate>

- (void) registerPermissions;

- (void) addOrUpdateNotification: (id) JSON;

- (NSArray*) allWatchedNotifications;

- (void) removeNotificationForIdentifier: (NSString*) identifier;

- (void) removeAllNotifications;

@end

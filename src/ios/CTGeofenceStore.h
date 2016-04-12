//
//  CTGeofenceStore.h
//  GeofenceTest
//
//  Created by Gary Meehan on 12/04/2016.
//
//

#import <Foundation/Foundation.h>

@interface CTGeofenceStore : NSObject

- (void) addOrUpdateNotification: (id) JSON;

- (void) addNotification: (id) JSON;

- (void) updateNotification: (id) JSON;

- (id) notificationForIdentifer: (NSString*) identifier;

- (NSArray*) allNotifications;

- (void) removeNotificationForIdentifier: (NSString*) identifer;

- (void) removeAllNotifications;

@end

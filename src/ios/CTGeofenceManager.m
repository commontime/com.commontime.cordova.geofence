//
//  CTGeofenceManager.m
//  GeofenceTest
//
//  Created by Gary Meehan on 12/04/2016.
//
//

#import "CTGeofenceManager.h"

#import <AudioToolbox/AudioToolbox.h>

#import "CTGeofenceStore.h"

typedef NS_ENUM(NSInteger, CTGeofenceTransitionType)
{
  CTGeofenceTransitionNone = 1,
  CTGeofenceTransitionEnter = 1,
  CTGeofenceTransitionExit = 2,
  CTGeofenceTransitionBoth = CTGeofenceTransitionEnter | CTGeofenceTransitionExit
};

@interface CTGeofenceManager()

@property (nonatomic, readwrite, strong) CLLocationManager* locationManager;
@property (nonatomic, readwrite, strong) CTGeofenceStore* store;

#ifdef DEBUG
@property (nonnull, readwrite, strong) CLLocation* lastLocation;
#endif

@end

@implementation CTGeofenceManager

- (id) init
{
  if ((self = [super init]))
  {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    if ([self.locationManager respondsToSelector: @selector(allowsBackgroundLocationUpdates)])
    {
      self.locationManager.allowsBackgroundLocationUpdates = YES;
    }
    
    if ([CLLocationManager locationServicesEnabled])
    {
      NSLog(@"location services enabled");
    }
    else
    {
      NSLog(@"location services NOT enabled");
    }
    
    if (![CLLocationManager isMonitoringAvailableForClass: [CLRegion class]])
    {
      NSLog(@"Geofencing is NOT available");
    }
    
    self.store = [[CTGeofenceStore alloc] init];
    
#ifdef DEBUG
    //[self.locationManager startUpdatingLocation];
#endif    
  }
  
  return self;
}

- (void) registerPermissions
{
  [self.locationManager requestAlwaysAuthorization];
}


- (void) checkRequirements
{
  if (![CLLocationManager locationServicesEnabled])
  {
    NSLog(@"location services are not enabled");
  }
  
  if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways)
  {
    NSLog(@"permission to always use the location services has not been granted");
  }
  
  UIUserNotificationSettings* settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
  
  if (settings)
  {
    if (!(settings.types & UIUserNotificationTypeSound))
    {
      NSLog(@"permission for notification sounds has not been granted");
    }
    
    if (!(settings.types & UIUserNotificationTypeBadge))
    {
      NSLog(@"permission for notification badges has not been granted");
    }
    
    if (!(settings.types & UIUserNotificationTypeAlert))
    {
      NSLog(@"permission for notification alerts has not been granted");
    }
  }
  else
  {
    NSLog(@"permission to use notifications has not been granted");
  }
}

- (void) handleTransitionWithRegion: (CLRegion*) region type: (CTGeofenceTransitionType) type
{
  NSDictionary* JSON = [self.store notificationForIdentifer: region.identifier];
  
  if (JSON)
  {
    NSMutableDictionary* transition = [NSMutableDictionary dictionaryWithDictionary: JSON];

    transition[@"transitionType"] = [NSNumber numberWithInteger: type];
    
    if ([transition[@"notification"] isKindOfClass: [NSDictionary class]])
    {
      [self scheduleNotification: JSON];
    }
    
    NSData* data = [NSJSONSerialization dataWithJSONObject: transition options: 0 error: NULL];
    
    if (data)
    {
      NSString* string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
      
      [[NSNotificationCenter defaultCenter] postNotificationName: @"handleTransition" object: string userInfo: nil];
    }
  }
}

- (void) scheduleNotification: (id) JSON
{
  NSLog(@"scheduling notification");
  
  UILocalNotification* notification = [[UILocalNotification alloc] init];
  
  notification.timeZone = [NSTimeZone defaultTimeZone];
  notification.fireDate = [NSDate date];
  notification.soundName = UILocalNotificationDefaultSoundName;
  notification.alertBody = JSON[@"notification"][@"text"];
  
  id notificationData = JSON[@"notification"][@"data"];
  
  if (notificationData)
  {
    NSData* data = [NSJSONSerialization dataWithJSONObject: notificationData options: 0 error: NULL];
    NSString* string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];

    notification.userInfo = @{@"geofence.notification.data": string};
  }
  
  [[UIApplication sharedApplication] scheduleLocalNotification: notification];
  
  id vibrate = JSON[@"notification"][@"vibrate"];
  
  if ([vibrate isKindOfClass: [NSArray class]])
  {
    if ([vibrate count] > 0 && [vibrate[0] integerValue] > 0)
    {
      AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    }
  }
}

- (void) addOrUpdateNotification: (id) JSON
{
  [self checkRequirements];
  
  double latitude = [JSON[@"latitude"] doubleValue];
  double longitude = [JSON[@"longitude"] doubleValue];
  double radius = [JSON[@"radius"] doubleValue];
  NSString* identifier = JSON[@"id"];
  CTGeofenceTransitionType transitionType = CTGeofenceTransitionNone;
  
  if (JSON[@"transitionType"])
  {
    transitionType = [JSON[@"transitionType"] intValue];
  }
  
  CLLocationCoordinate2D center = CLLocationCoordinate2DMake(latitude, longitude);
  CLCircularRegion* region = [[CLCircularRegion alloc] initWithCenter: center radius: radius identifier: identifier];
  
  region.notifyOnEntry = (transitionType & CTGeofenceTransitionEnter) != 0;
  region.notifyOnExit = (transitionType & CTGeofenceTransitionExit) != 0;
  
  NSLog(@"will monitor region %@", region);
  
  [self.store addOrUpdateNotification: JSON];
  [self.locationManager startMonitoringForRegion: region];
}

- (NSArray*) allWatchedNotifications
{
  return [self.store allNotifications];
}

- (CLRegion*) monitoredRegionForIdentifier: (NSString*) identifier
{
  for (CLRegion* region in [self.locationManager monitoredRegions])
  {
    if ([region.identifier isEqualToString: identifier])
    {
      return region;
    }
  }
  
  return nil;
}

- (void) removeNotificationForIdentifier: (NSString*) identifier
{
  [self.store removeNotificationForIdentifier: identifier];
  
  CLRegion* region = [self monitoredRegionForIdentifier: identifier];
  
  if (region)
  {
    NSLog(@"will stop monitoring region %@", identifier);
    
    [self.locationManager stopMonitoringForRegion: region];
  }
}

- (void) removeAllNotifications
{
  [self.store removeAllNotifications];
  
  for (CLRegion* region in [self.locationManager monitoredRegions])
  {
    NSLog(@"will stop monitoring region %@", region.identifier);
    
    [self.locationManager stopMonitoringForRegion: region];
  }
}

#ifdef DEBUG

- (void) logDistanceToGeofences
{
  if (self.lastLocation)
  {
    for (CLRegion* region in [self.locationManager monitoredRegions])
    {
      if ([region isKindOfClass: [CLCircularRegion class]])
      {
        CLCircularRegion* circularRegion = (CLCircularRegion*) region;
        CLLocation* center = [[CLLocation alloc] initWithLatitude: circularRegion.center.latitude longitude: circularRegion.center.longitude];
        
        NSLog(@"%@ is %.1f metres from current location", region.identifier, [center distanceFromLocation: self.lastLocation]);
      }
    }
  }
  else
  {
    NSLog(@"No last location");
  }
}

#endif

#pragma mark - CLLocationManagerDelegate

- (void) locationManager: (CLLocationManager*) manager didUpdateLocations: (NSArray<CLLocation *>*) locations
{
#ifdef DEBUG
  if (locations.count > 0)
  {
    self.lastLocation = locations[locations.count - 1];
    
    NSLog(@"did update locations; last location is %@", self.lastLocation);
    
    [self logDistanceToGeofences];
  }
#else
  NSLog(@"did update locations");
#endif
}

- (void) locationManager: (CLLocationManager*) manager didFailWithError: (NSError*) error
{
  NSLog(@"did fail with error: %@", error);
}

- (void) locationManager: (CLLocationManager*) manager didFinishDeferredUpdatesWithError: (NSError*) error
{
  NSLog(@"did finish deferred updates with error: %@", error);
}

- (void) locationManager: (CLLocationManager*) manager didEnterRegion: (CLRegion*) region
{
  NSLog(@"did enter region %@", region.identifier);
  
  [self handleTransitionWithRegion: region type: CTGeofenceTransitionEnter];
}

- (void) locationManager: (CLLocationManager*) manager didExitRegion: (CLRegion*) region
{
  NSLog(@"did exit region %@", region.identifier);
  
  [self handleTransitionWithRegion: region type: CTGeofenceTransitionExit];
}

- (void) locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
  NSLog(@"did start monitoring region %@", region.identifier);  
}

- (void) locationManager: (CLLocationManager*) manager didDetermineState: (CLRegionState) state forRegion: (CLRegion*) region
{
  NSLog(@"did determine state for region %@", region.identifier);
}

- (void) locationManager: (CLLocationManager*) manager monitoringDidFailForRegion: (CLRegion*) region withError: (NSError*) error
{
  NSLog(@"monitoring for region %@ did fail with error: %@", region.identifier, error);
}

@end

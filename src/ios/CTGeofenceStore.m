//
//  CTGeofenceStore.m
//  GeofenceTest
//
//  Created by Gary Meehan on 12/04/2016.
//
//

#import "CTGeofenceStore.h"

#import <sqlite3.h>

@interface CTGeofenceStore()

@property (nonatomic, readwrite, assign) sqlite3* database;

@end

@implementation CTGeofenceStore

- (id) init
{
  if ((self = [super init]))
  {
    if ([self openDatabase])
    {
      if (![self doesTableExist] && ![self createTable])
      {
        self = nil;
      }
    }
    else
    {
      self = nil;
    }
    
#ifdef DEBUG
      [self logTable];
#endif
  }
  
  return self;
}

- (void) dealloc
{
  if (self.database)
  {
    sqlite3_close(self.database);
  }
}

- (void) logLastError
{
  if (self.database)
  {
    int errorCode = sqlite3_errcode(self.database);
    const char* errorMessage = sqlite3_errmsg(self.database);
    
    NSLog(@"last database error: %s (%d)", errorMessage, errorCode);
  }
  else
  {
    NSLog(@"no database handle");
  }
}

- (BOOL) openDatabase
{
  NSArray* folders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  
  if (folders.count > 0)
  {
    NSString* documentsFolder = [folders objectAtIndex: 0];
    NSString* path = [documentsFolder stringByAppendingPathComponent: @"geofence.sql"];
    
    sqlite3* handle = NULL;
    
    if (sqlite3_open([path UTF8String], &handle) == SQLITE_OK)
    {
      self.database = handle;
      
      return YES;
    }
    else
    {
      return NO;
    }
  }
  else
  {
    return NO;
  }
}

- (BOOL) doesTableExist
{
  NSString* query = @"SELECT name FROM sqlite_master WHERE type='table' AND name='GeoNotifications';";
  sqlite3_stmt* handle = NULL;
  BOOL exists = NO;
  
  if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &handle, NULL) == SQLITE_OK)
  {
    exists = sqlite3_step(handle) == SQLITE_ROW;
  }
  else
  {
    [self logLastError];
  }
  
  if (handle)
  {
    sqlite3_finalize(handle);
  }
  
  return exists;
}

- (BOOL) createTable
{
  NSString* query = @"CREATE TABLE GeoNotifications (ID TEXT PRIMARY KEY, Data TEXT);";
  sqlite3_stmt* statement = NULL;
  BOOL success = NO;
  
  if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
  {
    success = sqlite3_step(statement) == SQLITE_DONE;
  }
  else
  {
    [self logLastError];
  }

  if (statement)
  {
    sqlite3_finalize(statement);
  }
  
  return success;
}

- (void) addOrUpdateNotification: (id) JSON
{
  if ([self notificationForIdentifer: JSON[@"id"]])
  {
    [self updateNotification: JSON];
  }
  else
  {
    [self addNotification: JSON];
  }
}

- (void) addNotification: (id) JSON
{
  NSData* identifierData = [JSON[@"id"] dataUsingEncoding: NSUTF8StringEncoding];
  
  if (!identifierData)
  {
    NSLog(@"missing identifier in notification");
    
    return;
  }

  NSError* error = nil;
  NSData* data = [NSJSONSerialization dataWithJSONObject: JSON options: 0 error: &error];
  
  if (!data)
  {
    NSLog(@"cannot serialize notification: %@", [error localizedDescription]);
    
    return;
  }

  NSString* query = @"INSERT INTO GeoNotifications (Id, Data) VALUES(?, ?);";
  sqlite3_stmt* statement = NULL;
  BOOL success = NO;
  
  if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
  {
    sqlite3_bind_text(statement, 1, [identifierData bytes], (int) [identifierData length], SQLITE_TRANSIENT);
    sqlite3_bind_text(statement, 2, [data bytes], (int) [data length], SQLITE_TRANSIENT);

    success = sqlite3_step(statement) == SQLITE_DONE;
  }
  
  if (statement)
  {
    sqlite3_finalize(statement);
  }
  
  if (!success)
  {
    [self logLastError];
  }
}

- (void) updateNotification: (id) JSON
{
  NSData* identifierData = [JSON[@"id"] dataUsingEncoding: NSUTF8StringEncoding];
  
  if (!identifierData)
  {
    NSLog(@"missing identifier in notification");
    
    return;
  }
  
  NSError* error = nil;
  NSData* data = [NSJSONSerialization dataWithJSONObject: JSON options: 0 error: &error];
  
  if (!data)
  {
    NSLog(@"cannot serialize notification: %@", [error localizedDescription]);
    
    return;
  }
  
  NSString* query = @"UPDATE GeoNotifications SET Data = ? WHERE Id = ?;";
  sqlite3_stmt* statement = NULL;
  BOOL success = NO;
  
  if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
  {
    sqlite3_bind_text(statement, 1, [data bytes], (int) [data length], SQLITE_TRANSIENT);
    sqlite3_bind_text(statement, 2, [identifierData bytes], (int) [identifierData length], SQLITE_TRANSIENT);
    
    success = sqlite3_step(statement) == SQLITE_DONE;
  }
  
  if (statement)
  {
    sqlite3_finalize(statement);
  }
  
  if (!success)
  {
    [self logLastError];
  }
}

- (id) notificationForIdentifer: (NSString*) identifier
{
  if (!identifier)
  {
    NSLog(@"missing identifier");
    
    return nil;
  }
  
  NSString* query = @"SELECT Data FROM GeoNotifications WHERE Id = ?;";
  sqlite3_stmt* statement = NULL;
  id JSON = nil;
  NSError* error = nil;
  BOOL success = NO;

  if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
  {
    NSData* identifierData = [identifier dataUsingEncoding: NSUTF8StringEncoding];

    sqlite3_bind_text(statement, 1, [identifierData bytes], (int) [identifierData length], SQLITE_TRANSIENT);
  
    if (sqlite3_step(statement) == SQLITE_ROW)
    {
      const unsigned char* bytes = sqlite3_column_text(statement, 0);
      size_t length = strlen((const char*) bytes);
      NSData* data = [[NSData alloc] initWithBytesNoCopy: (void*) bytes length: length freeWhenDone: NO];
      
      JSON = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &error];
    }
    
    success = YES;
  }
  
  if (statement)
  {
    sqlite3_finalize(statement);
  }
  
  if (!success)
  {
    if (error)
    {
      NSLog(@"%@", [error localizedDescription]);
    }
    else
    {
      [self logLastError];
    }
  }
  
  return JSON;
}

- (NSArray*) allNotifications
{
  NSString* query = @"SELECT Data FROM GeoNotifications;";
  sqlite3_stmt* statement = NULL;
  NSMutableArray* notifications = [NSMutableArray array];
  BOOL success = NO;
  
  if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
  {
    while (sqlite3_step(statement) == SQLITE_ROW)
    {
      const unsigned char* bytes = sqlite3_column_text(statement, 0);
      size_t length = strlen((const char*) bytes);
      NSData* data = [[NSData alloc] initWithBytesNoCopy: (void*) bytes length: length freeWhenDone: NO];
      NSError* error = nil;
      id JSON = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &error];
      
      if (JSON)
      {
        [notifications addObject: JSON];
      }
      else
      {
        NSLog(@"%@", [error localizedDescription]);
      }
    }
    
    success = YES;
  }
  
  if (statement)
  {
    sqlite3_finalize(statement);
  }
  
  if (!success)
  {
    [self logLastError];
  }
  
  return notifications;
}

- (void) removeNotificationForIdentifier: (NSString*) identifer
{
  NSData* identifierData =  [identifer dataUsingEncoding: NSUTF8StringEncoding];
  
  if (!identifierData)
  {
    NSLog(@"missing identifier in notification");
    
    return;
  }
  
  NSString* query = @"DELETE FROM GeoNotifications WHERE Id = ?;";
  sqlite3_stmt* statement = NULL;
  BOOL success = NO;
  
  if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
  {
    sqlite3_bind_text(statement, 1, [identifierData bytes], (int) [identifierData length], SQLITE_TRANSIENT);
    
    success = sqlite3_step(statement) == SQLITE_DONE;
  }
  
  if (statement)
  {
    sqlite3_finalize(statement);
  }
  
  if (!success)
  {
    [self logLastError];
  }
}

- (void) removeAllNotifications
{
  NSString* query = @"DELETE FROM GeoNotifications;";
  sqlite3_stmt* statement = NULL;
  BOOL success = NO;
  
  if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
  {
    success = sqlite3_step(statement) == SQLITE_DONE;
  }
  
  if (statement)
  {
    sqlite3_finalize(statement);
  }
  
  if (!success)
  {
    [self logLastError];
  }
}

#ifdef DEBUG

- (void) logTable
{
  NSString* query = @"SELECT Id, Data FROM GeoNotifications;";
  sqlite3_stmt* statement = NULL;
  BOOL success = NO;
  
  if (sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
  {
    NSLog(@"Id, Data");
    
    while (sqlite3_step(statement) == SQLITE_ROW)
    {
      const unsigned char* identifier = sqlite3_column_text(statement, 0);
      const unsigned char* data = sqlite3_column_text(statement, 1);
      
      NSLog(@"%s, %s", identifier, data);
    }
    
    success = YES;
  }
  
  if (statement)
  {
    sqlite3_finalize(statement);
  }
  
  if (!success)
  {
    [self logLastError];
  }
}

#endif

@end

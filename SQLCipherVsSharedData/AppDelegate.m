//
//  AppDelegate.m
//  SQLCipherVsSharedData
//

#import "AppDelegate.h"
#import "sqlite3.h"

// TODO: To reproduce this issue, you'll need to run on a device (not the simulator).
//       To code sign for a device, you'll need to create your own app id & app group id
//       and update this project to reflect them.
//       See the README.md for details.
//
// App ID: org.signal.sqlciphervsshareddata
// App Group ID: org.signal.sqlciphervsshareddata.group
NSString *const kApplicationGroupId = @"group.org.signal.sqlciphervsshareddata";

// This demo app offers two ways to reproduce the issue:
//
// * If you DO NOT create any content, the app will crash _the second time_ you launch the
//   app and send it to the background.
// * If you DO create some content (e.g. make an empty table), the app will crash _the first
//   time_ you launch the app and send it to the background.
#define CREATE_CONTENT

#define CONVERT_TO_STRING(X) #X
#define CONVERT_EXPR_TO_STRING(X) CONVERT_TO_STRING(X)

#define DemoLog(message, ...)                                                                                          \
{                                                                                                                  \
NSString *formattedMessage = [NSString stringWithFormat:message, ##__VA_ARGS__];                               \
NSLog(@"%s %@", __PRETTY_FUNCTION__, formattedMessage);                                                   \
fflush(stderr); \
}

#define DemoAssert(X)                                                                                                   \
if (!(X)) {                                                                                                        \
DemoLog(@"Assertion failed: %s", CONVERT_EXPR_TO_STRING(X));                        \
NSAssert(0, @"Assertion failed: %s", CONVERT_EXPR_TO_STRING(X));                                               \
}

@interface AppDelegate () {
    // Use an ivar for this state.
@private
    sqlite3 *db;
}

@end

#pragma mark -

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    DemoLog(@"didFinishLaunchingWithOptions");
    
    NSString *databasePath = self.dbPath;
    DemoLog(@"databasePath: %@", databasePath);
    
    BOOL isNewDatabaseFile = ![[NSFileManager defaultManager] fileExistsAtPath:databasePath];
    DemoLog(@"isNewDatabaseFile %d", isNewDatabaseFile);
   
    // I'm not sure if all of these flags are necessary.
    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_PRIVATECACHE;
    
    {
        int status = sqlite3_open_v2([databasePath UTF8String], &db, flags, NULL);
        DemoAssert(status == SQLITE_OK);
    }
    // I've never seen this issue without encryption being enabled.
    {
        NSString *encryptionKey = @"any key will do";
        NSData *keyData = [encryptionKey dataUsingEncoding:NSUTF8StringEncoding];
        int status = sqlite3_key(db, [keyData bytes], (int)[keyData length]);
        DemoAssert(status == SQLITE_OK);
    }
    // "journal_mode = WAL" is the simplest repro that I could find.
    {
        int status = sqlite3_exec(db, "PRAGMA journal_mode = WAL;", NULL, NULL, NULL);
        DemoAssert(status == SQLITE_OK);
    }
    {
        // See comments on CREATE_CONTENT symbol above.
#ifdef CREATE_CONTENT
        DemoAssert(isNewDatabaseFile);
        if (isNewDatabaseFile) {
            // There's nothing special about the CREATE TABLE command;
            // any SQL command that modifies the database will have the same effect.
            int status = sqlite3_exec(db, "CREATE TABLE groups ( group_id integer PRIMARY KEY );", NULL, NULL, NULL);
            DemoAssert(status == SQLITE_OK);
        }
#endif
    }
    DemoLog(@"didFinishLaunchingWithOptions");
   
    return YES;
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    DemoAssert([NSThread isMainThread]);
    
    DemoLog(@"applicationDidEnterBackground");
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    DemoAssert([NSThread isMainThread]);
    
    DemoLog(@"applicationWillEnterForeground");
}

+ (NSString *)appSharedDataDirectoryPath
{
    NSURL *groupContainerDirectoryURL =
    [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:kApplicationGroupId];
    return [groupContainerDirectoryURL path];
}

+ (NSString *)databaseFilename
{
    static NSString *result = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // See comments on CREATE_CONTENT symbol above.
#ifdef CREATE_CONTENT
        result = [NSString stringWithFormat:@"Database-Filename-%d.sqlite", (int) arc4random_uniform(60000)];
#else
        result = [NSString stringWithFormat:@"Database-Filename.sqlite"];
#endif
    });
    return result;
}

+ (NSString *)sharedDataDatabaseFilePath
{
    return [self.appSharedDataDirectoryPath stringByAppendingPathComponent:self.databaseFilename];
}

- (NSString *)dbPath
{
    DemoLog(@"databasePath: %@", AppDelegate.sharedDataDatabaseFilePath);
    
    return AppDelegate.sharedDataDatabaseFilePath;
}

@end


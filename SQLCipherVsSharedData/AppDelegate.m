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
// Example App ID: org.signal.sqlciphervsshareddata
// Example App Group ID: org.signal.sqlciphervsshareddata.group
NSString *const kApplicationGroupId = @"group.org.signal.sqlciphervsshareddata";

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
    //
    // If you comment out this block, the app will _NOT_ be terminated when it is suspended.
    {
        NSString *encryptionKey = @"any key will do";
        NSData *keyData = [encryptionKey dataUsingEncoding:NSUTF8StringEncoding];
        int status = sqlite3_key(db, [keyData bytes], (int)[keyData length]);
        DemoAssert(status == SQLITE_OK);
    }
    // "journal_mode = WAL" + "create some content" is the simplest repro that I could find.
    // I'm not sure if it's possible to reproduce this issue without WAL enabled.
    {
        int status = sqlite3_exec(db, "PRAGMA journal_mode = WAL;", NULL, NULL, NULL);
        DemoAssert(status == SQLITE_OK);
    }
    {
        // We make the simplest possible modification to the database by creating a table.
        // There's nothing special about the CREATE TABLE command;
        // any SQL command that modifies the database will have the same effect.
        DemoAssert(isNewDatabaseFile);
        if (isNewDatabaseFile) {
            int status = sqlite3_exec(db, "CREATE TABLE groups ( group_id integer PRIMARY KEY );", NULL, NULL, NULL);
            DemoAssert(status == SQLITE_OK);
        }
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
        // In the "create a table" case, we can even create a new database file each time the app is launched
        // and it will still be terminated when sent to the background.
        result = [NSString stringWithFormat:@"Database-Filename-%d.sqlite", (int) arc4random_uniform(60000)];
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


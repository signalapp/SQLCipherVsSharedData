# SQL Cipher vs. shared data containers

### Summary

iOS apps can't share an encrypted database with app extensions (e.g. share extensions) without being terminated every time they enter the background.

iOS won't let suspended apps retain a file lock on apps in the "shared data container" used to share files between iOS apps & their app extensions.

This seems to affect all versions of iOS and all device models.

This issue can be reproduced with very simple SQLite/SQLCipher code, but there is a little bit of complexity around using a "shared data container" on an iOS device.  This demo app demonstrates how to do so.

### Discussion


Demo Project to demonstrate an issue.

* To share a database between an iOS app and iOS app extension (e.g. a share extension), the database file must reside in the "shared data container".
  * See: https://developer.apple.com/library/content/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html
* iOS terminates apps almost immediately if they retain a file lock on any file in the shared data container while being suspended.
  * These are `0xdead10cc` terminations and often don't yield crash logs on the device, but always show up in the device console logs.
  * iOS only terminates apps for this reason when app transition from the `background` to `suspended` states.  iOS main apps can delay this by creating a "background task", but this only defers the issue briefly.
  * These crashes don't occur in the simulator and won't occur on devices if the debugger is attached.
  * See Apple's documentation https://developer.apple.com/library/content/technotes/tn2151/_index.html
`
The exception code 0xdead10cc indicates that an application has been terminated by the OS because it held on to a file lock or sqlite database lock during suspension. If your application is performing operations on a locked file or sqlite database at suspension time, it must request additional background execution time to complete those operations and relinquish the lock before suspending.
`
* SQLCipher databases appear to retain a file lock on the database file at all times in some configurations.
  * This demo app demonstrates this behavior using an empty database with encryption enabled and  `journal_mode = WAL`.
  * There may be other configurations that also demonstrate this issue.
  * SQLCipher databases without encryption enabled _DO NOT_ exhibit this issue.
* This means that our iOS apps which which keep an encrypted SQLCipher database open at all times are terminated every time it is sent to the background.

### Steps to Reproduce

This issue doesn't reproduce in a simulator, so we're going to need to run on an actual iOS device (not a simulator), which means we'll need to use valid "app ids" and "app group ids".

If you're going to use this demo project:

* Make sure you have an active iOS Developer Account and an iOS device running iOS 9 or later.
* Go to Apple's iOS developer center
  * https://developer.apple.com/account/ios/identifier
  * Create a new app group.
     * The description doesn't matter.
     * Select an "app group id" like "group.com.yourcompany.something".
  * Create a new application id.
    * The description doesn't matter.
    * Select an "app id" like "com.yourcompany.something".
    * Enable App Groups & configure App Groups using the "app group id" you created above.
* Download this demo project and open it in a recent XCode (9?).
* Update Project:
  * Select the Project Navigator (left tab in left pane).
  * Select SQLCipherVsSharedData workspace.
  * Select SQLCipherVsSharedData target in left pane of editor.
  * Select General tab.
  * Change the bundle id to match the "app id" you created above.
  * Select Capabilities tab.
  * Make sure the "app groups" capability is enabled and _only_ the "app group id" you selected above is active.
  * Open AppDelegate.m.
  * Modify kApplicationGroupId constant to reflect the "app group id" you created above.
  * Run the app on your device - _NOT_ the simulator.
     * iOS doesn't terminate apps with 0xdead10cc in the simulator.
     * If you have signing problems, contact me at matthew@whispersystems.org.
  * Kill the app / stop the debugging session.
     * iOS doesn't terminate apps with 0xdead10cc if the debugger is attached.
  * On your attached Mac, open the Console app and select your iOS device in the left sidebar.
  * Launch the app.
  * Send the app to the background.
  * In Console (on your mac), you should see an entry like this:
  
  ```
  default    16:08:57.000000 -0500    SpringBoard     Forcing crash report of <FBApplicationProcess: 0x1394b57d0; SQLCipherVsShar; pid: 4146> (reason: 4, description: <FBApplicationProcess: 0x1394b57d0; SQLCipherVsShar; pid: 4146> was suspended with locked system files:
  /var/mobile/Containers/Shared/AppGroup/FCC1D74E-36AD-439C-B2AD-9E6D5B407DED/Database-Filename-51898.sqlite)
  
```
 
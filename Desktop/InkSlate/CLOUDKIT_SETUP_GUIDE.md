# CloudKit Setup Guide for InkSlate

This guide will help you configure CloudKit sync for your InkSlate app in Xcode.

## Prerequisites

- Xcode 15.0 or later
- Apple Developer Account (free or paid)
- iOS 17.0+ target
- macOS 14.0+ target (if supporting Mac)

## Step 1: Enable iCloud Capability

1. **Open your project in Xcode**
2. **Select your app target** (InkSlate)
3. **Go to "Signing & Capabilities" tab**
4. **Click the "+ Capability" button**
5. **Search for and add "iCloud"**

## Step 2: Configure CloudKit

1. **In the iCloud capability section:**
   - ✅ Check "CloudKit"
   - ✅ Check "Key-value storage" (optional, for app settings)

2. **Click "CloudKit Containers"**
3. **Click the "+" button to add a new container**
4. **Enter your container identifier:** `iCloud.com.lucas.InkSlateNew`
5. **Click "OK"**

## Step 3: Verify Container ID

Your CloudKit container ID should be: `iCloud.com.lucas.InkSlateNew`

**Important:** This must match exactly what's in your `SlateApp.swift` file:
```swift
cloudKitDatabase: .private("iCloud.com.lucas.InkSlateNew")
```

## Step 4: Configure Entitlements

Your `Slate.entitlements` file should contain:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.lucas.InkSlateNew</string>
    </array>
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)com.lucas.InkSlateNew</string>
</dict>
</plist>
```

## Step 5: Test CloudKit Setup

### On Simulator (Limited Testing)
1. **Sign in to iCloud in Simulator:**
   - Settings > Sign in to your iPhone
   - Use your Apple ID

2. **Run your app and check console logs:**
   - Look for: `✅ iCloud is available and user is signed in`
   - Look for: `✅ ModelContainer created successfully with CloudKit sync enabled`

### On Real Device (Recommended)
1. **Install on a real iOS device**
2. **Sign in to iCloud on the device**
3. **Run the app and create some test data**
4. **Check if data syncs to other devices**

## Step 6: CloudKit Dashboard (Optional)

1. **Visit:** https://icloud.developer.apple.com/dashboard/
2. **Select your container:** `iCloud.com.lucas.InkSlateNew`
3. **Review the schema** (auto-generated from SwiftData models)
4. **Monitor sync status and data**

## Troubleshooting

### Common Issues

#### 1. "iCloud is NOT available"
- **Solution:** Ensure user is signed in to iCloud on device
- **Check:** Settings > [User Name] > iCloud > Make sure iCloud is enabled

#### 2. "ModelContainer creation failed"
- **Solution:** Check that CloudKit container ID matches exactly
- **Verify:** Container exists in Apple Developer portal

#### 3. Data not syncing
- **Solution:** Test on real devices (CloudKit doesn't work reliably in simulator)
- **Check:** Both devices signed in to same iCloud account
- **Wait:** Initial sync can take several minutes

#### 4. "CloudKit database not available"
- **Solution:** Ensure proper entitlements configuration
- **Check:** Container identifier matches in code and Xcode

### Debug Steps

1. **Check console logs for CloudKit status**
2. **Verify iCloud sign-in status**
3. **Test on multiple real devices**
4. **Wait for initial sync (can take 5-10 minutes)**

## Testing Sync

### Create Test Data
1. **Add a note, journal entry, or todo item**
2. **Save the data (app should auto-save)**
3. **Check console for:** `✅ Data saved to CloudKit`

### Verify Sync
1. **Install app on second device**
2. **Sign in to same iCloud account**
3. **Wait 5-10 minutes for initial sync**
4. **Check if data appears**

## Important Notes

- **CloudKit sync is automatic** - you don't need to manually trigger it
- **SwiftData handles all CloudKit operations** - no custom CloudKit code needed
- **Test on real devices** - simulator has limited CloudKit support
- **Initial sync can be slow** - be patient on first launch
- **Data syncs in background** - users don't need to manually sync

## Success Indicators

✅ Console shows: `✅ iCloud is available and user is signed in`
✅ Console shows: `✅ ModelContainer created successfully with CloudKit sync enabled`
✅ Data appears on multiple devices
✅ No CloudKit errors in console
✅ Sync status shows "Synced with iCloud"

## Need Help?

If you encounter issues:
1. Check the console logs for specific error messages
2. Verify your CloudKit container ID matches exactly
3. Test on real devices, not simulator
4. Ensure both devices are signed in to the same iCloud account
5. Wait for initial sync (can take several minutes)

---

**Remember:** CloudKit sync with SwiftData is designed to "just work" - the framework handles all the complex sync logic automatically!

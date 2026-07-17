# PlanSync Live Activity — one-time Xcode setup

The Dart side + Swift UI are done. You just need to add the Widget Extension target
in Xcode once (this can't be scripted safely from the CLI).

## Steps (~3 min)

1. Open the workspace:
   `open ios/Runner.xcworkspace`

2. **File ▸ New ▸ Target… ▸ Widget Extension**.
   - Product Name: **`PlanSyncWidget`**
   - ✅ tick **Include Live Activity**
   - Uncheck "Include Configuration App Intent" if offered.
   - Finish. When asked to activate the scheme, click **Activate**.
   - Set the extension's **Minimum Deployments** to **iOS 16.1** (target ▸ General).

3. Replace the auto-generated live-activity file with ours:
   - Delete the generated `PlanSyncWidgetLiveActivity.swift` **and** `PlanSyncWidget.swift`
     (the sample home-screen widget) from the `PlanSyncWidget` group.
   - Drag **`ios/PlanSyncWidget/PlanSyncWidgetLiveActivity.swift`** (this folder) into the
     `PlanSyncWidget` group, ✅ *Copy items if needed*, target = **PlanSyncWidget**.
   - Open the generated `PlanSyncWidgetBundle.swift` and make its body just:
     ```swift
     @main
     struct PlanSyncWidgetBundle: WidgetBundle {
       var body: some Widget { PlanSyncWidgetLiveActivity() }
     }
     ```

4. **App Group** on BOTH targets (Signing & Capabilities ▸ + Capability ▸ App Groups):
   - Add group **`group.com.supremolabs.plansync`** to the **Runner** target.
   - Add the **same** group to the **PlanSyncWidget** target.
   (Must match `LiveActivityService._appGroupId` and `sharedDefault` in the Swift file.)

5. Back in the repo root:
   ```
   export PATH="$HOME/Documents/FlutterVersions/flutter/bin:$PATH"
   cd ios && pod install && cd ..
   flutter run
   ```

## Verify
Create/seed a plan starting soon → it appears on the Lock Screen and Dynamic Island,
styled like the app. Editing plans updates it; when nothing is upcoming it ends.

Notes: iOS 16.1+; Live Activities can't show on the Simulator's always-on display but do
appear when you lock the simulator screen (Device ▸ Lock). `NSSupportsLiveActivities` is
already set in `Runner/Info.plist`.

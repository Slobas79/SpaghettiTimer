# Widget target setup

The Swift sources for the widget are in this folder, but the Widget Extension Xcode target still needs to be created. Hand-editing `project.pbxproj` to add an extension target is fragile — these steps in the Xcode UI take ~2 minutes and are reliable.

## 1. Add the Widget Extension target

1. Open `SpaghettiTimer.xcodeproj`.
2. **File → New → Target…** → iOS → **Widget Extension**.
3. Product Name: `SpaghettiTimerWidget`. Bundle Identifier: `sloba.SpaghettiTimer.SpaghettiTimerWidget`. **Include Live Activity: ON**. **Include Configuration App Intent: OFF**.
4. When prompted to activate the new scheme, choose **Activate**.

## 2. Replace the generated files

Xcode generates a few default files in the new `SpaghettiTimerWidget` group. Delete them (Move to Trash), then drag the four files already present in the `SpaghettiTimerWidget/` folder on disk into the `SpaghettiTimerWidget` group in Xcode:

- `SpaghettiTimerWidgetBundle.swift`
- `PresetsWidget.swift`
- `TimerLiveActivity.swift`

Make sure **target membership = SpaghettiTimerWidget** (not the app).

## 3. Share the cross-target source files

The widget needs to compile the same entity, repo, intent, and attributes types as the app. Select each of these files in the Project Navigator and tick **SpaghettiTimerWidget** in the File Inspector's Target Membership pane:

- `SpaghettiTimer/Shared/AppGroup.swift`
- `SpaghettiTimer/Shared/TimerActivityAttributes.swift`
- `SpaghettiTimer/Shared/StartTimerIntent.swift`
- `SpaghettiTimer/Model/Entity/TimerPreset.swift`
- `SpaghettiTimer/Model/Entity/RunningTimer.swift`
- `SpaghettiTimer/Repository/Disc/PresetsRepo.swift`
- `SpaghettiTimer/Repository/Disc/RunningTimersRepo.swift`

## 4. App Group capability

The widget reads the same `UserDefaults` suite the app writes to.

1. Select the **SpaghettiTimer** target → **Signing & Capabilities** → **+ Capability** → **App Groups** → add `group.sloba.SpaghettiTimer`.
2. Select the **SpaghettiTimerWidget** target → same steps → add `group.sloba.SpaghettiTimer`.

## 5. Live Activities Info.plist key

On the **SpaghettiTimer** target's Info pane, add the key **`NSSupportsLiveActivities`** = **YES**.

## 6. Build & run

Build the `SpaghettiTimer` scheme. Both targets should compile. Add the widget to the Home Screen and tap a preset's Start button — a Live Activity should appear, and reopening the app shows the same countdown in its grid tile.

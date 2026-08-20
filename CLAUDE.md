# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Build and run via Xcode — open `SpaghettiTimer.xcodeproj` and use the `SpaghettiTimer` scheme. There is no CLI build script.

From the command line (requires a connected device or a booted simulator):

```bash
xcodebuild -project SpaghettiTimer.xcodeproj -scheme SpaghettiTimer -destination 'platform=iOS Simulator,name=iPhone 17' build
```

There are no linting tools or package managers in this project.

## Testing — mandatory

`SpaghettiTimerTests` is a Swift Testing (`import Testing`) unit-test target, wired into the `SpaghettiTimer` scheme. Run it from the command line:

```bash
xcodebuild -project SpaghettiTimer.xcodeproj -scheme SpaghettiTimer -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Rules — these are not optional:

1. **Run the tests after every code change.** Any edit to source in `SpaghettiTimer/` or `SpaghettiTimerWidget/` must be followed by a full test run before the task is reported as done.
2. **The task is not finished until the tests pass.** A failing or erroring test run means the work is incomplete — fix the code and re-run until green. Never report completion on a red or unrun suite, and never describe a failure as pre-existing without showing the failing output.
3. **Do not change existing tests without explicit approval from the user.** Editing, weakening, renaming, skipping, deleting, or disabling an existing test — including changing its expectations to match new behaviour — requires asking first and getting a yes. If a change breaks a test, the default assumption is that the change is wrong, not the test. Adding *new* tests for new behaviour is always allowed and encouraged.

## Architecture

Clean Architecture in three layers:

```
View / ViewModel  →  UseCase (protocol + impl)  →  Repo (protocol + impl)
```

- **Entities** (`SpaghettiTimer/Model/Entity/`): `TimerPreset` and `RunningTimer` — plain `nonisolated` structs, `Codable`, `Sendable`.
- **Repos** (`SpaghettiTimer/Repository/Disc/`): Read/write `UserDefaults` in the shared App Group (`group.sloba.SpaghettiTimer`). `PresetsRepo` manages user presets and hidden built-in IDs. `RunningTimersRepo` persists active timers.
- **Use Cases** (`SpaghettiTimer/Model/UseCase/`): `@MainActor` classes that own the in-memory state and call into AlarmKit. `RunningTimersUseCaseImpl` drives the AlarmKit lifecycle (schedule, pause, resume, cancel) and observes `AlarmManager.shared.alarmUpdates` to reconcile state. `TimerPresetsUseCaseImpl` merges built-in presets with user-created ones.
- **ViewModel** (`TimersViewModel`): `@Observable @MainActor` class. Single instance created at app launch and injected through `HomeView`. Subscribes to `onChange` callbacks from both use cases to republish state. Exposes `tiles: [TileItem]` — running-timers-first ordering merged with the preset list.
- **Views**: `TimersView` is the main screen — a `LazyVGrid` of `TimerTile`s refreshed every 0.25 s via `TimelineView`. `NewTimerSheet` creates either a pinned preset or an ephemeral one-shot timer.

## Key Dependencies

### AlarmKit (iOS 26)
The app targets iOS 26 (deployment target 26.0–26.2). Timer countdowns are driven by **AlarmKit**, not `Timer` or `DispatchQueue`. `AlarmManager.shared` schedules/pauses/resumes/cancels alarms identified by `UUID`. Alarm state changes arrive via `AlarmManager.shared.alarmUpdates` async sequence.

`AlarmAttributes<SpaghettiTimerMetadata>` is the Live Activity attributes type, where `SpaghettiTimerMetadata` carries `presetName` and `alarmID` (the UUID string of the `RunningTimer`).

### App Group data sharing
Both targets read and write the same `UserDefaults` suite via `AppGroup.defaults` (`group.sloba.SpaghettiTimer`). Keys are defined in `AppGroupKey`. This is the only persistence mechanism; there is no CoreData or SwiftData.

### Widget Extension (`SpaghettiTimerWidget` target)
The widget bundle registers two widgets:
- `PresetsWidget` — `StaticConfiguration`, shows preset tiles with `StartTimerIntent` buttons. Timeline entries are generated at timer end-dates so the active-indicator dot disappears automatically.
- `TimerLiveActivity` — `ActivityConfiguration` for `AlarmAttributes<SpaghettiTimerMetadata>`, renders the lock screen / Dynamic Island countdown.

### Shared source files (compiled into both targets)
`AppGroup`, `TimerActivityAttributes` (`SpaghettiTimerMetadata`), `StartTimerIntent`, `TimerPreset`, `RunningTimer`, `PresetsRepo`, `RunningTimersRepo`.

### AppIntents
`StartTimerIntent`, `PauseTimerIntent`, `ResumeTimerIntent`, `CancelTimerIntent` are implemented in the main app target and wired to widget buttons. They write directly to `RunningTimersRepoImpl` (bypassing the in-app use case) and call `AlarmManager.shared` + `WidgetCenter.shared.reloadAllTimelines()`.

## Concurrency model

- Repo protocols are `nonisolated` and `Sendable` — safe to call from any actor.
- Use cases and `TimersViewModel` are `@MainActor`.
- `AlarmKit` calls inside use cases are dispatched with `Task { }` (inherits `@MainActor`) then bridge to `async` AlarmKit APIs.
- `AppIntent.perform()` runs off the main actor; intents access repos directly without going through use cases.

## Pause / resume state

`RunningTimer.pausedAt: Date?` tracks when a timer was paused. On resume, `startDate` is shifted forward by the elapsed pause duration so `endDate` stays accurate. This same pattern is duplicated in both `RunningTimersUseCaseImpl` and `ResumeTimerIntent` — they must stay in sync.

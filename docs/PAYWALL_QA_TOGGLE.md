# Paywall QA toggle

The paywall is currently **disabled** so the whole app can be QA'd without a
purchase. This document is everything you need to turn it back on — no
assistance required.

## Re-enable the paywall (the only step that matters)

Open `SpaghettiTimer/Model/Store/ProConfig.swift` and flip one line:

```swift
static let qaUnlockAllPro = true   // ← change to false
```

to

```swift
static let qaUnlockAllPro = false
```

Rebuild. That's it. Nothing else was changed, and there is no second flag
hiding anywhere.

> **Before shipping / archiving to TestFlight or the App Store, this must be
> `false`.** With it `true` every user gets Pro for free.

## What the flag does

`ProConfig.qaUnlockAllPro` forces `StoreUseCase.isPro` to `true`. Two places
read it, both in `SpaghettiTimer/Model/UseCase/StoreUseCase.swift`:

| Location | Line looks like | Purpose |
| --- | --- | --- |
| Property initialiser | `private(set) var isPro: Bool = ProConfig.qaUnlockAllPro` | Pro is on from the very first frame, before StoreKit answers |
| `refreshEntitlements()` | `isPro = owned \|\| ProConfig.qaUnlockAllPro` | The StoreKit refresh (and `restore()`, which calls it) can't flip Pro back off |

Every gate in the app funnels through `isPro`, so that single flag covers all
of them:

- `canPin(currentUserPresetCount:)` — the 3-pinned-preset free cap
- `canPinNextHour()` — the Pro-only "To next hour" dynamic tile
- `canEnableAutoRestart()` — the 3-use auto-restart free trial
- `registerAutoRestartUse()` — becomes a no-op, so the free trial counter is
  **not** consumed during QA
- The "Unlock Pro" item in the ••• menu on Home (`TimersView`) — hidden while
  Pro is on

## What QA behaviour to expect while it's `true`

- Pin as many presets as you like; the pin-limit paywall never appears.
- The auto-restart toggle always turns on; the auto-restart paywall never
  appears.
- The end-time "To next hour" pin works; the next-hour paywall never appears.
- The ••• menu shows **Replay tips** and **Restore Purchases**, but not
  **Unlock Pro**.
- The stored free auto-restart use count is untouched, so turning the flag back
  to `false` restores exactly the free-tier state you had before QA.

## How to still see the paywall while the flag is on

`PaywallView` itself is unchanged and still renders fine — the SwiftUI previews
at the bottom of `SpaghettiTimer/View/Screens/Paywall/PaywallView.swift` show
all three trigger variants (`.autoRestart`, `.pinLimit`, `.nextHour`). Use
those, or temporarily set the flag to `false`, to QA the paywall screen itself.

## Verifying it is off again

After setting the flag to `false`:

1. `grep -rn "qaUnlockAllPro" SpaghettiTimer/` should show the declaration in
   `ProConfig.swift` (now `false`) and the two reads in `StoreUseCase.swift`.
2. Launch on a simulator with a fresh install and try to pin a 4th user preset
   — the paywall should appear.

## Removing the toggle entirely (optional)

If you'd rather not carry the flag at all:

1. Delete the `qaUnlockAllPro` declaration from `ProConfig.swift`.
2. In `StoreUseCase.swift`, restore the two lines to
   `private(set) var isPro: Bool = false` and `isPro = owned`.
3. Delete this file.

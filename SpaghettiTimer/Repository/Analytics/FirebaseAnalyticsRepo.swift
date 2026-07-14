//
//  FirebaseAnalyticsRepo.swift
//  SpaghettiTimer
//
//  Firebase-backed analytics — main app target only. Everything here is gated on
//  `canImport(FirebaseAnalytics)`, so the project builds and runs today with no
//  SDK present (falling back to NoOpAnalyticsRepo) and lights up automatically
//  once the `firebase-ios-sdk` package is added in Xcode. See ANALYTICS_SPEC.md
//  §5 for the remaining manual setup (SPM product + GoogleService-Info.plist).
//

import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics

nonisolated struct FirebaseAnalyticsRepoImpl: AnalyticsRepo {
    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.firebaseParameters)
    }
}

nonisolated private extension AnalyticsEvent {
    var firebaseParameters: [String: Any] {
        params.mapValues { value in
            switch value {
            case .string(let string): return string as NSString
            case .int(let int): return int as NSNumber
            }
        }
    }
}
#endif

/// Configuration + queue-flush entry points used by the app at launch and on
/// foreground. Kept free of any hard Firebase reference outside `#if` guards.
enum AnalyticsBootstrap {
    /// Initialises Firebase. No-op in DEBUG and when the SDK isn't linked.
    static func configure() {
        #if canImport(FirebaseCore) && !DEBUG
        FirebaseCoreShim.configure()
        #endif
    }

    /// The repo the main app logs through. DEBUG and no-SDK builds get a no-op so
    /// development traffic never reaches the production GA4 property.
    static func makeRepo() -> AnalyticsRepo {
        #if canImport(FirebaseAnalytics) && !DEBUG
        return FirebaseAnalyticsRepoImpl()
        #else
        return NoOpAnalyticsRepo()
        #endif
    }

    /// Replays events queued by out-of-process AppIntents into the live repo.
    static func flushPending(into repo: AnalyticsRepo) {
        for event in PendingAnalyticsQueueRepoImpl.drain() {
            repo.log(event)
        }
    }
}

#if canImport(FirebaseCore) && !DEBUG
import FirebaseCore

private enum FirebaseCoreShim {
    static func configure() {
        FirebaseApp.configure()
    }
}
#endif

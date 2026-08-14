//
//  DeviceCapabilities.swift
//  SpaghettiTimer
//
//  Hardware traits the UI adapts to. Currently just one: whether this iPhone
//  has a Dynamic Island, which gates the tour tip that explains it.
//

import UIKit

@MainActor
enum DeviceCapabilities {
    /// Cached once a real (non-zero) reading is available — the trait can't
    /// change for the life of the process.
    private static var cachedHasDynamicIsland: Bool?

    /// True on iPhones with a Dynamic Island.
    ///
    /// There is no public API for this, so it's inferred from the cutout inset:
    /// notched iPhones report at most 50pt (iPhone 13 mini), Dynamic Island
    /// iPhones report 59pt or more (62pt on Pro sizes). The threshold sits in
    /// the gap between the two so neither class is near it. In landscape the
    /// cutout moves to the left/right insets, hence the max.
    static var hasDynamicIsland: Bool {
        if let cachedHasDynamicIsland { return cachedHasDynamicIsland }
        guard UIDevice.current.userInterfaceIdiom == .phone,
              let insets = keyWindow?.safeAreaInsets else { return false }

        let cutout = max(insets.top, insets.left, insets.right)
        // A zero reading means the window isn't laid out yet — answer "no" for
        // now but don't cache it, so a later call can still get it right.
        guard cutout > 0 else { return false }

        let result = cutout > 54
        cachedHasDynamicIsland = result
        return result
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

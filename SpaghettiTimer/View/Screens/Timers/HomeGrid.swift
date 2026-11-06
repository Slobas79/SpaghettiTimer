//
//  HomeGrid.swift
//  SpaghettiTimer
//
//  How many tile columns the Home grid gets for the width it has. Two fixed
//  columns made each tile about 440pt wide on the unfolded iPhone Duo, so only
//  one row fit and the second sat under the + and ••• buttons.
//

import SwiftUI

nonisolated enum HomeGrid {
    /// The narrowest a tile may get before the grid adds a column. An upright
    /// iPhone has room for two at most — the widest, the folded iPhone Duo,
    /// gives the grid about 426pt — so every one keeps the two columns the
    /// design is drawn for. The unfolded Duo's ~850pt takes four.
    static let minimumTileWidth: CGFloat = 180

    /// Columns for a grid `width` points wide with `spacing` between tiles:
    /// as many tiles of at least `minimumTileWidth` as fit, never fewer than
    /// two. A width not measured yet (zero) gets two.
    static func columnCount(forWidth width: CGFloat, spacing: CGFloat) -> Int {
        guard width.isFinite, width > 0 else { return 2 }
        let fit = ((width + spacing) / (minimumTileWidth + spacing)).rounded(.down)
        return max(2, Int(fit))
    }

    static func columns(forWidth width: CGFloat, spacing: CGFloat) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing),
              count: columnCount(forWidth: width, spacing: spacing))
    }
}

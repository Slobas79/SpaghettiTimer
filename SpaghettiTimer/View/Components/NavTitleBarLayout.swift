//
//  NavTitleBarLayout.swift
//  SpaghettiTimer
//
//  A nav bar row with buttons at both ends and a title centred on the bar.
//  The New Timer sheet used to centre its title in a ZStack over the
//  buttons, so any translation wider than the gap ran under Start (fr and
//  ro even on iPhone 17; es, pt-PT and el too on iPhone SE).
//

import SwiftUI

/// Lays out exactly three subviews: the leading buttons, the title, the
/// trailing buttons. The title stays centred on the bar while it fits
/// between the buttons; when it doesn't, it slides toward the roomier side,
/// and only when even the whole gap is too narrow is it offered less than
/// its ideal width — pair it with `lineLimit(1)` and `minimumScaleFactor` so
/// it shrinks instead of wrapping.
struct NavTitleBarLayout: Layout {
    /// Minimum space between the title and either group of buttons.
    var gap: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width ?? ideal.reduce(2 * gap) { $0 + $1.width }
        let height = proposal.height ?? ideal.map(\.height).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let (leading, title, trailing) = (subviews[0], subviews[1], subviews[2])

        let leadingWidth = leading.sizeThatFits(.unspecified).width
        let trailingWidth = trailing.sizeThatFits(.unspecified).width
        leading.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: .unspecified)
        trailing.place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: .unspecified)

        let span = Self.titleSpan(barWidth: bounds.width,
                                  leadingWidth: leadingWidth,
                                  trailingWidth: trailingWidth,
                                  titleWidth: title.sizeThatFits(.unspecified).width,
                                  gap: gap)
        title.place(at: CGPoint(x: bounds.minX + (span.lowerBound + span.upperBound) / 2, y: bounds.midY),
                    anchor: .center,
                    proposal: ProposedViewSize(width: span.upperBound - span.lowerBound, height: bounds.height))
    }

    /// The stretch of the bar the title gets, measured from its leading edge.
    /// Centred on the bar when that clears both button groups by `gap`,
    /// otherwise pushed just clear of the nearer group, and never wider than
    /// the room between them.
    nonisolated static func titleSpan(barWidth: CGFloat,
                                      leadingWidth: CGFloat,
                                      trailingWidth: CGFloat,
                                      titleWidth: CGFloat,
                                      gap: CGFloat) -> ClosedRange<CGFloat> {
        let lowest = leadingWidth + gap
        let highest = max(lowest, barWidth - trailingWidth - gap)
        let width = min(titleWidth, highest - lowest)
        let start = min(max((barWidth - width) / 2, lowest), highest - width)
        return start...(start + width)
    }
}

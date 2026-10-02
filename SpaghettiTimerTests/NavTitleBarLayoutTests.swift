//
//  NavTitleBarLayoutTests.swift
//  SpaghettiTimerTests
//
//  The New Timer title used to be centred in a ZStack over the buttons, so
//  “Nouveau minuteur” and “Temporizator nou” ran under Start. These hold the
//  title between the buttons without moving it off centre when it fits.
//

import CoreGraphics
import Testing
@testable import SpaghettiTimer

@Suite("Nav bar title placement")
struct NavTitleBarLayoutTests {
    /// The New Timer bar on iPhone 17 (402 pt sheet, 18 pt side padding):
    /// Cancel and Show tips on the leading side, Start on the trailing side.
    private func span(title: CGFloat, leading: CGFloat = 92, trailing: CGFloat = 80,
                      bar: CGFloat = 366) -> ClosedRange<CGFloat> {
        NavTitleBarLayout.titleSpan(barWidth: bar, leadingWidth: leading, trailingWidth: trailing,
                                    titleWidth: title, gap: 8)
    }

    @Test("A title that fits stays centred on the bar")
    func fittingTitleIsCentred() {
        #expect(span(title: 100) == 133...233)
    }

    @Test("A title that would reach Start slides toward the roomier side at full width")
    func titleSlidesClearOfStart() {
        // Centred it would span 118...248, past Start's edge at 242.
        #expect(span(title: 130, trailing: 116) == 112...242)
    }

    @Test("A title that would reach the leading buttons slides the other way")
    func titleSlidesClearOfLeadingButtons() {
        // Centred it would start at 118, before the leading buttons end at 124.
        #expect(span(title: 130, leading: 116) == 124...254)
    }

    @Test("A title wider than the gap gets exactly the gap, so it shrinks instead of overlapping")
    func wideTitleGetsTheWholeGap() {
        #expect(span(title: 400, trailing: 116) == 100...242)
    }

    @Test("With no room between the buttons the title gets no width")
    func noRoomGivesNoWidth() {
        let placed = span(title: 100, leading: 180, trailing: 180)

        #expect(placed.lowerBound == placed.upperBound)
    }

    @Test("The title never overlaps either group of buttons",
          arguments: [0.0, 50, 120, 150, 170, 200, 260, 400])
    func neverOverlaps(title: CGFloat) {
        for (leading, trailing) in [(92.0, 80.0), (92, 116), (116, 92), (60, 140)] {
            let placed = span(title: title, leading: leading, trailing: trailing)

            #expect(placed.lowerBound >= leading + 8)
            #expect(placed.upperBound <= 366 - trailing - 8)
            #expect(placed.upperBound - placed.lowerBound <= title)
        }
    }
}

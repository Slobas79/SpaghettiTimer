//
//  HomeGridTests.swift
//  SpaghettiTimerTests
//
//  On the unfolded iPhone Duo two fixed columns made each Home tile about
//  440pt wide, so one row filled the screen. These keep every upright iPhone
//  on two columns and give the wide screen more.
//

import CoreGraphics
import Testing
@testable import SpaghettiTimer

@Suite("Home grid columns")
struct HomeGridTests {
    private let gap: CGFloat = 16

    private func columns(_ width: CGFloat) -> Int {
        HomeGrid.columnCount(forWidth: width, spacing: gap)
    }

    /// Grid widths (screen width minus 2 × 20pt padding) of upright iPhones:
    /// SE with Display Zoom, SE, iPhone 17, Pro Max, and the folded iPhone Duo.
    @Test("Every upright iPhone keeps two columns", arguments: [280, 335, 362, 400, 426] as [CGFloat])
    func phonesKeepTwoColumns(width: CGFloat) {
        #expect(columns(width) == 2)
    }

    @Test("Nothing narrower than three 180pt tiles gets a third column")
    func twoColumnsUpToThreeTiles() {
        for width in stride(from: 1, through: 571, by: 1) {
            #expect(columns(CGFloat(width)) == 2, "width \(width)")
        }
        #expect(columns(572) == 3)
    }

    @Test("The unfolded iPhone Duo gets four columns")
    func unfoldedDuoGetsFour() {
        // 951pt screen, less the padding and either side's safe area.
        #expect(columns(850) == 4)
        #expect(columns(911) == 4)
    }

    @Test("A width not measured yet, or not a number, gets two columns",
          arguments: [0, -10, .nan, .infinity] as [CGFloat])
    func unmeasuredWidthGetsTwo(width: CGFloat) {
        #expect(columns(width) == 2)
    }

    @Test("The column items match the count and use the grid's spacing")
    func itemsMatchCount() {
        let items = HomeGrid.columns(forWidth: 850, spacing: gap)
        #expect(items.count == 4)
        #expect(items.allSatisfy { $0.spacing == gap })
    }
}

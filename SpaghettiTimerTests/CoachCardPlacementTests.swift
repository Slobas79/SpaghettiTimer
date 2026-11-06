//
//  CoachCardPlacementTests.swift
//  SpaghettiTimerTests
//
//  On the unfolded iPhone Duo, tour tip 1's card had no room below the tile,
//  went above where it had none either, and ran down over the tile. These
//  check the card now takes the roomier side in that case, and lands where it
//  always did everywhere it fits.
//

import CoreGraphics
import Testing
@testable import SpaghettiTimer

@Suite("Tour card placement")
struct CoachCardPlacementTests {
    private func below(minY: CGFloat, maxY: CGFloat, height: CGFloat, card: CGFloat) -> Bool {
        CoachCardPlacement.isBelow(spot: CGRect(x: 20, y: minY, width: 160, height: maxY - minY),
                                   height: height, cardHeight: card)
    }

    @Test("With room below the target, the card goes below")
    func roomBelowGoesBelow() {
        // Tip 1 on an iPhone 17: the first tile, near the top.
        #expect(below(minY: 10, maxY: 200, height: 780, card: 190))
    }

    @Test("Without room below but with room above, the card goes above")
    func roomAboveGoesAbove() {
        // The + button at the bottom of the screen.
        #expect(!below(minY: 690, maxY: 760, height: 780, card: 190))
    }

    @Test("With room on neither side, the card takes the roomier one")
    func neitherSideTakesTheRoomier() {
        // The unfolded Duo before the grid fix: one huge tile at the top.
        #expect(below(minY: 0, maxY: 357, height: 669, card: 200))
        // Roomier above: a target low on a short screen with a tall card.
        #expect(!below(minY: 300, maxY: 420, height: 600, card: 330))
    }

    @Test("Before the card is measured, the old rule decides")
    func unmeasuredCardKeepsOldRule() {
        #expect(!below(minY: 300, maxY: 420, height: 650, card: 0))
        #expect(below(minY: 10, maxY: 200, height: 780, card: 0))
    }

    @Test("Wherever the card fits above, the answer matches the old rule")
    func matchesOldRuleWhenTheCardFits() {
        let height: CGFloat = 700
        let card: CGFloat = 180
        for minY in stride(from: card + CoachCardPlacement.gap, through: 640, by: 10) {
            for size in stride(from: CGFloat(20), through: 200, by: 30) {
                let maxY = minY + size
                let old = maxY < height - 324
                #expect(below(minY: minY, maxY: maxY, height: height, card: card) == old,
                        "spot \(minY)…\(maxY)")
            }
        }
    }
}

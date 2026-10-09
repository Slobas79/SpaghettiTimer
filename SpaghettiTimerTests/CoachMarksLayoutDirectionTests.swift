//
//  CoachMarksLayoutDirectionTests.swift
//  SpaghettiTimerTests
//
//  In Arabic the tour's spotlight was drawn at the mirrored x position: tip 1
//  lit up the second tile instead of the first. These render the overlay over
//  two tiles and check which one shows through the cutout.
//

import SwiftUI
import Testing
@testable import SpaghettiTimer

@Suite("Tour spotlight in both layout directions")
@MainActor
struct CoachMarksLayoutDirectionTests {
    private static let tile: CGFloat = 100
    private static let height: CGFloat = 700

    /// Two tiles side by side, the first one marked as the tour's target, with
    /// the tour on screen. In right-to-left layout the first tile is on the right.
    private func render(_ direction: LayoutDirection) throws -> CGImage {
        let step = TutorialStep(target: .presetTile, title: "Tap to start", body: "Body")
        let screen = HStack(spacing: 0) {
            Color.red.frame(width: Self.tile, height: Self.tile)
                .tutorialTarget(.presetTile)
            Color.green.frame(width: Self.tile, height: Self.tile)
        }
        .frame(width: Self.tile * 2, height: Self.height, alignment: .top)
        .coachMarks(.home, isActive: .constant(true), steps: [step])
        .environment(\.layoutDirection, direction)

        let renderer = ImageRenderer(content: screen)
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    /// The brightest colour channel at a point, 0–255.
    private func brightness(in image: CGImage, x: Int, y: Int) throws -> UInt8 {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Draw the image shifted so the wanted pixel lands on the 1×1 context.
        // Core Graphics counts y from the bottom.
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1,
                                       width: image.width, height: image.height))
        return pixel[0..<3].max() ?? 0
    }

    /// Whether the cutout is over the tile whose left edge is at `minX`: its
    /// centre shows at full colour instead of under the 72% scrim.
    private func isLit(_ image: CGImage, tileAtX minX: CGFloat) throws -> Bool {
        let half = Int(Self.tile / 2)
        return try brightness(in: image, x: Int(minX) + half, y: half) > 150
    }

    @Test("Left-to-right: the spotlight is on the first tile, at the left")
    func leftToRight() throws {
        let image = try render(.leftToRight)
        #expect(try isLit(image, tileAtX: 0))
        #expect(try !isLit(image, tileAtX: Self.tile))
    }

    @Test("Right-to-left: the spotlight is on the first tile, at the right")
    func rightToLeft() throws {
        let image = try render(.rightToLeft)
        #expect(try isLit(image, tileAtX: Self.tile))
        #expect(try !isLit(image, tileAtX: 0))
    }
}

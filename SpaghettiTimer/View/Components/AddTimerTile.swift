//
//  AddTimerTile.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import SwiftUI

struct AddTimerTile: View {
    let action: () -> Void

    @ScaledMetric(relativeTo: .title) private var plusSize: CGFloat = 30

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: plusSize, weight: .semibold))
                .foregroundStyle(Theme.addPlus)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.addDash, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add timer")
        .accessibilityHint("Creates a new timer")
    }
}

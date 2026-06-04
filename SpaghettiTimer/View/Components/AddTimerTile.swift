//
//  AddTimerTile.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import SwiftUI

struct AddTimerTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.addPlus)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.addDash, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                )
        }
        .buttonStyle(.plain)
    }
}

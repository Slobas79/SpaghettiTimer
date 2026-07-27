//
//  PaywallView.swift
//  SpaghettiTimer
//
//  The single, contextual paywall for SpaghettiTimer Pro. Presented at the
//  point of desire — when a free user taps a fourth pin or reaches for
//  auto-restart after the trial — and also reachable directly for a plain
//  "unlock / restore". One SKU, one price, no dark patterns.
//

import SwiftUI

/// Why the paywall was shown. Doubles as the `.sheet(item:)` identity and
/// carries the contextual copy for each entry point.
enum PaywallTrigger: String, Identifiable {
    case autoRestart
    case pinLimit
    case general

    var id: String { rawValue }

    /// Headline tuned to what the user just reached for.
    var headline: LocalizedStringKey {
        switch self {
        case .autoRestart: return "Keep your timers looping"
        case .pinLimit:    return "Room for every timer"
        case .general:     return "Unlock the full timer"
        }
    }

    var subhead: LocalizedStringKey {
        switch self {
        case .autoRestart: return "You've used auto-restart on the house. Unlock it for good — plus unlimited pinned presets."
        case .pinLimit:    return "You've filled your free presets. Go unlimited — and unlock auto-restart while you're at it."
        case .general:     return "One upgrade unlocks everything below."
        }
    }
}

struct PaywallView: View {
    let store: StoreUseCase
    let trigger: PaywallTrigger

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                closeRow
                header
                    .padding(.top, 4)
                    .padding(.bottom, 30)
                features
                    .padding(.bottom, 24)
                reassurance
                    .padding(.bottom, 18)
                unlockButton
                restoreButton
                    .padding(.top, 14)
                terms
                    .padding(.top, 18)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { store.logPaywallShown(trigger) }
    }

    // MARK: - Close

    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.lightText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.subtleFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.top, 8)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .shadow(color: Theme.accent.opacity(0.5), radius: 16, y: 6)
                .accessibilityHidden(true)

            Text("SpaghettiTimer Pro")
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            Text(trigger.headline)
                .font(.system(size: bodySize + 2, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)

            Text(trigger.subhead)
                .font(.system(size: bodySize))
                .foregroundStyle(Theme.mutedTime)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Features

    private var features: some View {
        VStack(spacing: 0) {
            featureRow(
                icon: "arrow.clockwise",
                title: "Auto-restart",
                description: "Loop any timer automatically after a cooldown — perfect for intervals and batches."
            )
            hairline
            featureRow(
                icon: "infinity",
                title: "Unlimited presets",
                description: "Pin as many timers as you like, always one tap away."
            )
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceFill))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.surfaceBorder, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func featureRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: bodySize + 1, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: bodySize - 2))
                    .foregroundStyle(Theme.mutedTime)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private var hairline: some View {
        Rectangle().fill(Theme.hairline).frame(height: 0.5)
    }

    // MARK: - Reassurance

    private var reassurance: some View {
        Label("One-time purchase · No subscription", systemImage: "checkmark.seal.fill")
            .font(.system(size: bodySize - 2, weight: .medium))
            .foregroundStyle(Theme.success)
    }

    // MARK: - Buttons

    private var unlockButton: some View {
        Button {
            Task {
                if await store.purchase() { dismiss() }
            }
        } label: {
            ZStack {
                if store.purchaseInFlight {
                    ProgressView().tint(.white)
                } else {
                    Text(unlockTitle)
                        .font(.system(size: bodySize + 2, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Capsule().fill(store.canPurchase ? Theme.accent : Theme.disabledFill)
            )
            .shadow(color: store.canPurchase ? Theme.accent.opacity(0.4) : .clear, radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!store.canPurchase)
        .accessibilityLabel(unlockAccessibilityLabel)
    }

    private var unlockTitle: String {
        if let price = store.displayPrice {
            return String(localized: "Unlock — \(price)")
        }
        return store.isLoadingProduct
            ? String(localized: "Loading…")
            : String(localized: "Unavailable")
    }

    private var unlockAccessibilityLabel: String {
        if let price = store.displayPrice {
            return String(localized: "Unlock SpaghettiTimer Pro for \(price)")
        }
        return String(localized: "Unlock SpaghettiTimer Pro")
    }

    private var restoreButton: some View {
        Button {
            Task {
                await store.restore()
                if store.isPro { dismiss() }
            }
        } label: {
            Text("Restore Purchase")
                .font(.system(size: bodySize - 1, weight: .medium))
                .foregroundStyle(Theme.lightText)
        }
        .buttonStyle(.plain)
        .disabled(store.purchaseInFlight)
        .frame(maxWidth: .infinity)
    }

    private var terms: some View {
        Text("Payment is charged to your Apple Account. Family Sharing enabled.")
            .font(.system(size: bodySize - 4))
            .foregroundStyle(Theme.disabledText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Preview

#Preview("Auto-restart") {
    PaywallView(store: .preview, trigger: .autoRestart)
}

#Preview("Pin limit") {
    PaywallView(store: .preview, trigger: .pinLimit)
}

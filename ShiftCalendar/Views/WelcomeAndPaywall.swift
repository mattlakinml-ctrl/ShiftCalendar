import SwiftUI

/// Shown every time the app opens, until the user ticks "Don't show this again".
struct WelcomeTipView: View {
    let onShowGuide: () -> Void

    @AppStorage("hideWelcomeTip") private var hideWelcomeTip = false
    @Environment(PurchaseManager.self) private var purchases
    @State private var dontShowAgain = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                    .padding(.top, 28)

                Text("Need a hand?")
                    .font(.title.bold())

                Text("Tap **Start** for a quick guide. You can find it again any time: tap the cog at the top right, then **How to use this app**.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !purchases.isUnlocked {
                    Text("Free for \(PurchaseManager.trialDays) days, then \(purchases.priceText) once to keep using it. No subscription, no ads.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    dontShowAgain.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                            .font(.title2)
                            .foregroundStyle(dontShowAgain ? Color.blue : Color.secondary)
                        Text("Don't show this again")
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                    onShowGuide()
                } label: {
                    Text("Start")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding()
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .accessibilityLabel("Close")
        }
        .presentationDetents([.large])
        .onDisappear {
            if dontShowAgain { hideWelcomeTip = true }
        }
    }
}

/// Shown once the free month is over and the app hasn't been bought.
struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchases

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "light.beacon.max.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .padding(.top, 40)

                Text("Your free month is up")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Hope it's been useful! Keep using Shift Calendar for a one-off \(purchases.priceText).")
                    .font(.title3)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Pay once. Yours forever.", systemImage: "checkmark.circle.fill")
                    Label("No subscription.", systemImage: "checkmark.circle.fill")
                    Label("No adverts. Ever.", systemImage: "checkmark.circle.fill")
                    Label("Your rota stays exactly as you left it.", systemImage: "checkmark.circle.fill")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .symbolRenderingMode(.multicolor)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                UnlockButtons()
            }
            .padding()
        }
        .interactiveDismissDisabled()
    }
}

/// Buy and Restore buttons, used on the paywall and in Settings.
struct UnlockButtons: View {
    @Environment(PurchaseManager.self) private var purchases

    var body: some View {
        VStack(spacing: 12) {
            Button {
                Task { await purchases.buy() }
            } label: {
                Group {
                    if purchases.isPurchasing {
                        ProgressView()
                    } else {
                        Text("Unlock for \(purchases.priceText)")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(purchases.isPurchasing)

            Button("Restore purchase") {
                Task { await purchases.restore() }
            }
            .font(.subheadline)

            if let message = purchases.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

import SwiftUI

/// Shown every time the app opens, until the user ticks "Don't show this again".
struct WelcomeTipView: View {
    let onShowGuide: () -> Void

    @AppStorage("hideWelcomeTip") private var hideWelcomeTip = false
    @State private var dontShowAgain = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .padding(.top, 28)

            Text("Need a hand?")
                .font(.title.bold())

            VStack(spacing: 8) {
                Text("If you get stuck, tap the cog at the top right")
                Image(systemName: "gearshape.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("then tap **How to use this app**.")
            }
            .font(.title3)
            .multilineTextAlignment(.center)

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

            VStack(spacing: 10) {
                Button {
                    close()
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                Button("Show me the guide now") {
                    close()
                    onShowGuide()
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }

    private func close() {
        if dontShowAgain { hideWelcomeTip = true }
        dismiss()
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

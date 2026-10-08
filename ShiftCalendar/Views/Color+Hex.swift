import SwiftUI
import UIKit

enum HexColor {
    static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0x8E8E93
        if s.count == 6, let parsed = UInt64(s, radix: 16) {
            value = parsed
        }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    /// True when black text reads better than white on this background (e.g. yellow).
    static func prefersDarkText(_ hex: String) -> Bool {
        let c = rgb(hex)
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b > 0.6
    }
}

extension Color {
    init(hex: String) {
        let c = HexColor.rgb(hex)
        self.init(red: c.r, green: c.g, blue: c.b)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }
}

extension ShiftType {
    var color: Color { Color(hex: colorHex) }
    var textColor: Color { HexColor.prefersDarkText(colorHex) ? .black : .white }
}

/// A small coloured tile with the shift's short code, used everywhere a shift is shown.
struct ShiftBadge: View {
    let type: ShiftType?
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.25)
            .fill(type?.color ?? Color(.tertiarySystemFill))
            .frame(width: size, height: size)
            .overlay {
                Text(type?.code ?? "–")
                    .font(.system(size: size * 0.38, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(2)
                    .foregroundStyle(type?.textColor ?? .secondary)
            }
    }
}

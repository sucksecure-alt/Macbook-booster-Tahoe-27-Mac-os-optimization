import SwiftUI

enum T {
    static let carbon     = Color(red: 0.07, green: 0.08, blue: 0.10)
    static let carbonMid  = Color(red: 0.11, green: 0.12, blue: 0.15)
    static let carbonLite = Color(red: 0.16, green: 0.17, blue: 0.21)
    static let boost      = Color(red: 1.00, green: 0.45, blue: 0.10)
    static let redline    = Color(red: 1.00, green: 0.20, blue: 0.22)
    static let amber      = Color(red: 1.00, green: 0.75, blue: 0.22)
    static let cool       = Color(red: 0.30, green: 0.85, blue: 0.92)
    static let lime       = Color(red: 0.55, green: 0.90, blue: 0.40)
    static let violet     = Color(red: 0.65, green: 0.55, blue: 0.95)
    static let textHi     = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let textDim    = Color(red: 0.52, green: 0.55, blue: 0.62)

    static var boostGradient: LinearGradient {
        LinearGradient(colors: [amber, boost, redline],
                       startPoint: .top, endPoint: .bottom)
    }
    static var bgGradient: LinearGradient {
        LinearGradient(colors: [carbon, carbonMid],
                       startPoint: .top, endPoint: .bottom)
    }
}

struct ImpactDots: View {
    let count: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(i < count ? T.boost : Color.white.opacity(0.12))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

struct RiskBadge: View {
    let risk: Risk
    var body: some View {
        Text(risk.rawValue)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(risk.color.opacity(0.15), in: Capsule())
            .foregroundStyle(risk.color)
    }
}

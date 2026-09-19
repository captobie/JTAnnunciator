import SwiftUI
import JTAnnunciatorCore

/// The "annunciator" this app is named for: a large, hard-to-miss banner for the most recent
/// wanted-station alert, distinct from the dense decode list below it. This — a genuinely
/// visual, glanceable alert, not just a log line — is the JTAlert-style behavior this app exists
/// to bring to macOS.
struct AlertBannerView: View {
    let alert: AlertEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: alert.alreadyWorked ? "checkmark.circle" : "bell.badge.fill")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.callsign)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ColorCoding.color(for: alert).opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ColorCoding.color(for: alert), lineWidth: 2)
        )
        .padding(.horizontal, 12)
    }

    private var subtitle: String {
        let badge = ColorCoding.badgeText(for: alert.reason)
        return alert.alreadyWorked ? "\(badge) · already worked" : badge
    }
}

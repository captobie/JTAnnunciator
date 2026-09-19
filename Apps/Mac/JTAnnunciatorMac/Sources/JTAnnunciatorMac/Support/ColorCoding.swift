import SwiftUI
import JTAnnunciatorCore

/// The visual language this whole app exists to provide (the thing JTAlert does well on Windows
/// and JT-Bridge doesn't attempt on Mac): color-coding decoded callsigns by why they matter.
enum ColorCoding {
    static func color(for event: AlertEvent) -> Color {
        if event.alreadyWorked {
            return .secondary
        }
        switch event.reason {
        case .wantedCallsign:
            return .red
        case .wantedDXCC:
            return .yellow
        }
    }

    static func badgeText(for reason: AlertReason) -> String {
        switch reason {
        case .wantedCallsign:
            return "WANTED CALL"
        case let .wantedDXCC(entityName, _):
            return "NEW DXCC · \(entityName)"
        }
    }

    /// "WORKED · 20M FT8" — the band and mode the contact matched.
    static func workedBadgeText(for info: WorkedInfo) -> String {
        let detail = (info.bands + info.modes).joined(separator: " ")
        return detail.isEmpty ? "WORKED" : "WORKED · " + detail
    }

    /// Tooltip detail: QSO count, modes and last-worked date.
    static func workedDescription(for info: WorkedInfo) -> String {
        var parts = ["\(info.callsign): worked \(info.qsoCount)×"]
        if !info.modes.isEmpty { parts.append(info.modes.joined(separator: ", ")) }
        if let last = info.lastWorked {
            parts.append("last " + last.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.joined(separator: " · ")
    }
}

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

    /// The lit lamp this decode's box should show, or `nil` when the box stays dark.
    /// Wanted stations light red (callsign) or amber (DXCC); any other CQ lights green.
    static func lamp(for entry: DecodeEntry) -> Lamp? {
        if let alert = entry.alert, !alert.alreadyWorked {
            switch alert.reason {
            case .wantedCallsign: return .red
            case .wantedDXCC: return .amber
            }
        }
        return MessageClassifier.isCQ(entry.decode.message) ? .green : nil
    }
}

/// Colors for one annunciator lamp: a translucent lens lit from behind, brightest at the
/// center (the bulb) and deeper toward the edges, with dark legend text.
struct Lamp {
    let center: Color
    let edge: Color
    let glow: Color
    let legend: Color

    static let green = Lamp(
        center: Color(red: 0.62, green: 1.00, blue: 0.55), edge: Color(red: 0.08, green: 0.62, blue: 0.20),
        glow: Color(red: 0.20, green: 0.95, blue: 0.30), legend: Color(red: 0.02, green: 0.16, blue: 0.04)
    )
    static let red = Lamp(
        center: Color(red: 1.00, green: 0.42, blue: 0.32), edge: Color(red: 0.80, green: 0.06, blue: 0.08),
        glow: Color(red: 1.00, green: 0.15, blue: 0.10), legend: Color(red: 0.20, green: 0.00, blue: 0.00)
    )
    static let amber = Lamp(
        center: Color(red: 1.00, green: 0.86, blue: 0.40), edge: Color(red: 0.95, green: 0.50, blue: 0.05),
        glow: Color(red: 1.00, green: 0.60, blue: 0.10), legend: Color(red: 0.20, green: 0.08, blue: 0.00)
    )
}

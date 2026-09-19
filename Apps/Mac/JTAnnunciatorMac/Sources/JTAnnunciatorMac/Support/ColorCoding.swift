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
}

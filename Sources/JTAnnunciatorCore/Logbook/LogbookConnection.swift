import Foundation

/// The logging programs this app can read "worked before" history from. Each program gets its
/// own connection entry (its own file and its own reader), so adding another logger later is a
/// new case here plus a reader, not a change to the connection model.
public enum LogbookKind: String, Codable, CaseIterable, Equatable {
    case macLoggerDX

    public var displayName: String {
        switch self {
        case .macLoggerDX: return "MacLoggerDX"
        }
    }

    /// Where this program keeps its log by default, relative to the user's home directory.
    /// `nil` when there's no well-known location.
    public var defaultRelativePath: String? {
        switch self {
        case .macLoggerDX: return "Documents/MLDX_Logs/MacLoggerDX.sql"
        }
    }
}

/// One configured logbook: which program, where its file is, and whether it's in use.
public struct LogbookConnection: Codable, Identifiable, Equatable {
    public var id: UUID
    public var kind: LogbookKind
    public var path: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), kind: LogbookKind, path: String, isEnabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.path = path
        self.isEnabled = isEnabled
    }
}

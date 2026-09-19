import Foundation

/// What a callbook knows about one operator. Every field but `callsign` is optional because
/// services (and QRZ non-subscriber accounts) return different subsets.
public struct CallbookRecord: Equatable, Sendable {
    public var callsign: String
    public var name: String?
    public var city: String?
    public var state: String?
    public var country: String?
    public var grid: String?

    public init(
        callsign: String, name: String? = nil, city: String? = nil,
        state: String? = nil, country: String? = nil, grid: String? = nil
    ) {
        self.callsign = callsign
        self.name = name
        self.city = city
        self.state = state
        self.country = country
        self.grid = grid
    }

    /// "Newington, CT, United States" — whichever parts the service supplied.
    public var location: String? {
        let parts = [city, state, country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

public enum CallbookError: LocalizedError, Equatable {
    /// The username/password were rejected.
    case authenticationFailed(String)
    /// The service answered with an error other than "not found" or an expired session.
    case service(String)
    case malformedResponse

    public var errorDescription: String? {
        switch self {
        case let .authenticationFailed(message), let .service(message): return message
        case .malformedResponse: return "Unexpected response from the callbook service."
        }
    }
}

public protocol CallbookProvider: Sendable {
    /// The record for `callsign`, or `nil` when the service has no such callsign.
    func lookup(callsign: String) async throws -> CallbookRecord?
}

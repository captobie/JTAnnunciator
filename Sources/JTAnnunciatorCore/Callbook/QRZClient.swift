import Foundation

/// Looks callsigns up through the QRZ.com XML Data service (requires a QRZ XML subscription for
/// full data). Logs in lazily, reuses the session key, and logs in again if QRZ expires it.
public actor QRZClient: CallbookProvider {
    public typealias Fetch = @Sendable (URL) async throws -> Data

    private static let endpoint = "https://xmldata.qrz.com/xml/current/"
    private static let agent = "JTAnnunciator"

    private let username: String
    private let password: String
    private let fetch: Fetch
    private var sessionKey: String?

    public init(username: String, password: String, fetch: @escaping Fetch = QRZClient.urlSessionFetch) {
        self.username = username
        self.password = password
        self.fetch = fetch
    }

    public static let urlSessionFetch: Fetch = { url in
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CallbookError.service("QRZ returned HTTP \(http.statusCode).")
        }
        return data
    }

    /// Signs in and returns the subscription expiry QRZ reports ("non-subscriber" when the
    /// account has no XML subscription). Throws `.authenticationFailed` on bad credentials.
    @discardableResult
    public func login() async throws -> String? {
        let response = try await request(["username": username, "password": password, "agent": Self.agent])
        guard let key = response.sessionKey else {
            let message = response.error ?? "QRZ sign-in failed."
            throw message.localizedCaseInsensitiveContains("password") || message.localizedCaseInsensitiveContains("username")
                ? CallbookError.authenticationFailed(message) : CallbookError.service(message)
        }
        sessionKey = key
        return response.subscriptionExpiry
    }

    public func lookup(callsign: String) async throws -> CallbookRecord? {
        if let record = try await lookupExact(callsign) { return record }
        // "W1AW/P", "VP8/G4ABC" etc. are usually filed under the operator's base call.
        let base = CallsignParser.baseCallsignForCountryLookup(callsign)
        return base == callsign ? nil : try await lookupExact(base)
    }

    private func lookupExact(_ callsign: String) async throws -> CallbookRecord? {
        for attempt in 0..<2 {
            if sessionKey == nil { try await login() }
            let response = try await request(["s": sessionKey ?? "", "callsign": callsign])
            if let record = response.record { return record }
            guard let error = response.error else { throw CallbookError.malformedResponse }
            if error.localizedCaseInsensitiveContains("not found") { return nil }
            if attempt == 0, error.localizedCaseInsensitiveContains("session") {
                sessionKey = nil
                continue
            }
            throw CallbookError.service(error)
        }
        throw CallbookError.malformedResponse
    }

    private func request(_ parameters: [String: String]) async throws -> QRZResponse {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let query = parameters.sorted { $0.key < $1.key }.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&")
        guard let url = URL(string: Self.endpoint + "?" + query) else { throw CallbookError.malformedResponse }
        return try QRZResponse.parse(try await fetch(url))
    }
}

/// The parts of a QRZ XML reply this app uses: the `Session` block and, for lookups, the
/// `Callsign` block.
struct QRZResponse: Equatable {
    var sessionKey: String?
    var error: String?
    var subscriptionExpiry: String?
    var record: CallbookRecord?

    static func parse(_ data: Data) throws -> QRZResponse {
        let collector = Collector()
        let parser = XMLParser(data: data)
        parser.delegate = collector
        guard parser.parse() else { throw CallbookError.malformedResponse }

        var response = QRZResponse()
        let session = collector.fields["Session", default: [:]]
        response.sessionKey = session["Key"]
        response.error = session["Error"]
        response.subscriptionExpiry = session["SubExp"]

        let callsign = collector.fields["Callsign", default: [:]]
        if let call = callsign["call"] {
            let name = [callsign["fname"], callsign["name"]].compactMap { $0 }.joined(separator: " ")
            response.record = CallbookRecord(
                callsign: call,
                name: name.isEmpty ? nil : name,
                city: callsign["addr2"],
                state: callsign["state"],
                country: callsign["country"],
                grid: callsign["grid"]
            )
        }
        return response
    }

    /// Gathers the text of each child of `Session` and `Callsign`, keyed by section then element.
    private final class Collector: NSObject, XMLParserDelegate {
        var fields: [String: [String: String]] = [:]
        private var section: String?
        private var element: String?
        private var text = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String]) {
            if elementName == "Session" || elementName == "Callsign" {
                section = elementName
            } else if section != nil {
                element = elementName
                text = ""
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if element != nil { text += string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?) {
            if elementName == "Session" || elementName == "Callsign" {
                section = nil
            } else if let section, elementName == element {
                let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { fields[section, default: [:]][elementName] = value }
                element = nil
            }
        }
    }
}

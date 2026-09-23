import Foundation

/// Reads QSOs from a [Wavelog](https://www.wavelog.org) instance's `get_contacts_adif` API
/// endpoint, using a read-only API key generated in Wavelog's own Settings → API Keys. Unlike
/// `MacLoggerDXReader`, Wavelog is a web service, not a local file: this talks over HTTP, and
/// supports incremental ("delta") pulls via `fetchfromid` so a repeat poll only downloads
/// contacts logged since the last one, rather than the whole log every time — the API docs
/// recommend this to avoid needlessly re-crawling a potentially large log.
///
/// Only a single station profile per connection is supported (`station_id` as a plain integer);
/// Wavelog's array form for pulling several station profiles in one call isn't used.
public enum WavelogReader {
    /// Sends a JSON POST `body` to `url` and returns the raw response body. Injectable so tests
    /// can stub the network, matching `QRZClient`'s `Fetch` pattern.
    public typealias Post = @Sendable (URL, Data) async throws -> Data

    public enum ReadError: Error, LocalizedError, Equatable {
        case invalidServerURL(String)
        case missingAPIKey
        case httpStatus(Int)
        case transport(String)
        case malformedResponse
        case api(String)

        public var errorDescription: String? {
            switch self {
            case let .invalidServerURL(url): return "Invalid Wavelog server address: \(url)"
            case .missingAPIKey: return "No Wavelog API key set."
            case let .httpStatus(code): return "Wavelog server returned HTTP \(code)."
            case let .transport(message): return "Couldn't reach Wavelog: \(message)"
            case .malformedResponse: return "Unexpected response from Wavelog."
            case let .api(message): return message
            }
        }
    }

    /// The `get_contacts_adif` JSON response shape: `adif` holds the QSOs as ADIF text (present
    /// on success), `message` a status string (the error detail on failure).
    private struct APIResponse: Decodable {
        var lastfetchedid: Int?
        var message: String?
        var adif: String?
    }

    public static let urlSessionPost: Post = { url, body in
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 20
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ReadError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ReadError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    /// Fetches QSOs for `connection`: every QSO on the first pull (`lastFetchedID == nil`), or
    /// only those logged since the last pull otherwise. Returns the QSOs found plus `connection`
    /// updated with the new `lastFetchedID`, for the caller to persist for the next poll.
    public static func fetch(connection: LogbookConnection, post: Post = urlSessionPost) async throws -> LogbookReadResult {
        let host = (connection.serverURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, let base = URL(string: host), base.scheme != nil, base.host != nil else {
            throw ReadError.invalidServerURL(connection.serverURL ?? "")
        }
        let apiKey = connection.apiKey ?? ""
        guard !apiKey.isEmpty else { throw ReadError.missingAPIKey }

        let isDelta = connection.lastFetchedID != nil
        let payload: [String: Any] = [
            "key": apiKey,
            "station_id": connection.stationID ?? 1,
            "fetchfromid": connection.lastFetchedID ?? 0,
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let endpoint = base.appendingPathComponent("index.php/api/get_contacts_adif")

        // Whatever `post` throws — a raw URLSession/network error from a test double, or
        // anything else — callers should only ever see a `ReadError` from this function.
        let data: Data
        do {
            data = try await post(endpoint, body)
        } catch let error as ReadError {
            throw error
        } catch {
            throw ReadError.transport(error.localizedDescription)
        }

        let decoded: APIResponse
        do {
            decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            throw ReadError.malformedResponse
        }
        guard let adif = decoded.adif else {
            throw ReadError.api(decoded.message ?? "Wavelog didn't return any QSO data.")
        }

        var updated = connection
        if let lastID = decoded.lastfetchedid {
            updated.lastFetchedID = lastID
        }
        return LogbookReadResult(qsos: ADIFParser.qsos(fromADIF: adif), isDelta: isDelta, updatedConnection: updated)
    }
}

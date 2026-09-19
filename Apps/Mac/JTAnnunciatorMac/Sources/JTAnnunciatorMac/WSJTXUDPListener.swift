import Foundation
import Network
import JTAnnunciatorCore

/// Listens on WSJT-X's UDP port (2237 by default — WSJT-X's own Settings → Reporting → "UDP
/// Server" address/port) and decodes every datagram that arrives.
///
/// Built on `Network.framework`'s `NWListener`: for UDP, each distinct remote endpoint that
/// sends us a datagram shows up via `newConnectionHandler` as its own "connection" (Network.
/// framework's abstraction over a UDP 4-tuple, not a real connection) — this is the standard
/// pattern for a `Network.framework`-based UDP receiver. Not build/run-verified in this session
/// (no macOS/Xcode toolchain available where this was written) — see the repo README's
/// validation-status note; this is the first thing to sanity-check against a real running
/// WSJT-X instance.
final class WSJTXUDPListener {
    var onMessage: ((WSJTXMessage) -> Void)?
    var onError: ((Swift.Error) -> Void)?

    enum ListenerError: Swift.Error {
        case invalidPort
    }

    private let port: UInt16
    private let queue = DispatchQueue(label: "com.jtannunciator.udp-listener")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    init(port: UInt16) {
        self.port = port
    }

    func start() {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            onError?(ListenerError.invalidPort)
            return
        }
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: nwPort)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case let .failed(error) = state {
                    self?.onError?(error)
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            onError?(error)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.connections.removeValue(forKey: key)
            default:
                break
            }
        }
        connection.start(queue: queue)
        receiveNext(on: connection)
    }

    private func receiveNext(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                do {
                    let message = try WSJTXMessageDecoder.decode(data)
                    self.onMessage?(message)
                } catch {
                    self.onError?(error)
                }
            }
            if let error {
                self.onError?(error)
                return
            }
            guard connection.state != .cancelled else { return }
            self.receiveNext(on: connection)
        }
    }
}

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
    /// IPv4 multicast group to join (e.g. "224.0.0.1"). Multicast lets several apps (loggers,
    /// JT-Bridge, this one) all receive WSJT-X's feed; plain unicast to a shared port only
    /// reaches one of them. `nil` or empty falls back to a plain unicast listener.
    private let multicastAddress: String?
    private var readSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.jtannunciator.udp-listener")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    init(port: UInt16, multicastAddress: String? = nil) {
        self.port = port
        let trimmed = multicastAddress?.trimmingCharacters(in: .whitespaces) ?? ""
        self.multicastAddress = trimmed.isEmpty ? nil : trimmed
    }

    func start() {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            onError?(ListenerError.invalidPort)
            return
        }
        if let multicastAddress {
            startMulticast(address: multicastAddress, port: nwPort)
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

    /// Uses a BSD socket rather than Network.framework: NWListener/NWConnectionGroup can't set
    /// `SO_REUSEPORT`, which macOS requires to share a UDP port with other WSJT-X listeners
    /// (loggers, JT-Bridge, ...) already bound to it.
    private func startMulticast(address: String, port: NWEndpoint.Port) {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return fail("socket()") }

        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &on, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.rawValue.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { close(fd); return fail("bind()") }

        guard inet_addr(address) != INADDR_NONE else { close(fd); return fail("invalid multicast address") }
        var joined = false
        // Join on the default interface and on loopback (same-machine WSJT-X may send via either).
        for iface in [INADDR_ANY, INADDR_LOOPBACK] {
            var mreq = ip_mreq(imr_multiaddr: in_addr(s_addr: inet_addr(address)),
                               imr_interface: in_addr(s_addr: iface.bigEndian))
            if setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, socklen_t(MemoryLayout<ip_mreq>.size)) == 0 {
                joined = true
            }
        }
        guard joined else { close(fd); return fail("joining multicast group \(address)") }

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 65535)
            let n = recv(fd, &buffer, buffer.count, 0)
            guard n > 0, let self else { return }
            do {
                self.onMessage?(try WSJTXMessageDecoder.decode(Data(buffer[0..<n])))
            } catch {
                self.onError?(error)
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        readSource = source
    }

    private func fail(_ what: String) {
        onError?(NSError(domain: NSPOSIXErrorDomain, code: Int(errno),
                         userInfo: [NSLocalizedDescriptionKey: "\(what) failed: \(String(cString: strerror(errno)))"]))
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
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

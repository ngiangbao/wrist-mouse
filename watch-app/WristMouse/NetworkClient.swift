import Foundation
import Network

/// Maintains one persistent TCP connection to the Linux listener and speaks
/// the newline-delimited JSON protocol described in linux-listener/README.md.
final class NetworkClient: ObservableObject {
    enum Status: Equatable {
        case disconnected
        case connecting
        case connected
        case authFailed
        case error(String)
    }

    @Published private(set) var status: Status = .disconnected

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "wristmouse.network")
    private var token: String = ""

    func connect(host: String, port: UInt16, token: String) {
        self.token = token
        disconnect()

        status = .connecting
        let params = NWParameters.tcp

        let conn = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 43117,
            using: params
        )
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.sendAuth()
            case .failed(let error):
                DispatchQueue.main.async { self.status = .error(error.localizedDescription) }
            case .cancelled:
                DispatchQueue.main.async { self.status = .disconnected }
            default:
                break
            }
        }

        conn.start(queue: queue)
        receiveLoop()
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    private func sendAuth() {
        send(["type": "auth", "token": token])
    }

    // MARK: - Outgoing messages

    func sendMove(dx: Double, dy: Double) {
        guard status == .connected else { return }
        send(["type": "move", "dx": dx, "dy": dy])
    }

    func sendClick(button: String = "left") {
        send(["type": "click", "button": button])
    }

    func sendDown(button: String = "left") {
        send(["type": "down", "button": button])
    }

    func sendUp(button: String = "left") {
        send(["type": "up", "button": button])
    }

    private func send(_ dict: [String: Any]) {
        guard let conn = connection else { return }
        guard var data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        data.append(0x0A) // newline
        conn.send(content: data, completion: .contentProcessed { _ in })
    }

    // MARK: - Incoming messages (auth ack, pong)

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.handleIncoming(data)
            }
            if error != nil || isComplete {
                DispatchQueue.main.async { self.status = .disconnected }
                return
            }
            self.receiveLoop()
        }
    }

    private func handleIncoming(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
            if let ok = obj["ok"] as? Bool {
                DispatchQueue.main.async { self.status = ok ? .connected : .authFailed }
            }
        }
    }
}

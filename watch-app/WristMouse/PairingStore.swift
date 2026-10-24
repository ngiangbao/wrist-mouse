import Foundation

/// Persists the last-used host/port/token in UserDefaults so the watch
/// reconnects automatically on next launch.
struct PairingStore {
    private static let hostKey = "wristmouse.host"
    private static let portKey = "wristmouse.port"
    private static let tokenKey = "wristmouse.token"

    static var host: String {
        get { UserDefaults.standard.string(forKey: hostKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: hostKey) }
    }

    static var port: UInt16 {
        get {
            let v = UserDefaults.standard.integer(forKey: portKey)
            return v == 0 ? 43117 : UInt16(v)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: portKey) }
    }

    static var token: String {
        get { UserDefaults.standard.string(forKey: tokenKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    static var isConfigured: Bool {
        !host.isEmpty && !token.isEmpty
    }
}

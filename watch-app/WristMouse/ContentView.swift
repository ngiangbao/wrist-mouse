import SwiftUI

struct ContentView: View {
    @StateObject private var client = NetworkClient()
    @State private var isPaired: Bool = PairingStore.isConfigured

    var body: some View {
        Group {
            if isPaired {
                TrackpadView(client: client, isPaired: $isPaired)
            } else {
                PairingView(isPaired: $isPaired)
            }
        }
        .onChange(of: isPaired) { _, newValue in
            if newValue {
                client.connect(host: PairingStore.host, port: PairingStore.port, token: PairingStore.token)
            } else {
                client.disconnect()
            }
        }
    }
}

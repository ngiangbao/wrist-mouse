import SwiftUI

/// First-run setup screen: enter the IP/port/token printed by
/// linux-listener/setup.sh on the Omarchy machine.
struct PairingView: View {
    @Binding var isPaired: Bool

    @State private var host: String = PairingStore.host
    @State private var portText: String = String(PairingStore.port)
    @State private var token: String = PairingStore.token

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pair with Omarchy")
                    .font(.headline)

                TextField("Host / IP", text: $host)
                TextField("Port", text: $portText)
                TextField("Token", text: $token)

                Button("Save & Connect") {
                    PairingStore.host = host
                    PairingStore.port = UInt16(portText) ?? 43117
                    PairingStore.token = token
                    isPaired = true
                }
                .disabled(host.isEmpty || token.isEmpty)
                .padding(.top, 4)

                Text("Run ./setup.sh on your Linux machine — it prints the host, port and token to enter here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

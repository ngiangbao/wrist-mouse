import SwiftUI

/// The whole watch screen acts as a relative trackpad:
///   - drag  -> move the cursor
///   - tap   -> left click
///   - Digital Crown -> scroll
struct TrackpadView: View {
    @ObservedObject var client: NetworkClient
    @Binding var isPaired: Bool

    @State private var lastTranslation: CGSize = .zero
    @State private var crownValue: Double = 0
    @State private var sensitivity: Double = 2.2

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = (value.translation.width - lastTranslation.width) * sensitivity
                let dy = (value.translation.height - lastTranslation.height) * sensitivity
                lastTranslation = value.translation
                client.sendMove(dx: dx, dy: dy)
            }
            .onEnded { _ in
                lastTranslation = .zero
            }
    }

    var body: some View {
        ZStack {
            statusColor.opacity(0.15).ignoresSafeArea()

            VStack(spacing: 6) {
                statusBadge
                Spacer()
                Text("drag to move\ntap to click")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Re-pair") { isPaired = false }
                    .font(.caption2)
            }
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(drag)
        .onTapGesture {
            client.sendClick(button: "left")
        }
        .focusable(true)
        .digitalCrownRotation($crownValue)
        .onChange(of: crownValue) { oldValue, newValue in
            let delta = newValue - oldValue
            // TODO: wire this up once the Linux listener implements "scroll"
            // (see linux-listener/README.md). Kept here so the gesture is
            // ready to go the moment that lands.
            _ = delta
        }
        .onAppear {
            client.connect(host: PairingStore.host, port: PairingStore.port, token: PairingStore.token)
        }
    }

    private var statusColor: Color {
        switch client.status {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .authFailed, .error: return .red
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(statusColor).frame(width: 6, height: 6)
            Text(statusText).font(.caption2)
        }
    }

    private var statusText: String {
        switch client.status {
        case .connected: return "Connected"
        case .connecting: return "Connecting…"
        case .disconnected: return "Disconnected"
        case .authFailed: return "Bad token"
        case .error(let msg): return msg
        }
    }
}

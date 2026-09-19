import SwiftUI
import JTAnnunciatorCore

struct AnnunciatorView: View {
    @ObservedObject var viewModel: AnnunciatorViewModel
    @State private var showingWantedLists = false

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider()
            ZStack(alignment: .top) {
                decodeList
                if let latest = viewModel.latestAlert {
                    AlertBannerView(alert: latest)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .id(latest.id)
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Wanted Lists…") { showingWantedLists = true }
            }
        }
        .sheet(isPresented: $showingWantedLists) {
            WantedListsView(viewModel: viewModel)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 16) {
            Label(
                viewModel.isListening ? "Listening" : "Stopped",
                systemImage: viewModel.isListening ? "dot.radiowaves.left.and.right" : "pause.circle"
            )
            .foregroundStyle(viewModel.isListening ? .green : .secondary)

            Text("\(viewModel.stationsHeard) decoded")
                .foregroundStyle(.secondary)

            Text("DXCC entities loaded: \(viewModel.dxccDatabaseEntityCount)")
                .foregroundStyle(.secondary)

            if let error = viewModel.lastErrorDescription {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Spacer()
        }
        .font(.callout)
        .padding(8)
    }

    private var decodeList: some View {
        List(viewModel.recentDecodes.indices, id: \.self) { index in
            let decode = viewModel.recentDecodes[index]
            DecodeRow(decode: decode, matchingAlert: alert(for: decode))
        }
        .listStyle(.plain)
    }

    private func alert(for decode: WSJTXDecode) -> AlertEvent? {
        viewModel.alerts.first { $0.decode == decode }
    }
}

private struct DecodeRow: View {
    let decode: WSJTXDecode
    let matchingAlert: AlertEvent?

    var body: some View {
        HStack(spacing: 12) {
            Text(timeLabel)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            Text(String(format: "%+3d", decode.snr))
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)

            Text(decode.message)
                .fontWeight(matchingAlert == nil ? .regular : .semibold)

            Spacer()

            if let matchingAlert {
                Text(ColorCoding.badgeText(for: matchingAlert.reason))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ColorCoding.color(for: matchingAlert).opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(matchingAlert.map(ColorCoding.color) ?? .primary)
        .padding(.vertical, 2)
    }

    private var timeLabel: String {
        guard let millis = decode.timeMillisSinceMidnightUTC else { return "--:--:--" }
        let totalSeconds = millis / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

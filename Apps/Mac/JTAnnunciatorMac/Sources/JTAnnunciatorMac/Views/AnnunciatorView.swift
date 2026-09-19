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
                        .onTapGesture(count: 2) { viewModel.reply(to: latest.decode) }
                        .help("Double-click to reply in WSJT-X")
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

            if viewModel.logbookCallsignCount > 0 {
                Text("Log: \(viewModel.logbookCallsignCount.formatted()) stations")
                    .foregroundStyle(.secondary)
            }

            if let status = viewModel.replyStatus {
                Label(status, systemImage: "paperplane")
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }

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
        VSplitView {
            DecodePane(title: "All Decodes", entries: viewModel.entries, emptyText: "Waiting for decodes…", onReply: viewModel.reply)
                .frame(minHeight: 120)
            HSplitView {
                DecodePane(
                    title: viewModel.myCallsign.isEmpty ? "Calling Me" : "Calling \(viewModel.myCallsign)",
                    entries: viewModel.callingMeEntries,
                    emptyText: viewModel.myCallsign.isEmpty ? "Set your callsign in Settings" : "No one calling you",
                    onReply: viewModel.reply
                )
                .frame(minWidth: 200)
                DecodePane(title: "CQ", entries: viewModel.cqEntries, emptyText: "No CQs", onReply: viewModel.reply)
                    .frame(minWidth: 200)
            }
            .frame(minHeight: 120)
        }
    }
}

/// A titled, scrolling grid of decode boxes.
private struct DecodePane: View {
    let title: String
    let entries: [DecodeEntry]
    let emptyText: String
    let onReply: (WSJTXDecode) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Text("\(entries.count)").foregroundStyle(.secondary).monospacedDigit()
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 10)], spacing: 10) {
                    ForEach(entries) { entry in
                        DecodeBox(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { onReply(entry.decode) }
                    }
                }
                .padding(12)
            }
            .overlay {
                if entries.isEmpty {
                    Text(emptyText).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A single decode in a rectangular box; alert-matching decodes get a colored fill and border.
private struct DecodeBox: View {
    let entry: DecodeEntry

    private var decode: WSJTXDecode { entry.decode }
    private var tint: Color? { entry.alert.map(ColorCoding.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(decode.message)
                .font(.system(.body, design: .monospaced).weight(entry.alert == nil ? .regular : .bold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Text(String(format: "%+d dB", decode.snr))
                Text(String(format: "DT %.1f", decode.deltaTimeSeconds))
                Text("\(decode.deltaFrequencyHz) Hz")
                Spacer(minLength: 0)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            if let alert = entry.alert {
                Text(ColorCoding.badgeText(for: alert.reason))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint ?? .primary)
            }

            if let worked = entry.worked {
                Text(ColorCoding.workedBadgeText(for: worked))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .background((tint ?? Color.secondary).opacity(tint == nil ? 0.08 : 0.2), in: RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(tint ?? Color.secondary.opacity(0.35), lineWidth: tint == nil ? 1 : 2)
        )
        .help(entry.worked.map { ColorCoding.workedDescription(for: $0) + "\nDouble-click to reply in WSJT-X" }
            ?? "Double-click to reply in WSJT-X")
    }
}

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

            if let problem = viewModel.callbookWarning ?? viewModel.callbookError {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
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
            DecodePane(title: "All Decodes", entries: viewModel.entries, callbook: viewModel.callbookRecords, emptyText: "Waiting for decodes…", onReply: viewModel.reply)
                .frame(minHeight: 120)
            HSplitView {
                DecodePane(
                    title: viewModel.myCallsign.isEmpty ? "Calling Me" : "Calling \(viewModel.myCallsign)",
                    entries: viewModel.callingMeEntries,
                    callbook: viewModel.callbookRecords,
                    emptyText: viewModel.myCallsign.isEmpty ? "Set your callsign in Settings" : "No one calling you",
                    clearActions: ClearActions(one: viewModel.clearCallingMe, all: viewModel.clearAllCallingMe),
                    onReply: viewModel.reply
                )
                .frame(minWidth: 200)
                DecodePane(title: "CQ", entries: viewModel.cqEntries, callbook: viewModel.callbookRecords, emptyText: "No CQs", onReply: viewModel.reply)
                    .frame(minWidth: 200)
            }
            .frame(minHeight: 120)
        }
    }
}

/// Manual-clear hooks for a pane whose decodes persist across cycles.
private struct ClearActions {
    let one: (DecodeEntry) -> Void
    let all: () -> Void
}

/// A titled, scrolling grid of decode boxes. Panes given `clearActions` keep their decodes until
/// cleared by the user (right-click a box, or "Clear All"), and show each decode's time.
private struct DecodePane: View {
    let title: String
    let entries: [DecodeEntry]
    let callbook: [String: CallbookRecord]
    let emptyText: String
    var clearActions: ClearActions?
    let onReply: (WSJTXDecode) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Text("\(entries.count)").foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                if let clearActions {
                    Button("Clear All", action: clearActions.all)
                        .controlSize(.small)
                        .disabled(entries.isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 10)], spacing: 10) {
                    ForEach(entries) { entry in
                        DecodeBox(entry: entry, record: entry.callsign.flatMap { callbook[$0] })
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { onReply(entry.decode) }
                            .contextMenu {
                                if let clearActions {
                                    Button("Clear") { clearActions.one(entry) }
                                }
                            }
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

/// A single decode in a rectangular box: the calling station's callsign and its state/province
/// (or country), centered.
/// Everything else about the decode is in the hover tooltip. Alert-matching decodes get a
/// colored fill and border.
private struct DecodeBox: View {
    let entry: DecodeEntry
    let record: CallbookRecord?

    private var decode: WSJTXDecode { entry.decode }
    private var tint: Color? { entry.alert.map(ColorCoding.color) }

    var body: some View {
        VStack(spacing: 2) {
            Text(entry.callsign ?? decode.message)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(entry.worked == nil ? .primary : .tertiary)
            if let region {
                Text(region)
                    .font(.callout)
                    .foregroundStyle(entry.worked == nil ? .secondary : .tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .center)
        .padding(8)
        .background((tint ?? Color.secondary).opacity(tint == nil ? 0.08 : 0.2), in: RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(tint ?? Color.secondary.opacity(0.35), lineWidth: tint == nil ? 1 : 2)
        )
        .help(hoverText)
    }

    /// Second line: the state or province when the callbook supplied one, otherwise the country.
    private var region: String? {
        if let state = record?.state, !state.isEmpty {
            return RegionNames.fullName(forState: state, country: record?.country)
        }
        return entry.country
    }

    /// All the detail for this decode, shown on hover.
    private var hoverText: String {
        var lines = [decode.message]
        var detail: [String] = []
        if let millis = decode.timeMillisSinceMidnightUTC {
            let seconds = millis / 1000
            detail.append(String(format: "%02d:%02d:%02d UTC", seconds / 3600, (seconds % 3600) / 60, seconds % 60))
        }
        detail.append(String(format: "%+d dB", decode.snr))
        detail.append(String(format: "DT %.1f", decode.deltaTimeSeconds))
        detail.append("\(decode.deltaFrequencyHz) Hz")
        lines.append(detail.joined(separator: "  "))
        if let country = entry.country {
            lines.append(country)
        }
        if let record {
            let detail = [record.name, record.location, record.grid].compactMap { $0 }.joined(separator: " · ")
            if !detail.isEmpty { lines.append(detail) }
        }
        if let alert = entry.alert {
            lines.append(ColorCoding.badgeText(for: alert.reason))
        }
        if let worked = entry.worked {
            lines.append(ColorCoding.workedBadgeText(for: worked))
            lines.append(ColorCoding.workedDescription(for: worked))
        }
        lines.append("Double-click to reply in WSJT-X")
        return lines.joined(separator: "\n")
    }
}

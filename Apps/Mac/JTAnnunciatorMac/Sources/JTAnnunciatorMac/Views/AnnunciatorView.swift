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
            DecodePane(title: "All Decodes", entries: viewModel.entries, callbook: viewModel.callbookRecords, newFlag: viewModel.newFlag, emptyText: "Waiting for decodes…", onReply: viewModel.reply)
                .frame(minHeight: 120)
            HSplitView {
                DecodePane(
                    title: viewModel.myCallsign.isEmpty ? "Calling Me" : "Calling \(viewModel.myCallsign)",
                    entries: viewModel.callingMeEntries,
                    callbook: viewModel.callbookRecords, newFlag: viewModel.newFlag,
                    emptyText: viewModel.myCallsign.isEmpty ? "Set your callsign in Settings" : "No one calling you",
                    clearActions: ClearActions(one: viewModel.clearCallingMe, all: viewModel.clearAllCallingMe),
                    onReply: viewModel.reply
                )
                .frame(minWidth: 200)
                DecodePane(title: "CQ", entries: viewModel.cqEntries, callbook: viewModel.callbookRecords, newFlag: viewModel.newFlag, emptyText: "No CQs", onReply: viewModel.reply)
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
    let newFlag: (DecodeEntry, CallbookRecord?) -> NewFlag?
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 210), spacing: 10)], spacing: 10) {
                    ForEach(entries) { entry in
                        let record = entry.callsign.flatMap { callbook[$0] }
                        DecodeBox(entry: entry, record: record, newFlag: newFlag(entry, record))
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
/// Everything else about the decode is in the hover tooltip. CQ callers and wanted stations are
/// drawn as lit annunciator lamps (see `LampLens`).
private struct DecodeBox: View {
    let entry: DecodeEntry
    let record: CallbookRecord?
    let newFlag: NewFlag?

    private var decode: WSJTXDecode { entry.decode }
    private var lamp: Lamp? { ColorCoding.lamp(for: entry, newFlag: newFlag) }
    private var worked: Bool { entry.worked != nil }

    var body: some View {
        VStack(spacing: 2) {
            Text(entry.callsign ?? decode.message)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(lamp.map { AnyShapeStyle($0.legend.opacity(worked ? 0.45 : 1)) }
                    ?? AnyShapeStyle(worked ? .tertiary : .primary))
            if let region {
                Text(region)
                    .font(.callout)
                    .foregroundStyle(lamp.map { AnyShapeStyle($0.legend.opacity(worked ? 0.4 : 0.8)) }
                        ?? AnyShapeStyle(worked ? .tertiary : .secondary))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .center)
        .padding(8)
        .background { boxBackground }
        .help(hoverText)
    }

    @ViewBuilder
    private var boxBackground: some View {
        if let lamp {
            LampLens(lamp: lamp)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1))
        }
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
        if entry.callingMe {
            lines.append("CALLING YOU")
        }
        if let alert = entry.alert {
            lines.append(ColorCoding.badgeText(for: alert.reason))
        }
        if let newFlag {
            let onBandMode = [entry.band, entry.mode].compactMap { $0 }.joined(separator: " ")
            switch newFlag {
            case let .country(name): lines.append("NEW COUNTRY · \(name) on \(onBandMode)")
            case let .state(name): lines.append("NEW STATE · \(name) on \(onBandMode)")
            case let .wantedState(name): lines.append("WANTED STATE · \(name) on \(onBandMode)")
            }
        }
        if let worked = entry.worked {
            lines.append(ColorCoding.workedBadgeText(for: worked))
            lines.append(ColorCoding.workedDescription(for: worked))
        }
        lines.append("Double-click to reply in WSJT-X")
        return lines.joined(separator: "\n")
    }
}

/// An annunciator-panel lamp: a dark bezel around a translucent lens lit from behind, brightest
/// at the center where the "bulb" is, with a soft glow spilling past the bezel.
struct LampLens: View {
    let lamp: Lamp
    private let shape = RoundedRectangle(cornerRadius: 4)

    var body: some View {
        shape
            .fill(RadialGradient(colors: [lamp.center, lamp.edge], center: .center, startRadius: 4, endRadius: 115))
            .overlay {
                // Lens sheen: light catching the upper half of the plastic.
                shape.fill(LinearGradient(
                    colors: [.white.opacity(0.22), .white.opacity(0)], startPoint: .top, endPoint: .center
                ))
            }
            .overlay {
                // Recessed look: shadow falling inward from the bezel.
                shape.stroke(Color.black.opacity(0.45), lineWidth: 8)
                    .blur(radius: 4)
                    .clipShape(shape)
            }
            .overlay { shape.strokeBorder(Color(white: 0.08), lineWidth: 3) }
            .shadow(color: lamp.glow.opacity(0.55), radius: 9)
    }
}

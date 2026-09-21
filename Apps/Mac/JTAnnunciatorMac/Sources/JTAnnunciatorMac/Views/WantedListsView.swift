import SwiftUI
import JTAnnunciatorCore

struct WantedListsView: View {
    @ObservedObject var viewModel: AnnunciatorViewModel
    @Environment(\.dismiss) private var dismiss

    /// Edited copy of the list; only written to the view model on Save.
    @State private var draft = WantedList()
    @State private var newCallsign = ""
    @State private var newDXCCPrefix = ""
    @State private var newState = ""
    @State private var stateError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wanted Lists")
                .font(.title2.bold())

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    groups
                }
                .padding(.trailing, 12)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    viewModel.wantedList = draft
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear { draft = viewModel.wantedList }
        .padding(20)
        .frame(width: 440, height: 480)
    }

    @ViewBuilder
    private var groups: some View {
            GroupBox("Wanted Callsigns") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Callsign, e.g. K1ABC", text: $newCallsign)
                            .onSubmit(addCallsign)
                        Button("Add", action: addCallsign)
                            .disabled(newCallsign.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    entryList(items: sortedWantedCallsigns, remove: removeCallsign)
                }
                .padding(8)
            }

            GroupBox("Wanted DXCC Entities") {
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.dxccDatabaseEntityCount == 0 {
                        Text("No cty.dat file loaded yet — set one in Settings to enable DXCC alerts.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Primary prefix, e.g. 3D2 or JT", text: $newDXCCPrefix)
                            .onSubmit(addDXCCPrefix)
                        Button("Add", action: addDXCCPrefix)
                            .disabled(newDXCCPrefix.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Text("Enter the DXCC entity's primary prefix as it appears in your cty.dat file (a future version will let you search by country name instead).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    entryList(items: sortedWantedDXCCPrefixes, remove: removeDXCCPrefix)
                }
                .padding(8)
            }

            GroupBox("Wanted States") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("State or province, e.g. WY or Wyoming", text: $newState)
                            .onSubmit(addState)
                            .onChange(of: newState) { _ in stateError = nil }
                        Button("Add", action: addState)
                            .disabled(newState.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let stateError {
                        Text(stateError).font(.caption).foregroundStyle(.red)
                    } else {
                        Text("Matched using the state QRZ reports, so QRZ lookups must be on in Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    entryList(items: sortedWantedStates, remove: removeState)
                }
                .padding(8)
            }
    }

    private func entryList(items: [String], remove: @escaping (String) -> Void) -> some View {
        List {
            ForEach(items, id: \.self) { item in
                HStack {
                    Text(item)
                    Spacer()
                    Button {
                        remove(item)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .frame(height: 120)
    }

    private var sortedWantedCallsigns: [String] {
        draft.wantedCallsigns.sorted()
    }

    private var sortedWantedDXCCPrefixes: [String] {
        draft.wantedDXCCPrimaryPrefixes.sorted()
    }

    private var sortedWantedStates: [String] {
        draft.wantedStates.sorted()
    }

    private func addState() {
        let entry = newState.trimmingCharacters(in: .whitespaces)
        guard !entry.isEmpty else { return }
        guard let name = RegionNames.knownName(forState: entry) else {
            stateError = "\"\(entry)\" isn't a US state or Canadian province."
            return
        }
        draft.wantedStates.insert(name)
        newState = ""
    }

    private func removeState(_ name: String) {
        draft.wantedStates.remove(name)
    }

    private func addCallsign() {
        let call = newCallsign.trimmingCharacters(in: .whitespaces).uppercased()
        guard !call.isEmpty else { return }
        draft.wantedCallsigns.insert(call)
        newCallsign = ""
    }

    private func removeCallsign(_ call: String) {
        draft.wantedCallsigns.remove(call)
    }

    private func addDXCCPrefix() {
        let prefix = newDXCCPrefix.trimmingCharacters(in: .whitespaces)
        guard !prefix.isEmpty else { return }
        draft.wantedDXCCPrimaryPrefixes.insert(prefix)
        newDXCCPrefix = ""
    }

    private func removeDXCCPrefix(_ prefix: String) {
        draft.wantedDXCCPrimaryPrefixes.remove(prefix)
    }
}

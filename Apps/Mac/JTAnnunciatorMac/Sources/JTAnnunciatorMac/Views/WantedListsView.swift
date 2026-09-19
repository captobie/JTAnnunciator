import SwiftUI
import JTAnnunciatorCore

struct WantedListsView: View {
    @ObservedObject var viewModel: AnnunciatorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newCallsign = ""
    @State private var newDXCCPrefix = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wanted Lists")
                .font(.title2.bold())

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

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 460)
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
        viewModel.wantedList.wantedCallsigns.sorted()
    }

    private var sortedWantedDXCCPrefixes: [String] {
        viewModel.wantedList.wantedDXCCPrimaryPrefixes.sorted()
    }

    private func addCallsign() {
        let call = newCallsign.trimmingCharacters(in: .whitespaces).uppercased()
        guard !call.isEmpty else { return }
        viewModel.wantedList.wantedCallsigns.insert(call)
        newCallsign = ""
    }

    private func removeCallsign(_ call: String) {
        viewModel.wantedList.wantedCallsigns.remove(call)
    }

    private func addDXCCPrefix() {
        let prefix = newDXCCPrefix.trimmingCharacters(in: .whitespaces)
        guard !prefix.isEmpty else { return }
        viewModel.wantedList.wantedDXCCPrimaryPrefixes.insert(prefix)
        newDXCCPrefix = ""
    }

    private func removeDXCCPrefix(_ prefix: String) {
        viewModel.wantedList.wantedDXCCPrimaryPrefixes.remove(prefix)
    }
}

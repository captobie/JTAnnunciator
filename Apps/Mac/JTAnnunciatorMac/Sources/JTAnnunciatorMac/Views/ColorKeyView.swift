import SwiftUI
import AppKit

/// Explains what each lamp color on the decode boxes means. Shown in a floating window from
/// View → Color Key. Rows are in the same priority order `ColorCoding.lamp(for:newFlag:)` uses.
struct ColorKeyView: View {
    private struct Row: Identifiable {
        let id: String
        let lamp: Lamp?
        let title: String
        let detail: String
    }

    private let rows: [Row] = [
        Row(id: "red", lamp: .red, title: "Calling you",
            detail: "The message is addressed to your callsign."),
        Row(id: "yellow", lamp: .yellow, title: "Wanted",
            detail: "On your wanted callsign, DXCC or state lists, and not yet worked."),
        Row(id: "blue", lamp: .blue, title: "Worked before",
            detail: "Already in your log on the current band and mode. The text is dimmed."),
        Row(id: "amber", lamp: .amber, title: "New country or state",
            detail: "A country, US state or Canadian province you haven't worked on the current band and mode."),
        Row(id: "green", lamp: .green, title: "CQ",
            detail: "Calling CQ, and none of the above."),
        Row(id: "gray", lamp: nil, title: "Other",
            detail: "Any other decode."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(rows) { row in
                HStack(spacing: 16) {
                    sample(for: row.lamp)
                        .frame(width: 120, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title).font(.headline)
                        Text(row.detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
            Divider()
            Text("When several apply, the one nearest the top of this list wins.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 460)
        .background(FloatingWindow())
    }

    /// A miniature decode box in the given lamp color (or the unlit gray box).
    @ViewBuilder
    private func sample(for lamp: Lamp?) -> some View {
        ZStack {
            if let lamp {
                LampLens(lamp: lamp)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1))
            }
            VStack(spacing: 2) {
                Text("K1ABC")
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .foregroundStyle(lamp.map { AnyShapeStyle($0.legend) } ?? AnyShapeStyle(.primary))
                Text("Ohio")
                    .font(.caption)
                    .foregroundStyle(lamp.map { AnyShapeStyle($0.legend.opacity(0.8)) } ?? AnyShapeStyle(.secondary))
            }
        }
    }
}

/// Keeps the hosting window above other windows, even while another app is active, so the key
/// can stay visible next to the decode display.
private struct FloatingWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.level = .floating
            window.hidesOnDeactivate = false
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// The View → Color Key menu item.
struct ColorKeyCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Color Key") { openWindow(id: ColorKeyView.windowID) }
    }
}

extension ColorKeyView {
    static let windowID = "color-key"
}

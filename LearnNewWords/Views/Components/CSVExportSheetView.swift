import SwiftUI
import AppKit

/// Identifiable wrapper so .sheet(item:) delivers the CSV string with the presentation trigger.
struct CSVExportData: Identifiable {
    let id = UUID()
    let csv: String
}

/// Modal sheet displaying exported words in CSV format with a copy-to-clipboard button.
struct CSVExportSheetView: View {
    let csv: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            csvContent
            Divider()
            footerButtons
        }
        .frame(width: 360, height: 340)
    }

    private var header: some View {
        HStack {
            Label("Export CSV", systemImage: "doc.text")
                .font(.headline)
            Spacer()
            Text("\(csv.components(separatedBy: "\n").count) words")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }

    private var csvContent: some View {
        ScrollView {
            Text(csv)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
    }

    private var footerButtons: some View {
        HStack {
            Button(copied ? "Copied!" : "Copy All") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(csv, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            }
            .buttonStyle(.borderedProminent)
            .tint(copied ? .green : .accentColor)

            Spacer()

            Button("Done") { dismiss() }
        }
        .padding(14)
    }
}

import SwiftUI
import UniformTypeIdentifiers
import VideoConverterCore

struct ContentView: View {
    @EnvironmentObject private var viewModel: ConverterViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            DropTargetView()
            conversionList
        }
        .padding()
        .frame(minWidth: 600, minHeight: 420)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.pickFilesAndConvert) {
                    Label("Select Files", systemImage: "folder")
                }
                .disabled(viewModel.isProcessing)
            }
        }
        .alert("Conversion Failed", isPresented: Binding(get: {
            viewModel.lastError != nil
        }, set: { isPresented in
            if !isPresented {
                viewModel.lastError = nil
            }
        })) {
            Button("OK", role: .cancel) { viewModel.lastError = nil }
        } message: {
            Text(viewModel.lastError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Video Converter")
                .font(.largeTitle)
                .bold()
            Text("Drop .mov files below or pick them from Finder. They will be exported using AVFoundation so you don't need third-party codecs.")
                .foregroundColor(.secondary)
            HStack {
                Text("Output format:")
                Picker("Output format", selection: $viewModel.selectedFormat) {
                    ForEach(VideoFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var conversionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.conversions.isEmpty {
                Text("Conversions will appear here with progress and destination paths.")
                    .foregroundColor(.secondary)
            } else {
                Table(viewModel.conversions) {
                    TableColumn("Source") { item in
                        Text(item.sourceURL.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    TableColumn("Status") { item in
                        statusView(for: item)
                    }
                    TableColumn("Destination") { item in
                        if let destination = item.destinationURL {
                            Link(destination.lastPathComponent, destination: destination)
                        } else if item.state == .running {
                            ProgressView(value: item.progress)
                                .frame(width: 120)
                        } else {
                            Text(item.errorDescription ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func statusView(for item: ConversionSummary) -> some View {
        switch item.state {
        case .pending:
            Label("Pending", systemImage: "clock")
        case .running:
            HStack {
                ProgressView(value: item.progress)
                Text("\(Int(item.progress * 100))%")
            }
        case .succeeded:
            Label("Complete", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Label("Failed", systemImage: "xmark.octagon.fill")
                .foregroundColor(.red)
        }
    }
}

private struct DropTargetView: View {
    @EnvironmentObject private var viewModel: ConverterViewModel
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [6]))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                )
            VStack(spacing: 12) {
                Image(systemName: "film")
                    .font(.system(size: 48))
                Text("Drop video files here")
                    .font(.title3)
                Text("You can drag files directly from Finder. Multiple files are supported.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            viewModel.handleDroppedItems(providers)
            return true
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ConverterViewModel())
}

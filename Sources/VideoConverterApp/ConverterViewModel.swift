import Foundation
import Combine
import AppKit
import VideoConverterCore

@MainActor
final class ConverterViewModel: ObservableObject {
    @Published var conversions: [ConversionSummary] = []
    @Published var selectedFormat: VideoFormat = .mp4
    @Published var isProcessing: Bool = false
    @Published var lastError: String?

    private let service = VideoConversionService()

    func handleDroppedItems(_ providers: [NSItemProvider]) {
        Task {
            let urls = await extractFileURLs(from: providers)
            await convert(urls: urls)
        }
    }

    func pickFilesAndConvert() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mov", "mp4", "m4v"]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.begin { [weak self] response in
            guard response == .OK, let self else { return }
            Task { await self.convert(urls: panel.urls) }
        }
    }

    func convert(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }

        for url in urls {
            var summary = ConversionSummary(sourceURL: url, format: selectedFormat)
            summary.state = .running
            summary.startedAt = Date()
            conversions.insert(summary, at: 0)

            do {
                let destination = try await service.convert(fileAt: url, to: selectedFormat) { [weak self] progress in
                    Task { @MainActor in
                        guard let index = self?.conversions.firstIndex(where: { $0.id == summary.id }) else { return }
                        self?.conversions[index].progress = progress
                    }
                }
                if let index = conversions.firstIndex(where: { $0.id == summary.id }) {
                    conversions[index].destinationURL = destination
                    conversions[index].finishedAt = Date()
                    conversions[index].progress = 1
                    conversions[index].state = .succeeded
                }
            } catch {
                if let index = conversions.firstIndex(where: { $0.id == summary.id }) {
                    conversions[index].finishedAt = Date()
                    conversions[index].state = .failed
                    conversions[index].errorDescription = error.localizedDescription
                }
                lastError = error.localizedDescription
            }
        }
    }

    private func extractFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        await withTaskGroup(of: URL?.self) { group in
            var urls: [URL] = []
            for provider in providers where provider.hasItemConformingToTypeIdentifier("public.file-url") {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                            if let url = item as? URL {
                                continuation.resume(returning: url)
                            } else if
                                let data = item as? Data,
                                let string = String(data: data, encoding: .utf8),
                                let url = URL(string: string)
                            {
                                continuation.resume(returning: url)
                            } else {
                                continuation.resume(returning: nil)
                            }
                        }
                    }
                }
            }

            for await url in group {
                if let url {
                    urls.append(url)
                }
            }

            return urls
        }
    }
}

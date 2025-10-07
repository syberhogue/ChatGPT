import Foundation
import AVFoundation

public struct ConversionSummary: Identifiable, Hashable, Codable {
    public enum State: String, Codable {
        case pending
        case running
        case succeeded
        case failed
    }

    public let id: UUID
    public let sourceURL: URL
    public var destinationURL: URL?
    public var format: VideoFormat
    public var startedAt: Date?
    public var finishedAt: Date?
    public var progress: Double
    public var state: State
    public var errorDescription: String?

    public init(id: UUID = UUID(), sourceURL: URL, format: VideoFormat) {
        self.id = id
        self.sourceURL = sourceURL
        self.format = format
        self.progress = 0
        self.state = .pending
    }
}

public actor VideoConversionService {
    public init() {}

    public func convert(
        fileAt url: URL,
        to format: VideoFormat,
        destinationFolder: URL? = nil,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        let asset = AVAsset(url: url)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: format.exportPreset) else {
            throw VideoConversionError.exportSessionCreationFailed
        }

        let outputDirectory = destinationFolder ?? url.deletingLastPathComponent()
        let baseFilename = url.deletingPathExtension().lastPathComponent
        let destinationURL = uniqueDestinationURL(
            directory: outputDirectory,
            baseName: baseFilename,
            fileExtension: format.fileExtension
        )

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            throw VideoConversionError.fileAlreadyExists(destinationURL)
        }

        exportSession.outputURL = destinationURL
        if format == .mp4 {
            exportSession.outputFileType = .mp4
        } else if format == .m4v {
            exportSession.outputFileType = .m4v
        } else {
            exportSession.outputFileType = .mov
        }
        exportSession.shouldOptimizeForNetworkUse = true

        try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: destinationURL)
                case .failed:
                    continuation.resume(throwing: VideoConversionError.exportFailed(exportSession.error))
                case .cancelled:
                    continuation.resume(throwing: VideoConversionError.exportCancelled)
                default:
                    continuation.resume(throwing: VideoConversionError.exportFailed(exportSession.error))
                }
            }

            Task.detached { [weak exportSession] in
                while let exportSession, exportSession.status == .exporting {
                    progressHandler(Double(exportSession.progress))
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        }

        return destinationURL
    }

    private func uniqueDestinationURL(directory: URL, baseName: String, fileExtension: String) -> URL {
        var candidate = directory.appendingPathComponent("\(baseName).\(fileExtension)")
        var suffix = 1
        let fileManager = FileManager.default
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-\(suffix).\(fileExtension)")
            suffix += 1
        }
        return candidate
    }
}

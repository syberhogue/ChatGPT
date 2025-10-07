import Foundation
import AVFoundation

public enum VideoFormat: String, CaseIterable, Identifiable, Codable {
    case mp4
    case mov
    case m4v
    case presetHEVC

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mp4:
            return "H.264 (.mp4)"
        case .mov:
            return "QuickTime (.mov)"
        case .m4v:
            return "H.264 (.m4v)"
        case .presetHEVC:
            return "HEVC (.mov)"
        }
    }

    public var fileExtension: String {
        switch self {
        case .mp4:
            return "mp4"
        case .mov, .presetHEVC:
            return "mov"
        case .m4v:
            return "m4v"
        }
    }

    public var exportPreset: String {
        switch self {
        case .mp4:
            return AVAssetExportPresetHighestQuality
        case .mov:
            return AVAssetExportPresetPassthrough
        case .m4v:
            return AVAssetExportPreset1920x1080
        case .presetHEVC:
            if #available(macOS 11.0, *) {
                return AVAssetExportPresetHEVCHighestQuality
            } else {
                return AVAssetExportPresetHighestQuality
            }
        }
    }
}

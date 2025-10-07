import Foundation

public enum VideoConversionError: Error, LocalizedError {
    case exportSessionCreationFailed
    case exportFailed(Error?)
    case exportCancelled
    case fileAlreadyExists(URL)

    public var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Failed to create an export session for the selected file."
        case .exportFailed(let error):
            if let error {
                return "Conversion failed: \(error.localizedDescription)"
            }
            return "Conversion failed for an unknown reason."
        case .exportCancelled:
            return "The conversion was cancelled."
        case .fileAlreadyExists(let url):
            return "The destination file already exists at \(url.path)."
        }
    }
}

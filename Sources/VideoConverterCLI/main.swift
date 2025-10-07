import Foundation
import VideoConverterCore

enum CLIError: Error, LocalizedError {
    case missingInput

    var errorDescription: String? {
        switch self {
        case .missingInput:
            return "You must pass at least one input file (.mov) to convert."
        }
    }
}

@main
struct VideoConverterCLI {
    static func main() async {
        do {
            let (format, inputPaths) = try parseArguments()
            guard !inputPaths.isEmpty else {
                throw CLIError.missingInput
            }

            let service = VideoConversionService()
            for path in inputPaths {
                let url = URL(fileURLWithPath: path)
                do {
                    let destination = try await service.convert(fileAt: url, to: format, destinationFolder: nil) { progress in
                        let percentage = Int(progress * 100)
                        FileHandle.standardError.write("Converting \(url.lastPathComponent): \(percentage)%\n".data(using: .utf8)!)
                    }
                    print(destination.path)
                } catch {
                    FileHandle.standardError.write("Failed to convert \(url.path): \(error.localizedDescription)\n".data(using: .utf8)!)
                }
            }
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func parseArguments() throws -> (VideoFormat, [String]) {
        var args = CommandLine.arguments.dropFirst()
        var format: VideoFormat = .mp4
        var paths: [String] = []

        while let arg = args.first {
            args = args.dropFirst()
            if arg == "--format", let value = args.first {
                args = args.dropFirst()
                if let parsedFormat = VideoFormat(rawValue: value) {
                    format = parsedFormat
                } else {
                    throw NSError(
                        domain: "VideoConverterCLI",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Unknown format \(value). Available: \(VideoFormat.allCases.map(\.rawValue).joined(separator: ", "))"
                        ]
                    )
                }
            } else {
                paths.append(arg)
            }
        }

        return (format, paths)
    }
}

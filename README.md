# VideoConverter

A lightweight SwiftUI macOS application that uses AVFoundation to batch convert `.mov` videos into `.mp4`, `.m4v`, or `.mov` containers. The project also ships with a command-line companion so you can wire the converter into Finder Quick Actions for right-click conversions.

## Features

- Drag and drop videos from Finder onto the app window for instant conversion.
- Pick files using an `NSOpenPanel` if you prefer browsing.
- Choose between MP4 (H.264), M4V, QuickTime passthrough, or HEVC output.
- Monitor conversion progress for each file, including completion timestamps and destination links.
- Command line tool (`VideoConverterCLI`) for automation and Finder integration.

## Requirements

- macOS 13 Ventura or later.
- Xcode 15 or later to build the Swift Package as an app bundle.

## Building the macOS App

1. Open the project in Xcode:
   ```bash
   open Package.swift
   ```
2. When Xcode finishes resolving the package graph, select the **VideoConverterApp** scheme and the **My Mac** destination.
3. Build & run (`⌘R`). Xcode will create an `.app` bundle inside the Derived Data folder that you can keep in `/Applications`.

### Using the App

- Drag `.mov` files from Finder onto the drop zone to begin conversion.
- Use the toolbar button or the `Convert > Select Files…` menu to open files.
- The output files are written alongside the source videos. The destination column includes a clickable link to reveal the file in Finder.

## Finder Quick Action (Right-Click Conversion)

You can reuse the command-line target to create a Quick Action that appears in Finder's context menu. After building the `VideoConverterCLI` target, follow these steps:

1. Locate the CLI binary in Xcode's Derived Data folder. A quick way to retrieve the path is to run:
   ```bash
   swift build -c release --product VideoConverterCLI
   swift build -c release --show-bin-path
   ```
   The CLI executable will live inside the printed `.build/release` directory.
2. Open the **Shortcuts** app (or Automator if you prefer classic Quick Actions) and create a new **Quick Action**.
3. Configure it to receive files in Finder, then add a **Run Shell Script** action:
   ```bash
   /path/to/VideoConverterCLI --format mp4 "$@"
   ```
4. Save the Quick Action (for example, "Convert MOV to MP4"). It will immediately appear under Finder's right-click menu (`Quick Actions` submenu).

Because the CLI shares the same conversion core as the app, you get identical presets and export logic. You can also duplicate the Quick Action for different output formats by changing the `--format` flag.

## Drag & Drop Integration

The SwiftUI interface registers a drop target for `public.file-url` items, so you can drag one or many files directly from Finder. The ViewModel resolves security-scoped URLs, kicks off the conversion workflow on the main actor, and updates the table with live progress values using async/await.

## Testing Without macOS

The repository is designed for macOS and relies on AVFoundation and SwiftUI. Those frameworks are unavailable in this Linux-based environment, so automated tests are not included. Build and test the package on a Mac.

## Repository Layout

```
├── Package.swift
├── README.md
├── Sources
│   ├── VideoConverterApp
│   │   ├── ContentView.swift
│   │   ├── ConverterViewModel.swift
│   │   ├── Resources
│   │   │   └── Assets.xcassets
│   │   └── main.swift
│   ├── VideoConverterCLI
│   │   └── main.swift
│   └── VideoConverterCore
│       ├── VideoConversionError.swift
│       ├── VideoConversionService.swift
│       └── VideoFormat.swift
└── QuickActions
    └── README.md (instructions for manual Quick Action setup)
```

## License

MIT

# Finder Quick Action Templates

The Swift package includes a command-line converter (`VideoConverterCLI`) so you can create Finder Quick Actions for right-click conversions.

## Sample Shell Script

After you build the CLI target (`swift build -c release --product VideoConverterCLI`), the binary will be created inside `.build/release/VideoConverterCLI`. The following shell script wraps it with some simple logging and Finder notifications:

```bash
#!/bin/bash

set -euo pipefail

CLI_PATH="$HOME/Developer/VideoConverter/.build/release/VideoConverterCLI"
FORMAT="mp4"

for file in "$@"; do
  "$CLI_PATH" --format "$FORMAT" "$file"
done
```

You can save this as `~/Library/Application Support/VideoConverter/convert-mp4.sh` and mark it executable (`chmod +x`).

## Creating the Quick Action

1. Open **Shortcuts** or **Automator** and create a new **Quick Action**.
2. Configure it to receive files or folders in Finder.
3. Add a **Run Shell Script** step and paste the script above. Update `CLI_PATH` to the absolute path of your built CLI binary.
4. Save the Quick Action as "Convert MOV to MP4" (or any name you prefer).

The new action appears in Finder's context menu under **Quick Actions**. Because it invokes the shared CLI, it uses the same conversion presets as the GUI app.

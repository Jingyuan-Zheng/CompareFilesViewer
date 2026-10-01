# Compare Files Viewer

[简体中文](README.zh-CN.md)

A native macOS SwiftUI viewer for file-comparison results produced by a Shortcut or another tool. It displays relationships, version order, metadata, evidence, and Finder actions; it does not compare files itself.

## Build

```bash
swift build -c release
```

Pass JSON with `--file`, `--json`, or stdin. The app supports English and Simplified Chinese.

## Use

1. Build with `swift build -c release` and place the executable or app bundle where your Shortcut can run it.
2. Import `Compare Files.shortcut` and configure it to create a result JSON payload.
3. Launch `CompareFilesViewer --file /path/to/result.json`.
4. Review the main version, evidence, and Details sheet; use Reveal in Finder to inspect the referenced files.

## Input and workflow

Use `CompareFilesViewer --file /path/to/result.json`, `--json '<payload>'`, or pipe the payload to stdin. The payload contains `files`, `analysis`, and optional `local_evidence`; see `ExamplePayload.json`. The included Shortcut or another producer must compare files and create this payload before launching the viewer.

## What it shows

- Overall relationship and confidence, recommended main version, and version order.
- Finder icons, paths, sizes, modification times, and Reveal in Finder actions.
- AI groups, local SHA-256 metadata, text differences, and image-comparison evidence when provided.

## Requirements and privacy

Requires macOS 14 or later and Xcode Command Line Tools to build. It performs no network request and does not upload selected files; any AI or comparison policy belongs to the producer Shortcut.

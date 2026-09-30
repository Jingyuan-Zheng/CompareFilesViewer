# Compare Files Viewer

[简体中文](README.zh-CN.md)

A native macOS SwiftUI viewer for file-comparison results produced by a Shortcut or another tool. It displays relationships, version order, metadata, evidence, and Finder actions; it does not compare files itself.

## Build

```bash
swift build -c release
```

Pass JSON with `--file`, `--json`, or stdin. The app supports English and Simplified Chinese.

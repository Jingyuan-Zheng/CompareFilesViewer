# 文件比较结果查看器

[English](README.md)

原生 macOS SwiftUI 查看器，用于展示快捷指令或其他工具生成的文件比较结果。它显示关系、版本顺序、元数据、证据和 Finder 操作；不自行比较文件。

## 构建

```bash
swift build -c release
```

通过 `--file`、`--json` 或标准输入传入 JSON。应用支持英文和简体中文。

## 使用方法

1. 运行 `swift build -c release`，将可执行文件或 App 放到快捷指令可调用的位置。
2. 导入 `Compare Files.shortcut`，让它生成结果 JSON。
3. 运行 `CompareFilesViewer --file /path/to/result.json`。
4. 查看主版本、证据和“详细信息”，并使用“在 Finder 中显示”核对原文件。

## 输入与流程

可使用 `CompareFilesViewer --file /path/to/result.json`、`--json '<payload>'` 或标准输入。数据包含 `files`、`analysis` 和可选的 `local_evidence`；完整示例见 `ExamplePayload.json`。附带快捷指令或其他生产者必须先完成比较并生成数据，再启动查看器。

## 显示内容

- 总体关系与置信度、推荐主版本和版本顺序。
- Finder 图标、路径、大小、修改时间及“在 Finder 中显示”。
- AI 分组、本地 SHA-256 元数据、文本差异和可选图片比较证据。

## 要求与隐私

构建需要 macOS 14 及以上和 Xcode Command Line Tools。应用不发起网络请求，也不上传文件；AI 或比较策略由生成数据的快捷指令决定。

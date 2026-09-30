# 文件比较结果查看器

[English](README.md)

原生 macOS SwiftUI 查看器，用于展示快捷指令或其他工具生成的文件比较结果。它显示关系、版本顺序、元数据、证据和 Finder 操作；不自行比较文件。

## 构建

```bash
swift build -c release
```

通过 `--file`、`--json` 或标准输入传入 JSON。应用支持英文和简体中文。

# CompareFilesViewer

轻量 macOS SwiftUI 结果窗口。界面使用系统 Material / SF Symbols；文件本身的图标优先直接读取 Finder/NSWorkspace 当前显示的真实文件图标。

## 当前界面行为

- 主界面始终显示参与比较的文件。
- `version_order` 非空时显示“版本顺序（从旧到新）”；为空时显示普通“文件”列表。
- `main_file == null` 时明确显示“暂无法可靠确定”，不会隐藏整个区域。
- 文件行显示文件名、简化修改时间和格式化文件大小。
- 主版本显示系统 Accent Color badge，并可“在访达中显示”。
- `groups[].differences` 显示为“主要差异”。
- 总结和建议始终保留。
- “详细信息”中显示 AI 分组、本地 metadata / SHA-256、本地关系证据、文本 diff 和图片差异。
- 文件图标通过 `NSWorkspace.shared.icon(forFile:)` 读取；路径不可用时才回退到 SF Symbol。

## 源码结构

- `CompareFilesViewerApp.swift` — App 入口；以 accessory 模式运行，不显示 Dock 图标。
- `ContentView.swift` — 主窗口。
- `DetailsView.swift` — AI 分组与本地证据详细信息。
- `Models.swift` — AI JSON、文件 metadata、文本/图片 evidence 数据模型。
- `InputLoader.swift` — 支持 JSON 文件、JSON 字符串、stdin。
- `Style.swift` — Material 样式、Finder 文件图标、大小/路径/时间格式化。
- `WindowBackground.swift` — 系统毛玻璃窗口背景。
- `ExamplePayload.json` — 完整输入示例。

## 输入方式

推荐传完整 JSON 文件：

```bash
CompareFilesViewer --file /tmp/compare-files-result.json
```

也可以直接传 AI 固定 JSON：

```bash
CompareFilesViewer --json '{"overall_relation":"VERSION", ...}'
```

或通过 stdin：

```bash
cat /tmp/compare-files-result.json | CompareFilesViewer
```

无参数或 `--preview` 启动时显示内置预览数据。

## 完整 payload

```json
{
  "files": [...],
  "analysis": {...},
  "local_evidence": {
    "relation_signals": [],
    "text_differences": [],
    "text_pair_limit_reached": false,
    "image_differences": []
  }
}
```

`text_differences` 支持：

- `file_a` / `file_b`
- `status`
- `hunks`
- `added_lines` / `removed_lines`
- `sample_added` / `sample_removed`
- `samples_truncated`

## 编译

在 macOS 上：

```bash
swift build -c release
```

或者用 Xcode 打开 `Package.swift` 后运行 `CompareFilesViewer` scheme。

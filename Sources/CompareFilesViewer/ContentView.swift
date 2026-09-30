import AppKit
import SwiftUI

struct ContentView: View {
    let payload: CompareFilesPayload

    @State private var showingDetails = false

    private var analysis: AnalysisResult { payload.analysis }

    private var mainFileInfo: LocalFileInfo? {
        payload.file(named: analysis.mainFile)
    }

    private var usesVersionOrder: Bool {
        analysis.overallRelation != .mixed && !analysis.versionOrder.isEmpty
    }

    private var displayedFileNames: [String] {
        if usesVersionOrder {
            var result: [String] = []
            var seen = Set<String>()

            for name in analysis.versionOrder where seen.insert(name).inserted {
                if payload.files.isEmpty || payload.file(named: name) != nil {
                    result.append(name)
                }
            }

            for file in payload.files where seen.insert(file.name).inserted {
                result.append(file.name)
            }

            return result
        }

        if !payload.files.isEmpty {
            return payload.files.map(\.name)
        }

        if !analysis.groups.isEmpty {
            var seen = Set<String>()
            return analysis.groups
                .flatMap(\.files)
                .filter { seen.insert($0).inserted }
        }

        return analysis.versionOrder
    }

    private var differences: [String] {
        var result: [String] = []
        var seen = Set<String>()

        if analysis.groups.count <= 1 {
            for item in analysis.groups.first?.differences ?? [] where seen.insert(item).inserted {
                result.append(item)
            }
            return result
        }

        for (index, group) in analysis.groups.enumerated() {
            for difference in group.differences {
                let labeled = "文件组 \(index + 1)：\(difference)"
                if seen.insert(labeled).inserted {
                    result.append(labeled)
                }
            }
        }

        return result
    }

    var body: some View {
        ZStack {
            WindowBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    header
                    mainFileCard

                    if !displayedFileNames.isEmpty {
                        filesCard
                    }

                    if !differences.isEmpty {
                        differencesCard
                    }

                    textCard(
                        symbol: "text.alignleft",
                        title: L10n.ui("总结"),
                        text: analysis.summary.isEmpty ? L10n.ui("暂无总结。") : analysis.summary
                    )

                    textCard(
                        symbol: "lightbulb",
                        title: L10n.ui("建议"),
                        text: analysis.recommendation.isEmpty ? L10n.ui("暂无建议。") : analysis.recommendation
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
        }
        .frame(width: 560, height: 720)
        .background(WindowConfigurator())
        .sheet(isPresented: $showingDetails) {
            DetailsView(payload: payload)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 58, height: 58)

                Image(systemName: analysis.overallRelation.symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(analysis.overallRelation.title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))

                Text("\(payload.fileCount) 个文件 · \(payload.groupCount) 个文件组")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ConfidenceBadge(confidence: analysis.confidence)
        }
        .padding(.top, 3)
        .padding(.bottom, 4)
    }

    private var mainFileCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 11) {
                SectionTitle(symbol: "crown", title: L10n.ui("推荐主版本"))

                if let name = analysis.mainFile {
                    HStack(spacing: 12) {
                        FinderFileIcon(file: mainFileInfo, size: 34)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(name)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)

                            if let path = mainFileInfo?.displayPath {
                                Text(path)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }

                        Spacer(minLength: 12)

                        if mainFileInfo?.expandedPath != nil {
                            Button {
                                revealInFinder(mainFileInfo)
                            } label: {
                                Label(L10n.ui("在访达中显示"), systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .frame(width: 34)

                        Text(L10n.ui("暂无法可靠确定"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
            }
        }
    }

    private var filesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    symbol: usesVersionOrder ? "clock.arrow.circlepath" : "doc.on.doc",
                    title: usesVersionOrder ? L10n.ui("版本顺序（从旧到新）") : L10n.ui("文件")
                )

                VStack(spacing: 0) {
                    ForEach(Array(displayedFileNames.enumerated()), id: \.offset) { index, name in
                        fileRow(index: index, name: name)

                        if index != displayedFileNames.count - 1 {
                            Divider()
                                .padding(.leading, usesVersionOrder ? 44 : 38)
                        }
                    }
                }
            }
        }
    }

    private func fileRow(index: Int, name: String) -> some View {
        let info = payload.file(named: name)
        let isMain = name == analysis.mainFile
        let hasVersionNumber = usesVersionOrder && analysis.versionOrder.contains(name)

        return HStack(spacing: 10) {
            if hasVersionNumber {
                ZStack {
                    Circle()
                        .fill(isMain ? Color.accentColor : Color.secondary.opacity(0.13))
                        .frame(width: 26, height: 26)

                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isMain ? Color.white : Color.primary)
                }
            }

            FinderFileIcon(file: info, size: 28)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: isMain ? .semibold : .medium))
                    .lineLimit(1)

                let metadata = [info?.compactModified, info?.formattedSize]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")

                if !metadata.isEmpty {
                    Text(metadata)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isMain {
                Text(L10n.ui("主版本"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            if info?.expandedPath != nil {
                Button {
                    revealInFinder(info)
                } label: {
                    Label(L10n.ui("在访达中显示"), systemImage: "folder")
                }
            }
        }
    }

    private var differencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 11) {
                SectionTitle(symbol: "list.bullet.rectangle", title: L10n.ui("主要差异"))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(differences, id: \.self) { difference in
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)

                            Text(difference)
                                .font(.system(size: 13))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func textCard(symbol: String, title: String, text: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 9) {
                SectionTitle(symbol: symbol, title: title)

                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                showingDetails = true
            } label: {
                Label(L10n.ui("查看详细信息…"), systemImage: "info.circle")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(L10n.ui("完成")) {
                NSApp.keyWindow?.performClose(nil)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func revealInFinder(_ file: LocalFileInfo?) {
        guard let path = file?.expandedPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

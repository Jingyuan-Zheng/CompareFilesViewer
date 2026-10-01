import AppKit
import SwiftUI

struct DetailsView: View {
    let payload: CompareFilesPayload

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            WindowBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.ui("Details"))
                            .font(.system(size: 20, weight: .bold))
                        Text(L10n.ui("AI groups and local evidence"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(16)

                Divider()

                ScrollView {
                    VStack(spacing: 12) {
                        if !payload.analysis.groups.isEmpty {
                            groupsSection
                        }

                        if !payload.files.isEmpty {
                            localFilesSection
                        }

                        if let evidence = payload.localEvidence, hasEvidence(evidence) {
                            evidenceSection(evidence)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 660, height: 720)
    }

    private func hasEvidence(_ evidence: LocalEvidence) -> Bool {
        !evidence.relationSignals.isEmpty ||
        !evidence.textDifferences.isEmpty ||
        evidence.textPairLimitReached ||
        !evidence.imageDifferences.isEmpty ||
        evidence.imagePairLimitReached
    }

    private var groupsSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(payload.analysis.groups.enumerated()), id: \.offset) { index, group in
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionTitle(symbol: "square.stack.3d.up", title: L10n.ui("File Group %d", index + 1))
                            RelationBadge(relation: group.relation)
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Text(L10n.ui("Files"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)

                            ForEach(group.files, id: \.self) { name in
                                groupFileRow(name: name, isMain: name == group.mainFile)
                            }
                        }

                        Divider()

                        detailRow(
                            L10n.ui("Recommended Main Version"),
                            group.mainFile ?? L10n.ui("Unable to determine reliably")
                        )

                        if !group.versionOrder.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.ui("Version Order"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(Array(group.versionOrder.enumerated()), id: \.offset) { versionIndex, file in
                                    HStack(spacing: 8) {
                                        Text("\(versionIndex + 1)")
                                            .font(.system(size: 10, weight: .bold))
                                            .frame(width: 20, height: 20)
                                            .background(.quaternary, in: Circle())

                                        FinderFileIcon(file: payload.file(named: file), size: 20)

                                        Text(file)
                                            .font(.system(size: 12))
                                    }
                                }
                            }
                        }

                        if !group.differences.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.ui("Key Differences"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(group.differences, id: \.self) { difference in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 4))
                                            .foregroundStyle(.secondary)

                                        Text(difference)
                                            .font(.system(size: 12))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func groupFileRow(name: String, isMain: Bool) -> some View {
        let file = payload.file(named: name)

        return HStack(spacing: 9) {
            FinderFileIcon(file: file, size: 24)

            Text(name)
                .font(.system(size: 12, weight: isMain ? .semibold : .regular))
                .lineLimit(1)

            Spacer()

            if isMain {
                Text(L10n.ui("Main Version"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
            }
        }
    }

    private var localFilesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(symbol: "internaldrive", title: L10n.ui("Local File Information"))

                ForEach(Array(payload.files.enumerated()), id: \.offset) { index, file in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            FinderFileIcon(file: file, size: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)

                                if let size = file.formattedSize {
                                    Text(size)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if file.expandedPath != nil {
                                Button {
                                    revealInFinder(file)
                                } label: {
                                    Image(systemName: "folder")
                                }
                                .buttonStyle(.borderless)
                                .help(L10n.ui("Show in Finder"))
                            }
                        }

                        if let path = file.displayPath {
                            metadataRow(L10n.ui("Path"), path)
                        }
                        if let created = file.created {
                            metadataRow(L10n.ui("Created"), created)
                        }
                        if let modified = file.modified {
                            metadataRow(L10n.ui("Modified"), modified)
                        }
                        if let metadata = file.metadata {
                            metadataRow(L10n.ui("Metadata"), metadata)
                        }
                        if let family = file.normalizedFamily {
                            metadataRow(L10n.ui("File Family"), family)
                        }
                        if let sha = file.sha256 {
                            metadataRow("SHA-256", sha, monospaced: true)
                        }
                        if let textSha = file.textSha256 {
                            metadataRow(L10n.ui("Text SHA-256"), textSha, monospaced: true)
                        }
                    }

                    if index != payload.files.count - 1 {
                        Divider()
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func evidenceSection(_ evidence: LocalEvidence) -> some View {
        VStack(spacing: 12) {
            if !evidence.relationSignals.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(symbol: "checklist", title: L10n.ui("Local relationship evidence"))

                        ForEach(evidence.relationSignals, id: \.self) { signal in
                            Text(signal)
                                .font(.system(size: 11, design: .monospaced))
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            if !evidence.textDifferences.isEmpty || evidence.textPairLimitReached {
                textDifferencesSection(evidence)
            }

            if !evidence.imageDifferences.isEmpty || evidence.imagePairLimitReached {
                imageDifferencesSection(evidence)
            }
        }
    }

    private func textDifferencesSection(_ evidence: LocalEvidence) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(symbol: "doc.text.magnifyingglass", title: L10n.ui("Text Differences"))

                ForEach(Array(evidence.textDifferences.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("\(item.fileA) → \(item.fileB)")
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)

                            Spacer()

                            Text(item.statusTitle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(item.status == "DIFFERENT_TEXT" ? Color.accentColor : Color.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.quaternary, in: Capsule())
                        }

                        if item.status == "DIFFERENT_TEXT" {
                            let pieces = [
                                item.addedLines.map { L10n.ui("%d lines added", $0) },
                                item.removedLines.map { L10n.ui("%d lines removed", $0) },
                                item.hunks.map { L10n.ui("%d difference regions", $0) }
                            ]
                            .compactMap { $0 }

                            if !pieces.isEmpty {
                                Text(pieces.joined(separator: " · "))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            if !item.sampleAdded.isEmpty {
                                sampleLines(title: L10n.ui("Added samples"), symbol: "plus.circle", lines: item.sampleAdded)
                            }

                            if !item.sampleRemoved.isEmpty {
                                sampleLines(title: L10n.ui("Removed samples"), symbol: "minus.circle", lines: item.sampleRemoved)
                            }

                            if item.samplesTruncated {
                                Label(L10n.ui("Only some difference samples are shown."), systemImage: "ellipsis.circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if index != evidence.textDifferences.count - 1 {
                        Divider()
                    }
                }

                if evidence.textPairLimitReached {
                    Label(L10n.ui("There are many files, so not every text pair was compared."), systemImage: "exclamationmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func imageDifferencesSection(_ evidence: LocalEvidence) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(symbol: "photo.on.rectangle.angled", title: L10n.ui("Image Differences"))

                ForEach(evidence.imageDifferences) { item in
                    HStack {
                        Text("\(item.fileA) ↔ \(item.fileB)")
                            .font(.system(size: 11))
                            .lineLimit(1)

                        Spacer()

                        Text(item.score.map { String(format: "%.5f", $0) } ?? L10n.ui("Unavailable"))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if evidence.imagePairLimitReached {
                    Label(L10n.ui("There are many files, so not every image pair was compared pixel by pixel."), systemImage: "exclamationmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sampleLines(title: String, symbol: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 10, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.leading, 18)
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }

    private func metadataRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)

            Text(value)
                .font(.system(size: 11, design: monospaced ? .monospaced : .default))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
    }

    private func revealInFinder(_ file: LocalFileInfo) {
        guard let path = file.expandedPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

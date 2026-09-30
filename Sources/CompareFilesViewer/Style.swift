import AppKit
import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

struct SectionTitle: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Spacer(minLength: 0)
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Confidence

    private var tint: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: confidence.symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(confidence.title)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.13), in: Capsule())
        .accessibilityLabel("置信度 \(confidence.title)")
    }
}

struct RelationBadge: View {
    let relation: Relation

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: relation.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(relation.title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.10), in: Capsule())
    }
}

struct FinderFileIcon: View {
    let file: LocalFileInfo?
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let image = file?.workspaceIcon {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: file?.fileSymbol ?? "doc.fill")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .padding(size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension LocalFileInfo {
    var formattedSize: String? {
        guard let size else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var expandedPath: String? {
        guard let path, !path.isEmpty else { return nil }
        return NSString(string: path).expandingTildeInPath
    }

    var displayPath: String? {
        guard let expandedPath else { return nil }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if expandedPath == home {
            return "~"
        }
        if expandedPath.hasPrefix(home + "/") {
            return "~" + String(expandedPath.dropFirst(home.count))
        }

        return expandedPath
    }

    var compactModified: String? {
        guard let modified, !modified.isEmpty else { return nil }

        // Shell format is normally "yyyy-MM-dd HH:mm:ss Z". Keeping the
        // first 16 characters avoids unnecessary timezone conversion and
        // also works with preview strings that already omit seconds.
        if modified.count >= 16 {
            let end = modified.index(modified.startIndex, offsetBy: 16)
            let prefix = String(modified[..<end])
            if prefix.count == 16, prefix[prefix.index(prefix.startIndex, offsetBy: 10)] == " " {
                return prefix
            }
        }

        return modified
    }

    var workspaceIcon: NSImage? {
        guard let path = expandedPath,
              FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }

    var fileSymbol: String {
        switch (`extension` ?? "").lowercased() {
        case "pdf": return "doc.richtext.fill"
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "tif", "tiff", "webp": return "photo.fill"
        case "ppt", "pptx", "ppsx", "key": return "rectangle.3.group.fill"
        case "xls", "xlsx", "xlsm", "numbers", "csv": return "tablecells.fill"
        case "zip", "7z", "rar", "tar", "gz": return "archivebox.fill"
        case "txt", "md", "rtf", "doc", "docx", "pages": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
}

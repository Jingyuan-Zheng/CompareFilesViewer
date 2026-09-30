import Foundation

struct CompareFilesPayload: Codable, Sendable {
    var files: [LocalFileInfo]
    var analysis: AnalysisResult
    var localEvidence: LocalEvidence?

    enum CodingKeys: String, CodingKey {
        case files
        case analysis
        case localEvidence = "local_evidence"
    }
}

struct LocalFileInfo: Codable, Identifiable, Hashable, Sendable {
    var id: String { path ?? name }

    let name: String
    let path: String?
    let size: Int64?
    let created: String?
    let modified: String?
    let `extension`: String?
    let sha256: String?
    let textSha256: String?
    let normalizedFamily: String?
    let metadata: String?

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case size
        case created
        case modified
        case `extension`
        case sha256
        case textSha256 = "text_sha256"
        case normalizedFamily = "normalized_family"
        case metadata
    }
}

struct LocalEvidence: Codable, Sendable {
    let relationSignals: [String]
    let textDifferences: [TextDifference]
    let textPairLimitReached: Bool
    let imageDifferences: [ImageDifference]
    let imagePairLimitReached: Bool

    enum CodingKeys: String, CodingKey {
        case relationSignals = "relation_signals"
        case textDifferences = "text_differences"
        case textPairLimitReached = "text_pair_limit_reached"
        case imageDifferences = "image_differences"
        case imagePairLimitReached = "image_pair_limit_reached"
    }

    init(
        relationSignals: [String] = [],
        textDifferences: [TextDifference] = [],
        textPairLimitReached: Bool = false,
        imageDifferences: [ImageDifference] = [],
        imagePairLimitReached: Bool = false
    ) {
        self.relationSignals = relationSignals
        self.textDifferences = textDifferences
        self.textPairLimitReached = textPairLimitReached
        self.imageDifferences = imageDifferences
        self.imagePairLimitReached = imagePairLimitReached
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        relationSignals = try container.decodeIfPresent([String].self, forKey: .relationSignals) ?? []
        textDifferences = try container.decodeIfPresent([TextDifference].self, forKey: .textDifferences) ?? []
        textPairLimitReached = try container.decodeIfPresent(Bool.self, forKey: .textPairLimitReached) ?? false
        imageDifferences = try container.decodeIfPresent([ImageDifference].self, forKey: .imageDifferences) ?? []
        imagePairLimitReached = try container.decodeIfPresent(Bool.self, forKey: .imagePairLimitReached) ?? false
    }
}

struct TextDifference: Codable, Identifiable, Sendable {
    var id: String { "\(fileA)|\(fileB)" }

    let fileA: String
    let fileB: String
    let status: String
    let hunks: Int?
    let addedLines: Int?
    let removedLines: Int?
    let sampleAdded: [String]
    let sampleRemoved: [String]
    let samplesTruncated: Bool

    enum CodingKeys: String, CodingKey {
        case fileA = "file_a"
        case fileB = "file_b"
        case status
        case hunks
        case addedLines = "added_lines"
        case removedLines = "removed_lines"
        case sampleAdded = "sample_added"
        case sampleRemoved = "sample_removed"
        case samplesTruncated = "samples_truncated"
    }

    init(
        fileA: String,
        fileB: String,
        status: String,
        hunks: Int? = nil,
        addedLines: Int? = nil,
        removedLines: Int? = nil,
        sampleAdded: [String] = [],
        sampleRemoved: [String] = [],
        samplesTruncated: Bool = false
    ) {
        self.fileA = fileA
        self.fileB = fileB
        self.status = status
        self.hunks = hunks
        self.addedLines = addedLines
        self.removedLines = removedLines
        self.sampleAdded = sampleAdded
        self.sampleRemoved = sampleRemoved
        self.samplesTruncated = samplesTruncated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileA = try container.decode(String.self, forKey: .fileA)
        fileB = try container.decode(String.self, forKey: .fileB)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "UNAVAILABLE"
        hunks = try container.decodeIfPresent(Int.self, forKey: .hunks)
        addedLines = try container.decodeIfPresent(Int.self, forKey: .addedLines)
        removedLines = try container.decodeIfPresent(Int.self, forKey: .removedLines)
        sampleAdded = try container.decodeIfPresent([String].self, forKey: .sampleAdded) ?? []
        sampleRemoved = try container.decodeIfPresent([String].self, forKey: .sampleRemoved) ?? []
        samplesTruncated = try container.decodeIfPresent(Bool.self, forKey: .samplesTruncated) ?? false
    }

    var statusTitle: String {
        switch status {
        case "IDENTICAL_TEXT": return L10n.ui("提取文本一致")
        case "DIFFERENT_TEXT": return L10n.ui("提取文本不同")
        default: return L10n.ui("文本不可用")
        }
    }
}

struct ImageDifference: Codable, Identifiable, Sendable {
    var id: String { "\(fileA)|\(fileB)" }

    let fileA: String
    let fileB: String
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case fileA = "file_a"
        case fileB = "file_b"
        case score
    }
}

struct AnalysisResult: Codable, Sendable {
    let overallRelation: Relation
    let confidence: Confidence
    let mainFile: String?
    let versionOrder: [String]
    let groups: [FileGroup]
    let summary: String
    let recommendation: String

    enum CodingKeys: String, CodingKey {
        case overallRelation = "overall_relation"
        case confidence
        case mainFile = "main_file"
        case versionOrder = "version_order"
        case groups
        case summary
        case recommendation
    }

    init(
        overallRelation: Relation,
        confidence: Confidence,
        mainFile: String? = nil,
        versionOrder: [String] = [],
        groups: [FileGroup] = [],
        summary: String = "",
        recommendation: String = ""
    ) {
        self.overallRelation = overallRelation
        self.confidence = confidence
        self.mainFile = mainFile
        self.versionOrder = versionOrder
        self.groups = groups
        self.summary = summary
        self.recommendation = recommendation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overallRelation = try container.decode(Relation.self, forKey: .overallRelation)
        confidence = try container.decode(Confidence.self, forKey: .confidence)
        mainFile = try container.decodeIfPresent(String.self, forKey: .mainFile)
        versionOrder = try container.decodeIfPresent([String].self, forKey: .versionOrder) ?? []
        groups = try container.decodeIfPresent([FileGroup].self, forKey: .groups) ?? []
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        recommendation = try container.decodeIfPresent(String.self, forKey: .recommendation) ?? ""
    }
}

struct FileGroup: Codable, Identifiable, Sendable {
    var id: String { files.joined(separator: "|") + "|" + relation.rawValue }

    let files: [String]
    let relation: Relation
    let mainFile: String?
    let versionOrder: [String]
    let differences: [String]

    enum CodingKeys: String, CodingKey {
        case files
        case relation
        case mainFile = "main_file"
        case versionOrder = "version_order"
        case differences
    }

    init(
        files: [String],
        relation: Relation,
        mainFile: String? = nil,
        versionOrder: [String] = [],
        differences: [String] = []
    ) {
        self.files = files
        self.relation = relation
        self.mainFile = mainFile
        self.versionOrder = versionOrder
        self.differences = differences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        files = try container.decodeIfPresent([String].self, forKey: .files) ?? []
        relation = try container.decode(Relation.self, forKey: .relation)
        mainFile = try container.decodeIfPresent(String.self, forKey: .mainFile)
        versionOrder = try container.decodeIfPresent([String].self, forKey: .versionOrder) ?? []
        differences = try container.decodeIfPresent([String].self, forKey: .differences) ?? []
    }
}

enum Relation: String, Codable, CaseIterable, Sendable {
    case exact = "EXACT"
    case nearDuplicate = "NEAR_DUPLICATE"
    case version = "VERSION"
    case sameProject = "SAME_PROJECT"
    case unrelated = "UNRELATED"
    case mixed = "MIXED"
    case uncertain = "UNCERTAIN"

    var title: String {
        switch self {
        case .exact: return L10n.ui("完全相同")
        case .nearDuplicate: return L10n.ui("近似重复")
        case .version: return L10n.ui("不同版本")
        case .sameProject: return L10n.ui("同一项目")
        case .unrelated: return L10n.ui("完全无关")
        case .mixed: return L10n.ui("混合关系")
        case .uncertain: return L10n.ui("无法可靠判断")
        }
    }

    var symbol: String {
        switch self {
        case .exact: return "doc.on.doc"
        case .nearDuplicate: return "square.on.square"
        case .version: return "clock.arrow.circlepath"
        case .sameProject: return "folder"
        case .unrelated: return "arrow.triangle.branch"
        case .mixed: return "square.stack.3d.up"
        case .uncertain: return "questionmark.circle"
        }
    }
}

enum Confidence: String, Codable, CaseIterable, Sendable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"

    var title: String {
        switch self {
        case .high: return L10n.ui("高")
        case .medium: return L10n.ui("中")
        case .low: return L10n.ui("低")
        }
    }

    var symbol: String {
        switch self {
        case .high: return "chart.bar.fill"
        case .medium: return "chart.bar"
        case .low: return "exclamationmark.triangle.fill"
        }
    }
}

extension CompareFilesPayload {
    var allFileNames: [String] {
        if !files.isEmpty {
            return files.map(\.name)
        }

        let grouped = analysis.groups.flatMap(\.files)
        if !grouped.isEmpty {
            var seen = Set<String>()
            return grouped.filter { seen.insert($0).inserted }
        }

        return analysis.versionOrder
    }

    var fileCount: Int {
        allFileNames.count
    }

    var groupCount: Int {
        max(analysis.groups.count, fileCount > 0 ? 1 : 0)
    }

    func file(named name: String?) -> LocalFileInfo? {
        guard let name else { return nil }
        return files.first { $0.name == name }
    }
}

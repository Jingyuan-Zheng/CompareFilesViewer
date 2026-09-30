import Darwin
import Foundation

struct InputLoader {
    static func load() throws -> CompareFilesPayload {
        let arguments = Array(CommandLine.arguments.dropFirst())

        if let fileIndex = arguments.firstIndex(of: "--file"),
           arguments.indices.contains(fileIndex + 1) {
            let path = arguments[fileIndex + 1]
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return try decode(data)
        }

        if let jsonIndex = arguments.firstIndex(of: "--json"),
           arguments.indices.contains(jsonIndex + 1) {
            return try decode(Data(arguments[jsonIndex + 1].utf8))
        }

        if arguments.contains("--preview") {
            return SampleData.payload
        }

        if isatty(STDIN_FILENO) == 0 {
            let stdinData = FileHandle.standardInput.readDataToEndOfFile()
            if !stdinData.isEmpty,
               let text = String(data: stdinData, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return try decode(stdinData)
            }
        }

        return SampleData.payload
    }

    private static func decode(_ data: Data) throws -> CompareFilesPayload {
        let decoder = JSONDecoder()

        if let payload = try? decoder.decode(CompareFilesPayload.self, from: data) {
            return payload
        }

        if let analysis = try? decoder.decode(AnalysisResult.self, from: data) {
            return CompareFilesPayload(files: [], analysis: analysis, localEvidence: nil)
        }

        throw InputError.invalidJSON
    }
}

enum InputError: LocalizedError {
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "无法解析 Compare Files JSON。请传入固定 AI JSON，或包含 files / analysis 的完整 payload。"
        }
    }
}

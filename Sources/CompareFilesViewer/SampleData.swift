import Foundation

struct SampleData {
    static let payload = CompareFilesPayload(
        files: [
            LocalFileInfo(
                name: "report.pdf",
                path: "~/Downloads/report.pdf",
                size: 2_101_284,
                created: "2026-08-10 14:22",
                modified: "2026-08-10 14:22",
                extension: "pdf",
                sha256: "0d6d8f6c2b9f…",
                textSha256: "7d1acb34c82e…",
                normalizedFamily: "report",
                metadata: "com.adobe.pdf, pages 12"
            ),
            LocalFileInfo(
                name: "report-v2.pdf",
                path: "~/Downloads/report-v2.pdf",
                size: 2_417_611,
                created: "2026-08-18 09:41",
                modified: "2026-08-18 09:41",
                extension: "pdf",
                sha256: "61ab43d8710f…",
                textSha256: "bd8b2b06c927…",
                normalizedFamily: "report",
                metadata: "com.adobe.pdf, pages 13"
            ),
            LocalFileInfo(
                name: "report-final.pdf",
                path: "~/Downloads/report-final.pdf",
                size: 2_643_220,
                created: "2026-09-01 16:03",
                modified: "2026-09-01 16:03",
                extension: "pdf",
                sha256: "fd21aa93a90a…",
                textSha256: "4a97621df86f…",
                normalizedFamily: "report",
                metadata: "com.adobe.pdf, pages 14"
            )
        ],
        analysis: AnalysisResult(
            overallRelation: .version,
            confidence: .high,
            mainFile: "report-final.pdf",
            versionOrder: ["report.pdf", "report-v2.pdf", "report-final.pdf"],
            groups: [
                FileGroup(
                    files: ["report.pdf", "report-v2.pdf", "report-final.pdf"],
                    relation: .version,
                    mainFile: "report-final.pdf",
                    versionOrder: ["report.pdf", "report-v2.pdf", "report-final.pdf"],
                    differences: [
                        "新增第 4 章：实验结果分析",
                        "修改结论部分的表述",
                        "页面从 12 页增加到 14 页",
                        "新增 2 张图表",
                        "删除旧版附录 A"
                    ]
                )
            ],
            summary: "3 个文件属于同一文档的不同版本，内容存在连续的修改和更新。",
            recommendation: "建议将 report-final.pdf 作为主要版本保留，其他版本按需要留作备份或参考。"
        ),
        localEvidence: LocalEvidence(
            relationSignals: [
                "report.pdf ↔ report-v2.pdf : NORMALIZED_NAME_MATCH, EXTRACTED_TEXT_DIFFERS",
                "report-v2.pdf ↔ report-final.pdf : NORMALIZED_NAME_MATCH, EXTRACTED_TEXT_DIFFERS"
            ],
            textDifferences: [
                TextDifference(
                    fileA: "report.pdf",
                    fileB: "report-v2.pdf",
                    status: "DIFFERENT_TEXT",
                    hunks: 2,
                    addedLines: 8,
                    removedLines: 2,
                    sampleAdded: ["4. 实验结果分析", "增加了一组实验结果。"],
                    sampleRemoved: ["旧版结论段落"],
                    samplesTruncated: true
                ),
                TextDifference(
                    fileA: "report-v2.pdf",
                    fileB: "report-final.pdf",
                    status: "DIFFERENT_TEXT",
                    hunks: 1,
                    addedLines: 3,
                    removedLines: 1,
                    sampleAdded: ["最终结论经过修订。"],
                    sampleRemoved: ["初步结论。"]
                )
            ],
            imageDifferences: []
        )
    )
}

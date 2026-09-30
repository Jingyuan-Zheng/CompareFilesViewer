import Foundation

enum AppLanguage: String, CaseIterable, Identifiable { case english = "en"; case simplifiedChinese = "zh-Hans"; var id: String { rawValue }; var nativeName: String { self == .english ? "English" : "简体中文" } }

enum L10n {
    static func ui(_ chinese: String) -> String {
        guard AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "en") == .english else { return chinese }
        return [
            "详细信息": "Details", "AI 分组与本地证据": "AI groups and local evidence", "文件": "Files", "文件组": "File Group", "推荐主版本": "Recommended Main Version", "主版本": "Main Version", "暂无法可靠确定": "Unable to determine reliably", "版本顺序": "Version Order", "版本顺序（从旧到新）": "Version Order (oldest to newest)", "主要差异": "Key Differences", "总结": "Summary", "建议": "Recommendation", "暂无总结。": "No summary available.", "暂无建议。": "No recommendation available.", "查看详细信息…": "View Details…", "完成": "Done", "在访达中显示": "Show in Finder", "本地文件信息": "Local File Information", "路径": "Path", "创建时间": "Created", "修改时间": "Modified", "置信度": "Confidence", "无法显示比较结果": "Unable to display comparison result", "关闭": "Close", "没有收到可显示的数据。": "No displayable data was received.", "高": "High", "中": "Medium", "低": "Low", "完全相同": "Exact Match", "近似重复": "Near Duplicate", "不同版本": "Different Versions", "同一项目": "Same Project", "完全无关": "Unrelated", "混合关系": "Mixed Relationship", "无法可靠判断": "Unable to Determine"
        ][chinese] ?? chinese
    }
}

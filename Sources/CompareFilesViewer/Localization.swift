import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var nativeName: String { self == .english ? "English" : "简体中文" }
    var locale: Locale { Locale(identifier: rawValue) }

    static let launchedLanguage = AppLanguage(
        rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.english.rawValue
    ) ?? .english
}

enum L10n {
    static func ui(_ english: String, _ arguments: CVarArg...) -> String {
        let bundle = Bundle.main.path(forResource: AppLanguage.launchedLanguage.rawValue, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .module
        let format = bundle.localizedString(forKey: english, value: english, table: "Localizable")
        return arguments.isEmpty ? format : String(format: format, locale: AppLanguage.launchedLanguage.locale, arguments: arguments)
    }
}

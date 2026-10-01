import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var language = AppLanguage.english.rawValue
    var body: some View {
        Form {
            Picker(L10n.ui("Language"), selection: $language) {
                ForEach(AppLanguage.allCases) { option in
                    Text(verbatim: option.nativeName).tag(option.rawValue)
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 360)
        .onChange(of: language) { _, newValue in
            guard let language = AppLanguage(rawValue: newValue) else { return }
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
}

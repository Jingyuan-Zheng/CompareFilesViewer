import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var language = AppLanguage.english.rawValue
    var body: some View { Form { Picker("Language", selection: $language) { ForEach(AppLanguage.allCases) { Text(verbatim: $0.nativeName).tag($0.rawValue) } } }.formStyle(.grouped).padding(16).frame(width: 360) }
}

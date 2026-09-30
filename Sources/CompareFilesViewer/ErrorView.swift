import AppKit
import SwiftUI

struct ErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            WindowBackground()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)

                Text("无法显示比较结果")
                    .font(.system(size: 20, weight: .bold))

                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                Button("关闭") {
                    NSApp.keyWindow?.performClose(nil)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(32)
        }
        .frame(width: 440, height: 280)
        .background(WindowConfigurator())
    }
}

// AIDataConsentView.swift - 欢迎页（全屏，首次启动显示）
// 简洁友好的欢迎界面，继续即表示同意使用条款和隐私政策

import SwiftUI
import WebKit

struct AIDataConsentView: View {
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @Binding var hasConsented: Bool
    var onAgree: () -> Void
    var onDecline: () -> Void

    @State private var showTerms = false
    @State private var showPrivacy = false

    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }

    var body: some View {
        ZStack {
            colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App Logo
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 4)

                // App 名称
                Text("Smart Book")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(colors.primaryText)
                    .padding(.top, 20)

                // 技术支持说明
                Text(L("consent.poweredBy"))
                    .font(.subheadline)
                    .foregroundColor(colors.secondaryText)
                    .padding(.top, 8)

                Spacer()

                // 继续按钮
                Button {
                    onAgree()
                } label: {
                    Text(L("consent.continue"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 32)

                // 使用条款和隐私政策说明
                HStack(spacing: 0) {
                    Text(L("consent.agreementPrefix"))
                        .font(.caption)
                        .foregroundColor(colors.secondaryText)

                    Button {
                        showTerms = true
                    } label: {
                        Text(L("consent.termsOfService"))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Text(L("consent.and"))
                        .font(.caption)
                        .foregroundColor(colors.secondaryText)

                    Button {
                        showPrivacy = true
                    } label: {
                        Text(L("consent.privacyPolicy"))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showTerms) {
            TermsWebView()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyWebView()
        }
    }
}

// MARK: - 使用条款 WebView
struct TermsWebView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            WebViewContainer(url: termsURL())
                .navigationTitle(L("settings.termsOfService"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L("common.done")) {
                            dismiss()
                        }
                    }
                }
        }
    }

    private func termsURL() -> URL {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let url = lang.hasPrefix("zh") ? "https://raccoonx.ai/service/cn" : "https://raccoonx.ai/service"
        return URL(string: url)!
    }
}

// MARK: - 隐私政策 WebView
struct PrivacyPolicyWebView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            WebViewContainer(url: privacyPolicyURL())
                .navigationTitle(L("settings.privacyPolicy"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L("common.done")) {
                            dismiss()
                        }
                    }
                }
        }
    }

    private func privacyPolicyURL() -> URL {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let url = lang.hasPrefix("zh") ? "https://raccoonx.ai/privacy/cn" : "https://raccoonx.ai/privacy"
        return URL(string: url)!
    }
}

// MARK: - 简单 WebView 容器
struct WebViewContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

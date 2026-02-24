// AIDataConsentView.swift - AI 数据共享同意弹窗（全屏，不可滚动）
// 满足 Apple App Store 审核要求：在发送用户数据到第三方 AI 服务前获得用户明确同意

import SwiftUI
import WebKit

struct AIDataConsentView: View {
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var systemColorScheme
    @Binding var hasConsented: Bool
    var onAgree: () -> Void
    var onDecline: () -> Void

    @State private var showPrivacyPolicy = false

    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }

    var body: some View {
        ZStack {
            colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                // 头部图标 + 标题
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text(L("consent.title"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colors.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                // 说明文字
                Text(L("consent.description"))
                    .font(.footnote)
                    .foregroundColor(colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)

                Spacer(minLength: 8)

                // 数据共享详情
                VStack(alignment: .leading, spacing: 10) {
                    ConsentServiceRow(
                        icon: "bubble.left.and.text.bubble.right",
                        iconColor: .blue,
                        title: "Google Gemini",
                        description: L("consent.service.gemini"),
                        colors: colors
                    )
                    Divider()
                    ConsentServiceRow(
                        icon: "speaker.wave.3",
                        iconColor: .green,
                        title: "Google Cloud TTS",
                        description: L("consent.service.googleTTS"),
                        colors: colors
                    )
                    Divider()
                    ConsentServiceRow(
                        icon: "mic.fill",
                        iconColor: .purple,
                        title: "Deepgram",
                        description: L("consent.service.deepgram"),
                        colors: colors
                    )
                }
                .padding(14)
                .background(colors.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, 24)

                Spacer(minLength: 8)

                // 数据保护说明
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text(L("consent.protection.encrypted"))
                            .font(.caption)
                            .foregroundColor(colors.secondaryText)
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    Label {
                        Text(L("consent.protection.noTraining"))
                            .font(.caption)
                            .foregroundColor(colors.secondaryText)
                    } icon: {
                        Image(systemName: "xmark.shield")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    Label {
                        Text(L("consent.protection.withdraw"))
                            .font(.caption)
                            .foregroundColor(colors.secondaryText)
                    } icon: {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 8)

                // 隐私政策链接
                Button {
                    showPrivacyPolicy = true
                } label: {
                    Text(L("consent.viewPrivacyPolicy"))
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .underline()
                }

                Spacer(minLength: 12)

                // 按钮
                VStack(spacing: 10) {
                    Button {
                        onAgree()
                    } label: {
                        Text(L("consent.agree"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(14)
                    }

                    Button {
                        onDecline()
                    } label: {
                        Text(L("consent.decline"))
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }

                    Text(L("consent.declineNote"))
                        .font(.caption2)
                        .foregroundColor(colors.secondaryText.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 8)
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyWebView()
        }
    }
}

// MARK: - 服务行组件
struct ConsentServiceRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let colors: ThemeColors

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(colors.primaryText)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
        let path = lang.hasPrefix("zh") ? "/privacy_cn.html" : "/privacy.html"
        return URL(string: "\(AppConfig.apiBaseURL)\(path)")
            ?? URL(string: "https://example.com/privacy")!
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

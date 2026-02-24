// AIDataConsentView.swift - AI 数据共享同意弹窗
// 满足 Apple App Store 审核要求：在发送用户数据到第三方 AI 服务前获得用户明确同意

import SwiftUI

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
            // 背景遮罩
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 头部图标
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                            .padding(.top, 28)

                        Text(L("consent.title"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(colors.primaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 16)

                    // 说明文字
                    Text(L("consent.description"))
                        .font(.subheadline)
                        .foregroundColor(colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // 数据共享详情
                    VStack(alignment: .leading, spacing: 12) {
                        // Google Gemini
                        ConsentServiceRow(
                            icon: "bubble.left.and.text.bubble.right",
                            iconColor: .blue,
                            title: "Google Gemini",
                            description: L("consent.service.gemini"),
                            colors: colors
                        )

                        Divider()

                        // Google TTS
                        ConsentServiceRow(
                            icon: "speaker.wave.3",
                            iconColor: .green,
                            title: "Google Cloud TTS",
                            description: L("consent.service.googleTTS"),
                            colors: colors
                        )

                        Divider()

                        // Deepgram
                        ConsentServiceRow(
                            icon: "mic.fill",
                            iconColor: .purple,
                            title: "Deepgram",
                            description: L("consent.service.deepgram"),
                            colors: colors
                        )
                    }
                    .padding(16)
                    .background(colors.cardBackground.opacity(0.6))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    // 数据保护说明
                    VStack(alignment: .leading, spacing: 8) {
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
                    .padding(16)
                    .padding(.horizontal, 4)

                    // 隐私政策链接
                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        Text(L("consent.viewPrivacyPolicy"))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .underline()
                    }
                    .padding(.bottom, 20)

                    // 按钮
                    VStack(spacing: 10) {
                        // 同意按钮
                        Button {
                            onAgree()
                        } label: {
                            Text(L("consent.agree"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }

                        // 不同意按钮
                        Button {
                            onDecline()
                        } label: {
                            Text(L("consent.decline"))
                                .font(.subheadline)
                                .foregroundColor(colors.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }

                        // 不同意的提示
                        Text(L("consent.declineNote"))
                            .font(.caption2)
                            .foregroundColor(colors.secondaryText.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 20)
                }
                .background(colors.background)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
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
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(colors.primaryText)
                Text(description)
                    .font(.caption)
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
        // 根据语言选择隐私政策页面
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let path = lang.hasPrefix("zh") ? "/privacy_cn.html" : "/privacy.html"
        return URL(string: "\(AppConfig.apiBaseURL)\(path)")
            ?? URL(string: "https://example.com/privacy")!
    }
}

// MARK: - 简单 WebView 容器
import WebKit

struct WebViewContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

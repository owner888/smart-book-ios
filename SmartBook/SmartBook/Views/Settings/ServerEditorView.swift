// ServerEditorView.swift - 服务器地址编辑视图

import SwiftUI

struct ServerEditorView: View {
    @Binding var url: String
    var colors: ThemeColors
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var isValid = true

    var body: some View {
        NavigationStack {
            ZStack {
                colors.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    // 输入框
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("server.address"))
                            .font(.headline)
                            .foregroundColor(colors.primaryText)

                        TextField(L("server.address.placeholder"), text: $url)
                            .textFieldStyle(.plain)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(colors.cardBackground)
                            .cornerRadius(10)
                            .foregroundColor(colors.primaryText)
                            .focused($isFocused)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isValid ? Color.clear : Color.red, lineWidth: 1)
                            )

                        if !isValid {
                            Text(L("server.url.invalid"))
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(colors.cardBackground)
                    .cornerRadius(12)

                    // 常用地址
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("server.quickSet"))
                            .font(.headline)
                            .foregroundColor(colors.primaryText)

                        ForEach(quickURLs, id: \.self) { quickURL in
                            Button {
                                url = quickURL
                            } label: {
                                HStack {
                                    Text(quickURL)
                                        .foregroundColor(colors.primaryText)
                                    Spacer()
                                    if url == quickURL {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(colors.primaryText)
                                    }
                                }
                                .padding(12)
                                .background(colors.inputBackground)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(colors.cardBackground)
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(L("server.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colors.navigationBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                    .foregroundColor(colors.primaryText)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common.save")) {
                        if validateURL(url) {
                            onSave(url)
                        } else {
                            isValid = false
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(colors.primaryText)
                }
            }
            .onAppear {
                isFocused = true
            }
            .onChange(of: url) { _, _ in
                isValid = true
            }
        }
    }

    // MARK: - Helper Methods

    private var quickURLs: [String] {
        [
            AppConfig.apiBaseURL,
            "http://127.0.0.1:9527",
            "http://192.168.1.100:9527",
        ]
    }

    private func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
            url.scheme == "http" || url.scheme == "https",
            url.host != nil
        else {
            return false
        }
        return true
    }
}

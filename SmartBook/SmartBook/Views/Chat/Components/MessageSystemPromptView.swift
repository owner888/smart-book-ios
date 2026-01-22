// MessageSystemPromptView.swift - 系统提示词组件

import SwiftUI

struct MessageSystemPromptView: View {
    let prompt: String
    var colors: ThemeColors
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text(L("chat.systemPrompt.title"))
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(colors.primaryText)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(prompt)
                    .font(.caption)
                    .foregroundColor(colors.secondaryText)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.05))
                )
        )
    }
}

// TypingIndicator.swift - 打字指示器

import SwiftUI

struct TypingIndicator: View {
    var colors: ThemeColors = .dark
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(colors.secondaryText.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TypingIndicator(colors: .light)
            .padding()
            .background(Color.white)

        TypingIndicator(colors: .dark)
            .padding()
            .background(Color.black)
    }
}

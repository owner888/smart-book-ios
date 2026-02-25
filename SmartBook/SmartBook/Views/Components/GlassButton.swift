//
//  GlassButton.swift
//  SmartBook
//
//  Created by Andrew on 2026/1/14.
//

import SwiftUI

extension Button {
    @ViewBuilder
    func glassEffect(size: CGSize = CGSize(width: 40, height: 40)) -> some View {
        if #available(iOS 26, *) {
            self.background {
                Color.white.opacity(0.001).frame(width: size.width, height: size.height).glassEffect(
                    .regular,
                    in: .rect(cornerRadius: size.height / 2)
                )
            }
        } else {
            self.background {
                GaussianBlurView()
                    .opacity(0.45)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: size.height / 2))
                    .overlay {
                        RoundedRectangle(cornerRadius: size.height / 2)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        Color.gray.opacity(0.18),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    }
            }
        }
    }

    @ViewBuilder
    func glassEffect(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, *) {
            self.background {
                Color.white.opacity(0.001).glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self.background {
                GaussianBlurView()
                    .opacity(0.5)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.32),
                                        Color.gray.opacity(0.16),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    }
            }
        }
    }
}

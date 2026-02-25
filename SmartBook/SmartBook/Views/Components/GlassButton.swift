//
//  GlassButton.swift
//  SmartBook
//
//  Created by Andrew on 2026/1/14.
//

import SwiftUI

struct GlassFallbackStyle {
    let cornerRadius: CGFloat
    let blurOpacity: CGFloat
    let grayOpacity: CGFloat?
    let frameSize: CGSize?
    let borderStops: [Gradient.Stop]
    let borderStartPoint: UnitPoint
    let borderEndPoint: UnitPoint
    let borderWidth: CGFloat

    static func iconButton(size: CGSize) -> GlassFallbackStyle {
        GlassFallbackStyle(
            cornerRadius: size.height / 2,
            blurOpacity: 0.45,
            grayOpacity: nil,
            frameSize: size,
            borderStops: [
                .init(color: Color.white.opacity(0.35), location: 0.0),
                .init(color: Color.gray.opacity(0.18), location: 1.0),
            ],
            borderStartPoint: .topLeading,
            borderEndPoint: .bottomTrailing,
            borderWidth: 0.8
        )
    }

    static func modelButton(cornerRadius: CGFloat) -> GlassFallbackStyle {
        GlassFallbackStyle(
            cornerRadius: cornerRadius,
            blurOpacity: 0.5,
            grayOpacity: nil,
            frameSize: nil,
            borderStops: [
                .init(color: Color.white.opacity(0.32), location: 0.0),
                .init(color: Color.gray.opacity(0.16), location: 1.0),
            ],
            borderStartPoint: .topLeading,
            borderEndPoint: .bottomTrailing,
            borderWidth: 0.8
        )
    }

    static func inputContainer(cornerRadius: CGFloat) -> GlassFallbackStyle {
        GlassFallbackStyle(
            cornerRadius: cornerRadius,
            blurOpacity: 0.5,
            grayOpacity: 0.18,
            frameSize: nil,
            borderStops: [
                .init(color: Color.white.opacity(0.18), location: 0.0),
                .init(color: Color.white.opacity(0.32), location: 0.5),
                .init(color: Color.white.opacity(0.18), location: 1.0),
            ],
            borderStartPoint: .topTrailing,
            borderEndPoint: .bottomLeading,
            borderWidth: 0.8
        )
    }
}

struct GlassFallbackBackground: View {
    let style: GlassFallbackStyle

    var body: some View {
        ZStack {
            if let grayOpacity = style.grayOpacity {
                Color.gray.opacity(grayOpacity)
            }

            GaussianBlurView()
                .opacity(style.blurOpacity)
        }
        .frame(width: style.frameSize?.width, height: style.frameSize?.height)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(stops: style.borderStops),
                        startPoint: style.borderStartPoint,
                        endPoint: style.borderEndPoint
                    ),
                    lineWidth: style.borderWidth
                )
        }
    }
}

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
                GlassFallbackBackground(style: .iconButton(size: size))
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
                GlassFallbackBackground(style: .modelButton(cornerRadius: cornerRadius))
            }
        }
    }
}

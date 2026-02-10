//
//  CustomMenuView.swift
//  Alist iOS
//
//  Created by Andrew on 2025/12/15.
//

import SwiftUI
import Combine


struct CustomMenuView<Label: View, Content: View>: View, Animatable {
    var alignment: Alignment
    var edgeInsets: EdgeInsets
    var labelSize = CGSizeMake(36, 36)
    var isOnlyDark = false
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label
    @EnvironmentObject private var obser: CustomMenuObservable
    @State private var contentSize = CGSize.zero


    var body: some View {
        let widthDiff = contentSize.width - labelSize.width
        let heightDiff = contentSize.height - labelSize.height
        let rWidth = widthDiff * contentOpacity
        let rHeight = heightDiff * contentOpacity
        return ZStack {
            GaussianBlurView().opacity(0.7).ignoresSafeArea().onTapGesture {
                closeAction()
            }
            ZStack(alignment: alignment) {
                content.background(content: {
                    GaussianBlurView().opacity(0.8)
                }).overlay(content: {
                    RoundedRectangle(cornerRadius: 24).stroke(
                        .gray.opacity(0.5),
                        lineWidth: 1
                    )
                }).clipShape(.rect(cornerRadius: 24)).scaleEffect(contentScale).blur(
                    radius: 14 * blurProgress
                ).opacity(contentOpacity)
                    .onGeometryChange(for: CGSize.self) {
                        $0.size
                    } action: { newValue in
                        contentSize = newValue
                    }.fixedSize().frame(
                        width: min(contentSize.width, labelSize.width + rWidth),
                        height: min(contentSize.height, labelSize.height + rHeight)
                    )
                label.blur(radius: 14 * blurProgress)
                    .opacity(1 - labelOpacity)
                    .frame(width: labelSize.width, height: labelSize.height)
            }.clipped().compositingGroup()
            .scaleEffect(
                x: 1 + (blurProgress * 0.35),
                y: 1 + (blurProgress * 0.45),
                anchor: scaleAnchor
            ).offset(y: offset * blurProgress).frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: alignment
            ).applyEdge(edgeInsets, alignment: alignment)
        }.opacity(obser.progress > 0.1 ? 1 : obser.progress / 0.1)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.3),
                {
                    obser.progress = 1.0
                }
            )
        }
    }
    
    func closeAction() {
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.25,
            execute: {
                obser.onClose?()
            }
        )
        withAnimation(
            .easeInOut(duration: 0.3),
            {
                obser.progress = 0
            }
        )
    }

    var labelOpacity: CGFloat {
        min(obser.progress / 0.35, 1)
    }

    var contentOpacity: CGFloat {
        max(obser.progress - 0.35, 0) / 0.65
    }

    var blurProgress: CGFloat {
        return obser.progress > 0.5 ? (1 - obser.progress) / 0.5 : obser.progress / 0.5
    }

    var contentScale: CGFloat {
        let minAspectScale = min(
            labelSize.width / contentSize.width,
            labelSize.height / contentSize.height
        )
        return minAspectScale + (1 - minAspectScale) * obser.progress
    }

    var scaleAnchor: UnitPoint {
        switch alignment {
        case .bottomTrailing: .bottomTrailing
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .top: .top
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .trailing: .trailing
        default: .center

        }
    }

    var offset: CGFloat {
        switch alignment {
        case .bottom, .bottomLeading, .bottomTrailing: return -75
        case .top, .topLeading, .topTrailing: return 75
        default: return 0
        }
    }

}

class CustomMenuObservable: ObservableObject {
    @Published var progress: CGFloat = 0
    var onClose: (() -> Void)?
    
    func willShow() {
        progress = 0
    }
    
    func close() {
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.25,
            execute: {
                self.onClose?()
            }
        )
        withAnimation(
            .easeInOut(duration: 0.3),
            {
                progress = 0
            }
        )
    }
}

private struct PopOverHelper<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var isVisible: Bool = false
    var body: some View {
        content.opacity(isVisible ? 1 : 0)
            .task {
                try? await Task.sleep(for: .seconds(0.1))
                withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    @ViewBuilder
    fileprivate func applyEdge(_ edge: EdgeInsets, alignment: Alignment)
    -> some View
    {
        switch alignment {
        case .bottomTrailing:
            self.padding(.bottom, edge.bottom).padding(.trailing, edge.trailing)
        case .topTrailing:
            self.padding(.top, edge.top).padding(.trailing, edge.trailing)
        case .topLeading:
            self.padding(.top,edge.top).padding(.leading,edge.leading)
        case .bottomLeading:
            self.padding(.bottom, edge.bottom).padding(.leading, edge.leading)
        default:
            self.padding()
        }
    }
}



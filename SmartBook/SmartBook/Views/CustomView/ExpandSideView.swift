//
//  ExpandMenuView.swift
//  SliderView
//
//  Created by Andrew on 2026/1/14.
//

import SwiftUI
import Combine
import UIKit

struct ExpandSideView<Side: View, Content: View>: View {
    @ViewBuilder var side: Side
    @ViewBuilder var content: Content

    @State private var scrollOffset: CGFloat = 0
    @State private var sideWidth: CGFloat = 1
    @EnvironmentObject private var obser: ExpandSideObservable
    @Environment(\.colorScheme) private var colorScheme

    var blurStyle: UIBlurEffect.Style {
        return colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader(content: { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ZStack {
                            side.background(content: {
                                GeometryReader { sideProxy in
                                    Color.clear.onAppear {
                                        sideWidth = sideProxy.size.width
                                    }
                                }
                            })
                            GaussianBlurView(style: blurStyle).opacity(
                                scrollOffset / sideWidth
                            ).ignoresSafeArea()
                        }.id(0)
                        ZStack {
                            content.frame(
                                width: proxy.size.width,
                                height: proxy.size.height
                            )
                            GaussianBlurView(style: blurStyle).opacity(
                                min(1.0 - scrollOffset / sideWidth, 0.8)
                            ).ignoresSafeArea().simultaneousGesture(
                                TapGesture().onEnded({ _ in
                                    obser.jumpToPage(1)
                                })
                            )
                        }.id(1)
                    }.background(
                        GeometryReader {
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: -$0.frame(in: .named("scroll")).origin
                                    .scrollOffset(.horizontal)
                            )
                        }
                    ).onPreferenceChange(ScrollOffsetPreferenceKey.self) {
                        scrollOffset = $0
                    }
                }
                .coordinateSpace(name: "scroll")
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $obser.currentPage)
                .onAppear(perform: {
                    obser.jumpToPage(1, animate: false)
                })
            })
        }
    }
}

class ExpandSideObservable: ObservableObject {
    @Published var currentPage: Int? = nil
    func jumpToPage(_ page: Int, animate: Bool = true) {
        if animate {
            withAnimation(.spring(duration: 0.25)) {
                currentPage = page
            }
        } else {
            currentPage = page
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

extension CGPoint {
    func scrollOffset(_ axes: Axis.Set) -> CGFloat {
        return axes == .vertical ? y : x
    }
}

struct ScrollBouncerDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            var parent = view.superview
            while parent != nil {
                if let scrollView = parent as? UIScrollView {
                    scrollView.bounces = false  // 彻底禁用
                    break
                }
                parent = parent?.superview
            }
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

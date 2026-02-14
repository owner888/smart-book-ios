//
//  ExpandMenuView.swift
//  SliderView
//
//  Created by Andrew on 2026/1/14.
//

import SwiftUI
import Combine
import UIKit
import SwiftUIIntrospect

struct ExpandSideView<Side: View, Content: View>: View {
    @ViewBuilder var side: Side
    @ViewBuilder var content: Content

    @State private var scrollOffset: CGFloat = 0
    @State private var sideWidth: CGFloat = 1
    @State private var expandScrollView: UIScrollView? = nil
    @State private var disabledScroll = false
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
                    }
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $obser.currentPage)
                .scrollDisabled(disabledScroll)
                .onScrollGeometryChange(for: CGFloat.self, of: { geo in
                    geo.contentOffset.x
                }, action: { _, newValue in
                    scrollOffset = newValue
                    obser.isMainPage = scrollOffset > sideWidth - 30
                })
                .introspect(.scrollView, on: .iOS(.v18,.v26)) { scrollView in
                    scrollView.bounces = false
                }
                .onAppear(perform: {
                    obser.jumpToPage(1, animate: false)
                }).onReceive(NotificationCenter.default.publisher(for: .disableExpandScroll)) { notificaion in
                    if let disable = notificaion.object as? Bool {
                        disabledScroll = disable
                    }
                }
            })
        }
    }
}

class ExpandSideObservable: ObservableObject {
    @Published var isMainPage = false
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

// MARK: - 滚动控制通知
extension Notification.Name {
    static let disableExpandScroll = Notification.Name("disableExpandScroll")
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


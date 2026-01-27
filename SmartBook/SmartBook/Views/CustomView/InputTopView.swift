//
//  InputTopView.swift
//  SmartBook
//
//  Created by Andrew on 2026/1/18.
//

import SwiftUI

struct InputTopView: View {

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var themeManager = ThemeManager.shared
    @State private var position = ScrollPosition()
    @State private var scrollOffset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var scrollWidth: CGFloat = 0

    private let space: CGFloat = 100.0

    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }

    var action: (MenuConfig.TopFunctionType) -> Void

    var body: some View {
        let functions = MenuConfig.topFunctions
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: space, height: 1)
                HStack(spacing:12) {
                    ForEach(0..<functions.count, id: \.self) { i in
                        button(functions[i])
                    }
                }
                Color.clear
                    .frame(width: space, height: 1)
            }
        }.scrollPosition($position).onAppear {
            position.scrollTo(x: space)
        }.onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentSize.width
        } action: { oldValue, newValue in
            contentWidth = newValue
        }.onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.x
        } action: { oldValue, newValue in
            if newValue < space {
                position.scrollTo(x: space)
            }
            let maxOffset = contentWidth - scrollWidth - space
            if newValue > maxOffset {
                position.scrollTo(x: maxOffset)
            }
            scrollOffset = newValue
        }.onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.containerSize.width
        } action: { oldValue, newValue in
            scrollWidth = newValue
        }
    }

    func button(_ type: MenuConfig.TopFunctionType) -> some View {
        let isGet = type == .getSuper
        return Button {
            action(type)
        } label: {
            HStack(spacing: 8) {
                MenuIcon(
                    config: type.config,
                    size: 18,
                    color: isGet ? colors.accentColor : .apprBlack
                ).opacity(isGet ? 1 : 0.6)
                Text(type.config.title).foregroundStyle(
                    isGet ? colors.accentColor : .apprBlack
                )
            }.padding(.all, 14).background {
                if #available(iOS 26, *) {
                    if isGet {
                        Color.clear.glassEffect(.clear.tint(colors.accentColor.opacity(0.2)),in:.rect(cornerRadius: 22))
                    } else {
                        Color.clear.glassEffect(.regular, in:.rect(cornerRadius: 22))
                    }
                } else {
                    Group {
                        if isGet {
                            colors.accentColor.opacity(0.2)
                        } else {
                            Color.apprBlack.opacity(0.1)
                        }
                    }.clipShape(RoundedRectangle(cornerRadius: 22))
                }
            }
        }

    }
}

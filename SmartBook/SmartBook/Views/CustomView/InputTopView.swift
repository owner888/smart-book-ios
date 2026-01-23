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
    
    private var colors: ThemeColors {
        themeManager.colors(for: systemColorScheme)
    }
    
    var action: (MenuConfig.TopFunctionType) -> Void
    
    var body: some View {
        let functions = MenuConfig.topFunctions
        return ScrollView(.horizontal,showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<functions.count, id:\.self) { i in
                    button(functions[i])
                }
            }
        }
    }
    
    func button(_ type: MenuConfig.TopFunctionType) -> some View {
        let isGet = type == .getSuper
        return Button {
            action(type)
        } label: {
            HStack(spacing: 8) {
                MenuIcon(config: type.config,size: 18,color: isGet ? colors.accentColor : .apprBlack).opacity(isGet ? 1 : 0.6)
                Text(type.config.title).foregroundStyle(isGet ? colors.accentColor : .apprBlack)
            }.padding(.all,14).background {
                if isGet {
                    colors.accentColor.opacity(0.2)
                } else {
                    Color.apprBlack.opacity(0.1)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 22))
        }

    }
}

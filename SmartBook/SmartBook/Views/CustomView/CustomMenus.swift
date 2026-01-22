// CustomMenus.swift - 自定义菜单组件

import SwiftUI

// MARK: - 媒体菜单
struct MediaMenu: View {
    var onSelected: (MenuConfig.MediaMenuType) -> Void
    private let configs = MenuConfig.medias
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    menuItem(configs[i])
                }
            }
            Color.apprBlack.opacity(0.15).frame(height: 0.5).padding(.horizontal, 12).padding(.vertical, 5)
            VStack(spacing: 4) {
                ForEach(3..<5, id: \.self) { i in
                    menuItem(configs[i])
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    func menuItem(_ type: MenuConfig.MediaMenuType) -> some View {
        Button {
            onSelected(type)
        } label: {
            HStack(spacing: 15) {
                Color.apprBlack.frame(width: 32, height: 32).opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 16)).overlay {
                    MenuIcon(config: type.config)
                }
                Text(type.config.title).font(.headline).foregroundStyle(Color.apprBlack)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - AI 功能菜单
struct AIFunctionMenu: View {
    @Binding var currentFunc: MenuConfig.AIModelFunctionType
    var action: (MenuConfig.AIModelFunctionType) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 3) {
                upgradeView
                Color.apprBlack.frame(height: 0.5).opacity(0.15).padding(.horizontal, 12)
                ForEach(0..<MenuConfig.aiFunctions.count, id: \.self) { i in
                    menuItem(MenuConfig.aiFunctions[i])
                }
            }
            .padding(.all, 6)
        }
        .frame(height: 332)
    }
    
    var upgradeView: some View {
        let config = MenuConfig.AIModelFunctionType.super.config
        return Button {
            action(.super)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        MenuIcon(config: config, size: 20)
                        Text(config.title).font(.title3).bold().foregroundStyle(.apprBlack).opacity(0.8)
                    }
                    Text(config.summary ?? "").font(.caption).foregroundStyle(.apprBlack).opacity(0.3)
                }
                Text(L("menu.upgrade")).font(.headline).foregroundStyle(.apprWhite).padding(.horizontal, 12).padding(.vertical, 8).background {
                    Color.apprBlack.clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
    }
    
    func menuItem(_ type: MenuConfig.AIModelFunctionType) -> some View {
        let config = type.config
        let isSelected = type == currentFunc
        return Button {
            action(type)
        } label: {
            HStack(spacing: 12) {
                MenuIcon(config: config)
                VStack(alignment: .leading, spacing: 5) {
                    Text(config.title).foregroundStyle(.apprBlack).opacity(0.8)
                    Text(config.summary ?? "").font(.caption).foregroundStyle(.apprBlack).opacity(0.5)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").resizable().scaledToFit().foregroundStyle(.apprBlack).frame(width: 16, height: 16)
                }
            }
            .padding(.all, 12)
            .background {
                if isSelected {
                    Color.apprBlack.opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Color.white.opacity(0.001)
                }
            }
        }
        .buttonStyle(MenuButtonStyle())
    }
}

// MARK: - 菜单图标
struct MenuIcon: View {
    var config: MenuConfig.Config
    var size: CGFloat = 14
    var color: Color = Color.apprBlack
    
    var body: some View {
        Group {
            if config.builtIn {
                Image(systemName: config.icon).resizable().scaledToFit()
            } else {
                Image(config.icon).resizable().renderingMode(.template).scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(color)
    }
}

// MARK: - 菜单按钮样式
struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

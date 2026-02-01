//
//  VIPUpgradeView.swift
//  SmartBook
//
//  Created by Cline on 2026/1/27.
//

import SwiftUI

struct VIPUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // 标题区域
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 60)) // 装饰性大图标
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text(L("vip.title"))
                        .font(.title)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text(L("vip.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(.top, 20)
                
                // 功能列表 - 卡片样式
                VStack(spacing: 14) {
                    FeatureRow(
                        icon: "brain",
                        iconColor: .purple,
                        title: L("vip.feature.pro.title"),
                        description: L("vip.feature.pro.desc")
                    )
                    
                    FeatureRow(
                        icon: "sparkles",
                        iconColor: .orange,
                        title: L("vip.feature.unlimited.title"),
                        description: L("vip.feature.unlimited.desc")
                    )
                    
                    FeatureRow(
                        icon: "clock.arrow.circlepath",
                        iconColor: .green,
                        title: L("vip.feature.priority.title"),
                        description: L("vip.feature.priority.desc")
                    )
                    
                    FeatureRow(
                        icon: "doc.text.magnifyingglass",
                        iconColor: .blue,
                        title: L("vip.feature.context.title"),
                        description: L("vip.feature.context.desc")
                    )
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal)
                    
                // 价格区域
                VStack(spacing: 8) {
                    Text(L("vip.price"))
                        .font(.title).fontWeight(.bold) // 大标题 - 动态字号
                    
                    Text(L("vip.trial"))
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
                
                // 订阅按钮
                Button {
                    // TODO: 实现订阅逻辑
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.headline)
                        Text(L("vip.subscribe"))
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // 说明文本
                Text(L("vip.cancelAnytime"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer(minLength: 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// 按钮缩放样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// 功能行组件
struct FeatureRow: View {
    let icon: String
    var iconColor: Color = .blue
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    VIPUpgradeView()
}

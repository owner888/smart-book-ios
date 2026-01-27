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
            ScrollView {
                VStack(spacing: 30) {
                    // 标题区域
                    VStack(spacing: 12) {
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.yellow)
                        
                        Text("升级到 SmartBook Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("解锁更强大的AI模型和功能")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // 功能列表
                    VStack(spacing: 20) {
                        FeatureRow(
                            icon: "brain",
                            title: "Gemini 2.5 Pro",
                            description: "最强大的AI模型，适合复杂任务"
                        )
                        
                        FeatureRow(
                            icon: "sparkles",
                            title: "无限制对话",
                            description: "不再受日常使用次数限制"
                        )
                        
                        FeatureRow(
                            icon: "clock.arrow.circlepath",
                            title: "优先响应",
                            description: "更快的AI响应速度"
                        )
                        
                        FeatureRow(
                            icon: "doc.text.magnifyingglass",
                            title: "更大上下文",
                            description: "支持更长的对话历史"
                        )
                    }
                    .padding(.horizontal)
                    
                    // 价格区域
                    VStack(spacing: 16) {
                        Text("¥58/月")
                            .font(.system(size: 48, weight: .bold))
                        
                        Text("首月 5 折优惠")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.yellow.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 20)
                    
                    // 订阅按钮
                    Button {
                        // TODO: 实现订阅逻辑
                    } label: {
                        Text("立即订阅")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                    
                    // 说明文本
                    Text("订阅后可随时取消")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
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

// 功能行组件
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    VIPUpgradeView()
}

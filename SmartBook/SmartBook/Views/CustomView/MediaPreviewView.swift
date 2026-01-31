//
//  MediaPreviewView.swift
//  SmartBook
//
//  选中媒体的预览视图
//

import SwiftUI

// MARK: - 媒体预览视图
struct MediaPreviewView: View {
    let image: UIImage
    var onRemove: () -> Void
    
    var body: some View {
        // 图片缩略图
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                // 删除按钮
                Button(action: onRemove) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .offset(x: 8, y: -8)
            }
    }
}

// MARK: - 文档预览视图
struct DocumentPreviewView: View {
    let fileName: String
    var onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 文件图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "doc.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            
            // 文件名
            Text(fileName)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // 删除按钮
            Button(action: onRemove) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

// MARK: - 预览示例
#Preview("Image Preview") {
    VStack {
        Spacer()
        
        MediaPreviewView(
            image: UIImage(systemName: "photo")!,
            onRemove: {}
        )
        .padding()
        
        Spacer()
    }
    .background(Color.black)
}

#Preview("Document Preview") {
    VStack {
        Spacer()
        
        DocumentPreviewView(
            fileName: "document.pdf",
            onRemove: {}
        )
        .padding()
        
        Spacer()
    }
    .background(Color.black)
}

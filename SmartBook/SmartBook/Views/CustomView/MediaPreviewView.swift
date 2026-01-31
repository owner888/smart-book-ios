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
    
    // 获取文件扩展名
    private var fileExtension: String {
        let ext = (fileName as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "FILE" : ext
    }
    
    var body: some View {
        ZStack {
            // 80x80的背景方块
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
            
            // 文档图标（居中）
            Image(systemName: "doc.text.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.9))
            
            // 文件类型标签（底部）
            VStack {
                Spacer()
                Text(fileExtension)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 80, height: 80)
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

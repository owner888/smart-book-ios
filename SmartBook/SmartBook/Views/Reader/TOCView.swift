// TOCView.swift - 目录视图

import SwiftUI

struct TOCView: View {
    let chapters: [EPUBChapter]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        onSelect(index)
                    } label: {
                        HStack {
                            Text(chapter.title)
                                .foregroundColor(index == currentIndex ? .blue : .primary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            if index == currentIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

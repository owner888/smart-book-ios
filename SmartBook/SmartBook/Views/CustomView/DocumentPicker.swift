//
//  DocumentPicker.swift
//  SmartBook
//
//  文档选择器 - 支持选择各种文件类型
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var allowedTypes: [UTType]
    var onDocumentPicked: (URL) -> Void
    var onMultipleDocumentsPicked: (([URL]) -> Void)? = nil
    var allowsMultipleSelection: Bool = false
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowsMultipleSelection
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard !urls.isEmpty else { return }
            
            // 如果只选择了一个，使用单个回调
            if urls.count == 1, let url = urls.first {
                parent.onDocumentPicked(url)
            } else if let multipleCallback = parent.onMultipleDocumentsPicked {
                // 多个文档，使用多选回调
                multipleCallback(urls)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Document Type Extensions
extension DocumentPicker {
    // 预定义的常用文档类型
    static let allDocuments: [UTType] = [
        .pdf,
        .text,
        .plainText,
        .rtf,
        .html,
        .xml,
        .sourceCode,
        .data,
        .content
    ]
    
    static let images: [UTType] = [
        .image,
        .jpeg,
        .png,
        .heic,
        .gif
    ]
    
    static let ebooks: [UTType] = [
        UTType(filenameExtension: "epub") ?? .data,
        UTType(filenameExtension: "mobi") ?? .data,
        UTType(filenameExtension: "azw") ?? .data,
        UTType(filenameExtension: "azw3") ?? .data,
        .pdf
    ]
}

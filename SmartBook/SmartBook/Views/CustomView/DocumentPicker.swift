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
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
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
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
            parent.presentationMode.wrappedValue.dismiss()
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

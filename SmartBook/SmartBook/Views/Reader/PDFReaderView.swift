// PDFReaderView.swift - PDF 阅读器视图
// 使用 iOS 原生 PDFKit 显示 PDF

import PDFKit
import SwiftUI

struct PDFReaderView: View {
    let pdfURL: URL

    var body: some View {
        PDFKitView(url: pdfURL)
            .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - PDFKit UIViewRepresentable

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()

        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        // 设置背景色
        pdfView.backgroundColor = .systemBackground

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // PDF 不需要更新
    }
}

#Preview {
    if let sampleURL = Bundle.main.url(forResource: "sample", withExtension: "pdf") {
        PDFReaderView(pdfURL: sampleURL)
    } else {
        Text("No sample PDF found")
    }
}

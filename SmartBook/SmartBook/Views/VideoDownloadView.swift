import SwiftUI
import Photos
import UniformTypeIdentifiers

struct VideoDownloadView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var inputURL = ""
    @State private var model: VideoDownloadModel?
    @State private var isParsing = false
    @State private var isDownloading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var downloadProgress: [String: Int] = [:]
    @State private var lastDownloadedPath: String?
    @State private var lastDownloadedItem: VideoDownloadItem?
    @State private var exportDocument: DownloadedFileDocument?
    @State private var showFileExporter = false

    private let service = VideoDownloadService()

    var body: some View {
        List {
            Section(L("videoDownload.section.link")) {
                TextField(L("videoDownload.input.placeholder"), text: $inputURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task {
                        await parseURL()
                    }
                } label: {
                    if isParsing {
                        HStack {
                            ProgressView()
                            Text(L("videoDownload.parsing"))
                        }
                    } else {
                        Text(L("videoDownload.parse"))
                    }
                }
                .disabled(inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)
            }

            if let model {
                Section(L("videoDownload.section.info")) {
                    if let title = model.title, !title.isEmpty {
                        Text(title)
                    }
                    if let duration = model.videoDuration, !duration.isEmpty {
                        Text(String(format: L("videoDownload.info.duration"), duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(String(format: L("videoDownload.info.count"), model.videoList.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(L("videoDownload.section.list")) {
                    if model.videoList.isEmpty {
                        Text(L("videoDownload.list.empty"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.videoList, id: \.href) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .font(.subheadline)
                                Text(item.href)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)

                                let progress = downloadProgress[item.href]
                                if let progress {
                                    if progress >= 0 {
                                        ProgressView(value: Double(progress), total: 100)
                                        Text("\(progress)%")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ProgressView()
                                        Text(L("videoDownload.downloading"))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Button {
                                    Task {
                                        await download(item)
                                    }
                                } label: {
                                    Text(progress == 100 ? L("videoDownload.button.downloaded") : L("videoDownload.button.download"))
                                }
                                .disabled(isDownloading)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            if let path = lastDownloadedPath {
                Section(L("videoDownload.section.recent")) {
                    Text(path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let item = lastDownloadedItem {
                        if item.isVideo || item.isPhoto {
                            Button(L("videoDownload.button.saveToPhotos")) {
                                Task {
                                    await saveToPhotos()
                                }
                            }
                        }

                        Button(L("videoDownload.button.saveToFiles")) {
                            do {
                                guard let path = lastDownloadedPath else { return }
                                exportDocument = try DownloadedFileDocument(url: URL(fileURLWithPath: path))
                                showFileExporter = true
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }

            if let successMessage {
                Section(L("common.success")) {
                    Text(successMessage)
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            if let errorMessage {
                Section(L("common.error")) {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(L("videoDownload.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("common.close")) {
                    dismiss()
                }
            }
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportDocument,
            contentType: .data,
            defaultFilename: suggestedFileName
        ) { result in
            switch result {
            case .success:
                successMessage = L("videoDownload.message.savedToFiles")
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func parseURL() async {
        errorMessage = nil
        successMessage = nil
        model = nil
        isParsing = true
        defer { isParsing = false }

        do {
            model = try await service.fetchVideoDownload(inputURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func download(_ item: VideoDownloadItem) async {
        errorMessage = nil
        successMessage = nil
        isDownloading = true
        defer { isDownloading = false }

        do {
            let localURL = try await service.downloadMedia(item) { progress in
                Task { @MainActor in
                    downloadProgress[item.href] = progress
                }
            }
            downloadProgress[item.href] = 100
            lastDownloadedPath = localURL.path
            lastDownloadedItem = item
            successMessage = L("videoDownload.message.downloadCompleted")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveToPhotos() async {
        guard let path = lastDownloadedPath, let item = lastDownloadedItem else { return }

        let status = await requestPhotoPermission()
        guard status == .authorized || status == .limited else {
            errorMessage = L("videoDownload.message.noPhotoPermission")
            return
        }

        do {
            let url = URL(fileURLWithPath: path)
            try await saveAsset(url: url, isVideo: item.isVideo)
            successMessage = L("videoDownload.message.savedToPhotos")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var suggestedFileName: String {
        guard let path = lastDownloadedPath else { return "video_download" }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func requestPhotoPermission() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if current == .notDetermined {
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    continuation.resume(returning: status)
                }
            }
        }
        return current
    }

    private func saveAsset(url: URL, isVideo: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.creationDate = Date()

                if isVideo {
                    request.addResource(with: .video, fileURL: url, options: nil)
                } else {
                    request.addResource(with: .photo, fileURL: url, options: nil)
                }
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "VideoDownload", code: -1))
                }
            }
        }
    }
}

struct DownloadedFileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.data]

    var fileData: Data

    init(url: URL) throws {
        self.fileData = try Data(contentsOf: url)
    }

    init(configuration: ReadConfiguration) throws {
        self.fileData = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: fileData)
    }
}

import Foundation

struct TwitterVideoModel: Codable {
    var status: String?
    var data: String?
    var videoCover: String?
    var title: String?
    var videoDuration: String?
    var videoList: [TwitterVideoItem]

    var isSuccess: Bool {
        status?.lowercased() == "ok"
    }

    enum CodingKeys: String, CodingKey {
        case status
        case data
        case videoCover
        case title
        case videoDuration
        case videoList
    }

    init(
        status: String? = nil,
        data: String? = nil,
        videoCover: String? = nil,
        title: String? = nil,
        videoDuration: String? = nil,
        videoList: [TwitterVideoItem] = []
    ) {
        self.status = status
        self.data = data
        self.videoCover = videoCover
        self.title = title
        self.videoDuration = videoDuration
        self.videoList = videoList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        data = try container.decodeIfPresent(String.self, forKey: .data)
        videoCover = try container.decodeIfPresent(String.self, forKey: .videoCover)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        videoDuration = try container.decodeIfPresent(String.self, forKey: .videoDuration)
        videoList = try container.decodeIfPresent([TwitterVideoItem].self, forKey: .videoList) ?? []
    }
}

struct TwitterVideoItem: Codable, Hashable {
    var href: String
    var title: String

    var isVideo: Bool {
        title.lowercased().contains("mp4")
    }

    var isAudio: Bool {
        title.lowercased().contains("mp3")
    }

    var isPhoto: Bool {
        title.lowercased().contains("photo")
    }

    init(href: String, title: String) {
        self.href = href
        self.title = title
    }
}

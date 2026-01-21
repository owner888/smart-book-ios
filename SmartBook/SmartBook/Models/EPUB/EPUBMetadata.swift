// EPUBMetadata.swift - EPUB 元数据

import Foundation
import UIKit

/// EPUB 元数据
struct EPUBMetadata {
    var title: String?
    var author: String?
    var publisher: String?
    var language: String?
    var description: String?
    var coverImage: UIImage?
    var localCoverPath: String?
}

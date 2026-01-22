// MenuConfig.swift - 菜单配置

import Foundation

class MenuConfig {
    static let medias: [MediaMenuType] = [.camera, .photo, .file, .createPhoto, .editPhoto]
    static let aiFunctions: [AIModelFunctionType] = [.heavy, .expert, .fast, .auto, .thinking]
    static let topFunctions: [TopFunctionType] = [.getSuper, .createVideo, .editPhoto, .voiceMode, .camera, .analysisDocument, .custom]
    
    struct Config {
        var icon: String
        var title: String
        var summary: String? = nil
        var builtIn: Bool = true  // icon是否内置
    }
    
    // MARK: - 媒体菜单类型
    
    enum MediaMenuType {
        case camera
        case photo
        case file
        case createPhoto
        case editPhoto
        
        var config: Config {
            switch self {
            case .camera:
                return Config(icon: "camera", title: "摄像头")
            case .photo:
                return Config(icon: "photo.on.rectangle.angled", title: "照片")
            case .file:
                return Config(icon: "document", title: "文件")
            case .createPhoto:
                return Config(icon: "photo.badge.plus", title: "创作图片")
            case .editPhoto:
                return Config(icon: "square.and.pencil", title: "编辑图像")
            }
        }
    }
    
    // MARK: - AI 模型功能类型
    
    enum AIModelFunctionType: Equatable {
        case `super`
        case heavy
        case expert
        case fast
        case auto
        case thinking
        
        var config: Config {
            switch self {
            case .super:
                return Config(icon: "bolt.circle", title: "Super", summary: L("ai.super.summary"))
            case .heavy:
                return Config(icon: "square.grid.2x2", title: "Heavy", summary: "Team of experts")
            case .expert:
                return Config(icon: "lightbulb.max", title: "Expert", summary: "Thinks hard")
            case .fast:
                return Config(icon: "bolt", title: "Fast", summary: "Quick responses by 4.1")
            case .auto:
                return Config(icon: "airplane", title: "Auto", summary: "Chooses Fast or Expert")
            case .thinking:
                return Config(icon: "moon", title: "4.1 Thinking", summary: "Thinks fast")
            }
        }
    }
    
    // MARK: - 顶部功能类型
    
    enum TopFunctionType {
        case getSuper
        case createVideo
        case editPhoto
        case voiceMode
        case camera
        case analysisDocument
        case custom
        
        var config: Config {
            switch self {
            case .getSuper:
                return Config(icon: "bolt.circle", title: L("menu.top.getSuper"))
            case .createVideo:
                return Config(icon: "photo.badge.plus", title: L("menu.top.createVideo"))
            case .editPhoto:
                return Config(icon: "square.and.pencil", title: L("menu.top.editPhoto"))
            case .voiceMode:
                return Config(icon: "waveform", title: L("menu.top.voiceMode"))
            case .camera:
                return Config(icon: "camera", title: L("menu.top.camera"))
            case .analysisDocument:
                return Config(icon: "document", title: L("menu.top.analysisDocument"))
            case .custom:
                return Config(icon: "slider.horizontal.3", title: L("menu.top.custom"))
            }
        }
    }
}

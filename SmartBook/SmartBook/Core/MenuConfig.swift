// MenuConfig.swift - 菜单配置

import Foundation

class MenuConfig {
    static let medias: [MediaMenuType] = [.camera, .photo, .file, .createPhoto, .editPhoto]
    
    // AI 模型配置（动态从服务器加载）
    @MainActor
    static var aiFunctions: [AIModelFunctionType] = [.heavy, .expert, .fast, .auto, .thinking]
    
    // 助手配置（动态从服务器加载）
    @MainActor
    static var assistants: [AssistantType] = [.chat, .book, .continue]
    
    static let topFunctions: [TopFunctionType] = [.getSuper, .createVideo, .editPhoto, .voiceMode, .camera, .analysisDocument, .custom]
    
    struct Config {
        var icon: String
        var title: String
        var summary: String? = nil
        var builtIn: Bool = true  // icon是否内置
    }
    
    // MARK: - 动态加载助手
    
    /// 从服务器加载助手配置
    @MainActor
    static func loadAssistants() async {
        do {
            let assistantService = AssistantService.shared
            try await assistantService.loadAssistants()
            
            // 将助手转换为 AssistantType
            assistants = assistantService.assistants.map { assistant in
                let dynamicAssistant: DynamicAssistant = (
                    id: assistant.id,
                    name: assistant.name,
                    avatar: assistant.avatar
                )
                return .dynamic(dynamicAssistant)
            }
        } catch {
            // 保留静态默认值
            assistants = [.chat, .book, .continue]
        }
    }
    
    // MARK: - 动态加载 AI 模型
    
    /// 从服务器加载 AI 模型配置
    @MainActor
    static func loadAIModels() async {
        do {
            // 使用 ChatService 的单例 ModelService
            let modelService = ModelService.shared
            try await modelService.loadModels()
            
            // 将模型转换为 AIModelFunctionType
            aiFunctions = modelService.models.map { model in
                // 根据 rate 映射图标
                let icon: String
                switch model.rate {
                case "0x":
                    icon = "bolt"  // 免费最快
                case let r where r.hasPrefix("0."):
                    icon = "hare"  // 轻量级
                case "1x":
                    icon = "lightbulb.max"  // 专家
                case let r where r.hasPrefix("2") || r.hasPrefix("3"):
                    icon = "brain"  // 超级
                default:
                    icon = "cpu"
                }
                
                let dynamicModel: DynamicAIModel = (
                    id: model.id,
                    name: model.name,
                    icon: icon,
                    summary: model.description ?? "Rate: \(model.rate)"
                )
                return .dynamic(dynamicModel)
            }
            
            print("✅ 成功加载 \(modelService.models.count) 个 AI 模型")
        } catch {
            print("⚠️ 加载 AI 模型失败，使用默认配置: \(error.localizedDescription)")
            // 保留静态默认值
            aiFunctions = [.heavy, .expert, .fast, .auto, .thinking]
        }
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
                return Config(icon: "camera", title: L("menu.media.camera"))
            case .photo:
                return Config(icon: "photo.on.rectangle.angled", title: L("menu.media.photo"))
            case .file:
                return Config(icon: "document", title: L("menu.media.file"))
            case .createPhoto:
                return Config(icon: "photo.badge.plus", title: L("menu.media.createPhoto"))
            case .editPhoto:
                return Config(icon: "square.and.pencil", title: L("menu.media.editPhoto"))
            }
        }
    }
    
    // MARK: - AI 模型功能类型
    
    // 类型别名，避免命名歧义
    typealias DynamicAIModel = (id: String, name: String, icon: String, summary: String)
    
    enum AIModelFunctionType: Equatable {
        case `super`
        case heavy
        case expert
        case fast
        case auto
        case thinking
        case dynamic(DynamicAIModel)  // 从服务器动态加载的模型
        
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
            case .dynamic(let dynamicModel):
                // 使用元组的 name 字段作为 title
                return Config(
                    icon: dynamicModel.icon,
                    title: dynamicModel.name,
                    summary: dynamicModel.summary
                )
            }
        }
        
        // 获取模型ID（用于API调用）
        var modelId: String {
            switch self {
            case .super:
                return "gemini-2.5-pro"
            case .heavy:
                return "gemini-2.5-pro"
            case .expert:
                return "gemini-2.5-flash"
            case .fast:
                return "gemini-2.5-flash-lite"
            case .auto:
                return "gemini-2.5-flash"
            case .thinking:
                return "gemini-2.5-flash"
            case .dynamic(let model):
                return model.id
            }
        }
        
        // Equatable conformance
        static func == (lhs: AIModelFunctionType, rhs: AIModelFunctionType) -> Bool {
            switch (lhs, rhs) {
            case (.super, .super),
                 (.heavy, .heavy),
                 (.expert, .expert),
                 (.fast, .fast),
                 (.auto, .auto),
                 (.thinking, .thinking):
                return true
            case (.dynamic(let lModel), .dynamic(let rModel)):
                return lModel.id == rModel.id
            default:
                return false
            }
        }
    }
    
    // MARK: - 助手类型
    
    // 类型别名
    typealias DynamicAssistant = (id: String, name: String, avatar: String)
    
    enum AssistantType: Equatable {
        case chat
        case book
        case `continue`
        case dynamic(DynamicAssistant)  // 从服务器动态加载的助手
        
        var config: Config {
            switch self {
            case .chat:
                return Config(icon: "💬", title: "通用聊天", builtIn: false)
            case .book:
                return Config(icon: "📚", title: "书籍问答", builtIn: false)
            case .continue:
                return Config(icon: "✍️", title: "续写小说", builtIn: false)
            case .dynamic(let assistant):
                return Config(
                    icon: assistant.avatar,
                    title: assistant.name,
                    builtIn: false
                )
            }
        }
        
        // 获取助手ID（用于API调用）
        var assistantId: String {
            switch self {
            case .chat:
                return ""
            case .book:
                return "book-qa"
            case .continue:
                return "novel-continue"
            case .dynamic(let assistant):
                return assistant.id
            }
        }
        
        // Equatable conformance
        static func == (lhs: AssistantType, rhs: AssistantType) -> Bool {
            switch (lhs, rhs) {
            case (.chat, .chat),
                 (.book, .book),
                 (.continue, .continue):
                return true
            case (.dynamic(let lAssistant), .dynamic(let rAssistant)):
                return lAssistant.id == rAssistant.id
            default:
                return false
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

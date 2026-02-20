// ChatViewModelTests.swift - ChatViewModel 单元测试

import XCTest

@testable import SmartBook

final class ChatViewModelTests: XCTestCase {

    var viewModel: ChatViewModel!
    var mockBookState: BookState!

    @MainActor
    override func setUpWithError() throws {
        viewModel = ChatViewModel()
        mockBookState = BookState()
        viewModel.bookState = mockBookState
    }

    @MainActor
    override func tearDownWithError() throws {
        viewModel = nil
        mockBookState = nil
    }

    // MARK: - 初始化测试

    @MainActor
    func testInitialState() {
        // Then: 初始状态应该正确
        XCTAssertTrue(viewModel.messages.isEmpty, "初始消息列表应该为空")
        XCTAssertFalse(viewModel.isLoading, "初始不应该在加载中")
        XCTAssertNil(viewModel.currentMessageId, "初始不应该有问题消息ID")
    }

    // MARK: - 消息发送测试

    func testSendMessage() async {
        // Given: ViewModel 已初始化
        let testMessage = "你好，测试消息"

        // When: 发送消息
        await viewModel.sendMessage(testMessage)

        // Then: 消息列表应该包含用户消息
        XCTAssertFalse(viewModel.messages.isEmpty, "消息列表不应该为空")
        XCTAssertEqual(viewModel.messages.first?.role, .user, "第一条消息应该是用户消息")
        XCTAssertEqual(viewModel.messages.first?.content, testMessage, "消息内容应该匹配")
    }

    func testSendEmptyMessage() async {
        // Given: ViewModel 已初始化
        let emptyMessage = ""

        // When: 发送空消息
        await viewModel.sendMessage(emptyMessage)

        // Then: 消息列表应该为空（空消息不应该被发送）
        XCTAssertTrue(viewModel.messages.isEmpty, "空消息不应该被添加")
    }

    // MARK: - 消息历史测试

    func testMessageHistory() async {
        // Given: 发送多条消息
        await viewModel.sendMessage("第一条消息")
        await viewModel.sendMessage("第二条消息")
        await viewModel.sendMessage("第三条消息")

        // Then: 消息历史应该按顺序保存
        XCTAssertGreaterThanOrEqual(viewModel.messages.count, 3, "应该至少有3条用户消息")

        // 验证消息顺序
        let userMessages = viewModel.messages.filter { $0.role == .user }
        XCTAssertEqual(userMessages[0].content, "第一条消息")
        XCTAssertEqual(userMessages[1].content, "第二条消息")
        XCTAssertEqual(userMessages[2].content, "第三条消息")
    }

    // MARK: - 清空消息测试

    func testClearMessages() async {
        // Given: 有一些消息
        await viewModel.sendMessage("测试消息")
        XCTAssertFalse(viewModel.messages.isEmpty, "发送前应该有消息")

        // When: 清空消息
        viewModel.clearMessages()

        // Then: 消息列表应该为空
        XCTAssertTrue(viewModel.messages.isEmpty, "清空后消息列表应该为空")
    }

    // MARK: - 书籍上下文测试

    @MainActor
    func testSendMessageWithBook() async {
        // Given: 选择了一本书
        let testBook = Book(
            id: "test_book_id",
            title: "测试书籍",
            author: "测试作者",
            coverURL: nil,
            filePath: nil,
            addedDate: Date()
        )
        mockBookState.selectedBook = testBook

        // When: 发送消息
        await viewModel.sendMessage("关于这本书的问题")

        // Then: 消息应该包含书籍上下文
        XCTAssertFalse(viewModel.messages.isEmpty, "应该有消息")
        // 注意: 这里需要根据实际实现验证书籍上下文是否被使用
    }

    // MARK: - 错误处理测试

    func testErrorHandling() async {
        // Given: 模拟网络错误场景
        // 注意: 这需要能够注入 mock 的 ChatService

        // When: 发送消息时发生错误
        // await viewModel.sendMessage("测试消息")

        // Then: 应该设置错误信息
        // XCTAssertNotNil(viewModel.errorMessage, "应该有错误信息")

        // 注意: 这个测试需要依赖注入来实现
    }

    // MARK: - 加载状态测试

    func testLoadingState() async {
        // Given: ViewModel 已初始化
        XCTAssertFalse(viewModel.isLoading, "初始不应该在加载中")

        // When: 发送消息（在发送过程中检查）
        // 注意: 这需要在异步操作中间检查状态，较难测试

        // Then: 加载完成后应该不在加载中
        await viewModel.sendMessage("测试")
        // 最终状态应该是不加载
        XCTAssertFalse(viewModel.isLoading, "完成后不应该在加载中")
    }

    // MARK: - 性能测试

    func testSendMessagePerformance() {
        measure {
            Task {
                await viewModel.sendMessage("性能测试消息")
            }
        }
    }

    func testMultipleMessagesPerformance() {
        measure {
            Task {
                for i in 1...10 {
                    await viewModel.sendMessage("消息 \(i)")
                }
            }
        }
    }
}

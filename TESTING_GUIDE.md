### 📋 SmartBook iOS 测试指南

---

## 🎯 测试概览

本文档提供 SmartBook iOS 项目的完整测试指南，包括单元测试、UI测试和集成测试。

---

## 📦 已创建的测试文件

### 1. BookServiceTests.swift
**测试范围**: 书籍服务
- ✅ 书籍加载
- ✅ 书籍导入
- ✅ 书籍删除
- ✅ 书籍搜索
- ✅ 阅读统计
- ✅ 性能测试

### 2. ChatViewModelTests.swift
**测试范围**: 聊天视图模型
- ✅ 初始化状态
- ✅ 消息发送
- ✅ 消息历史
- ✅ 清空消息
- ✅ 书籍上下文
- ✅ 错误处理
- ✅ 性能测试

### 3. EPUBParserTests.swift
**测试范围**: EPUB解析器
- ✅ 元数据解析
- ✅ 内容解析
- ✅ 封面提取
- ✅ 缓存管理
- ✅ 性能测试

---

## 🚀 运行测试

### 方法 1: Xcode GUI
```
1. 打开 SmartBook.xcodeproj
2. 选择测试目标 (Cmd+U)
3. 等待测试完成
4. 查看测试报告
```

### 方法 2: 命令行
```bash
# 运行所有测试
xcodebuild test \
  -scheme SmartBook \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# 运行特定测试类
xcodebuild test \
  -scheme SmartBook \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:SmartBookTests/BookServiceTests

# 运行特定测试方法
xcodebuild test \
  -scheme SmartBook \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:SmartBookTests/BookServiceTests/testLoadLocalBooks
```

### 方法 3: 快捷键
- `Cmd + U` - 运行所有测试
- `Cmd + Ctrl + U` - 运行最近的测试
- `Cmd + Opt + U` - 重新运行失败的测试

---

## 📝 测试配置

### 测试目标设置

在 `SmartBook.xcodeproj` 中确保：

1. **测试目标已创建**
   - Target Name: `SmartBookTests`
   - Bundle ID: `com.smartbook.SmartBookTests`
   - Host Application: SmartBook

2. **测试文件已添加**
   ```
   SmartBookTests/
   ├── BookServiceTests.swift
   ├── ChatViewModelTests.swift
   └── EPUBParserTests.swift
   ```

3. **测试资源**
   ```
   SmartBookTests/Resources/
   └── test.epub (测试用EPUB文件)
   ```

### Build Settings

```swift
// 在测试目标的 Build Settings 中:
ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES
ENABLE_TESTABILITY = YES
```

---

## 🧪 编写新测试

### 测试模板

```swift
import XCTest
@testable import SmartBook

final class MyFeatureTests: XCTestCase {
    
    var sut: MyFeature!  // System Under Test
    
    override func setUpWithError() throws {
        sut = MyFeature()
    }
    
    override func tearDownWithError() throws {
        sut = nil
    }
    
    // MARK: - 测试用例
    
    func testFeatureBehavior() {
        // Given: 准备测试数据
        let input = "test input"
        
        // When: 执行被测试的功能
        let result = sut.process(input)
        
        // Then: 验证结果
        XCTAssertEqual(result, "expected output")
    }
}
```

### 命名规范

```swift
// ✅ 好的命名
func testLoadLocalBooks()
func testSendMessage()
func testParseMetadata()

// ❌ 不好的命名
func test1()
func testStuff()
func myTest()
```

### Given-When-Then 模式

```swift
func testExample() {
    // Given: 设置测试前置条件
    let service = BookService()
    let expectedCount = 10
    
    // When: 执行被测试的操作
    let books = service.loadLocalBooks()
    
    // Then: 验证结果
    XCTAssertEqual(books.count, expectedCount)
}
```

---

## 🎭 Mock 和 Stub

### 创建 Mock Service

```swift
class MockChatService: ChatService {
    var shouldFail = false
    var mockResponse = "Mock response"
    
    override func sendMessage(_ text: String, bookId: String?, history: [ChatMessage]) async throws -> String {
        if shouldFail {
            throw APIError.networkError
        }
        return mockResponse
    }
}
```

### 使用 Mock

```swift
func testWithMockService() async {
    // Given
    let mockService = MockChatService()
    mockService.mockResponse = "Test response"
    viewModel.chatService = mockService  // 需要依赖注入
    
    // When
    await viewModel.sendMessage("Test")
    
    // Then
    XCTAssertEqual(viewModel.messages.last?.content, "Test response")
}
```

---

## ⚡ 性能测试

### 测试方法性能

```swift
func testPerformance() {
    measure {
        // 需要测试性能的代码
        _ = bookService.loadLocalBooks()
    }
}
```

### 性能指标

- **基准时间**: < 0.1 秒
- **警告阈值**: 0.1 - 0.5 秒
- **失败阈值**: > 0.5 秒

---

## 🎨 UI 测试

### 创建 UI 测试

```swift
// SmartBookUITests/SmartBookUITests.swift
import XCTest

final class SmartBookUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testChatFlow() {
        // 测试聊天流程
        let messageTextField = app.textFields["messageInput"]
        messageTextField.tap()
        messageTextField.typeText("Hello")
        
        let sendButton = app.buttons["sendButton"]
        sendButton.tap()
        
        // 验证消息已发送
        XCTAssertTrue(app.staticTexts["Hello"].exists)
    }
}
```

---

## 📊 测试覆盖率

### 查看覆盖率

1. **Xcode**:
   - Product > Scheme > Edit Scheme
   - Test > Options > Code Coverage ✅

2. **命令行**:
   ```bash
   xcodebuild test \
     -scheme SmartBook \
     -enableCodeCoverage YES \
     -destination 'platform=iOS Simulator,name=iPhone 15'
   ```

3. **查看报告**:
   ```bash
   xcrun xccov view --report \
     ~/Library/Developer/Xcode/DerivedData/.../SmartBook.xcresult
   ```

### 覆盖率目标

| 模块 | 目标覆盖率 | 当前状态 |
|------|-----------|---------|
| Models | 90%+ | ⚪ 待测试 |
| Services | 80%+ | ⚪ 待测试 |
| ViewModels | 70%+ | ⚪ 待测试 |
| Views | 50%+ | ⚪ 待测试 |

---

## 🐛 测试调试

### 调试失败的测试

```swift
func testDebugExample() {
    // 添加断点
    let books = bookService.loadLocalBooks()
    
    // 打印调试信息
    print("📚 Books count: \(books.count)")
    books.forEach { book in
        print("  - \(book.title)")
    }
    
    // 继续测试
    XCTAssertFalse(books.isEmpty)
}
```

### 常用 XCTest 断言

```swift
// 相等性
XCTAssertEqual(a, b)
XCTAssertNotEqual(a, b)

// 布尔值
XCTAssertTrue(condition)
XCTAssertFalse(condition)

// Nil 检查
XCTAssertNil(value)
XCTAssertNotNil(value)

// 异常
XCTAssertThrowsError(try expression())
XCTAssertNoThrow(try expression())

// 数值比较
XCTAssertGreaterThan(a, b)
XCTAssertLessThan(a, b)
```

---

## 🔄 持续集成

### GitHub Actions 配置

```yaml
# .github/workflows/ios-tests.yml
name: iOS Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app
      
      - name: Run tests
        run: |
          xcodebuild test \
            -scheme SmartBook \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -enableCodeCoverage YES
      
      - name: Upload coverage
        uses: codecov/codecov-action@v2
```

---

## 📋 测试清单

### 开发阶段

- [ ] 为新功能编写单元测试
- [ ] 测试覆盖率 > 目标值
- [ ] 所有测试通过
- [ ] 无性能回归

### Code Review 阶段

- [ ] 测试代码符合规范
- [ ] Mock/Stub 使用合理
- [ ] 测试用例完整
- [ ] 边界条件已测试

### 发布前

- [ ] 运行完整测试套件
- [ ] UI 测试通过
- [ ] 性能测试通过
- [ ] 在真机上测试

---

## 🎯 最佳实践

### ✅ 推荐做法

1. **测试独立性**
   - 每个测试互不依赖
   - 使用 setUp/tearDown 清理

2. **清晰的命名**
   - testFeature_Condition_ExpectedResult
   - testLoadBooks_WhenEmpty_ReturnsEmptyArray

3. **完整的覆盖**
   - 正常路径
   - 边界条件
   - 错误情况

4. **快速执行**
   - 单元测试 < 0.1s
   - 避免网络请求
   - 使用 Mock

### ❌ 避免做法

1. **测试依赖**
   - 不要依赖其他测试的结果
   - 不要依赖执行顺序

2. **过度 Mock**
   - 不要 Mock 所有依赖
   - 保持测试真实性

3. **脆弱的测试**
   - 不要硬编码时间
   - 不要依赖网络

---

## 📚 参考资源

### Apple 官方文档
- [XCTest Framework](https://developer.apple.com/documentation/xctest)
- [Testing Apps in Xcode](https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode)

### 测试书籍
- "Test Driven Development in Swift" - Dominik Hauser
- "iOS Test-Driven Development by Tutorials" - raywenderlich.com

### 在线资源
- [Swift Testing Best Practices](https://www.swiftbysundell.com/basics/unit-testing/)
- [XCTest Cheat Sheet](https://github.com/Xcode/XCTest-Cheat-Sheet)

---

## 🎉 总结

**测试是保证代码质量的关键**！

- ✅ 已创建 3 个测试文件
- ✅ 覆盖核心功能
- ⚠️ 需要添加更多测试
- 📈 目标: 80%+ 代码覆盖率

---

*最后更新: 2026-01-21*

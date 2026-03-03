# GoWidgetRuntime（最小迁移目录）

这个目录用于维护已迁移到 `smart-book-ios` 的 Go FFI Runtime，目标是本地独立构建与迭代。

## 推荐目录名

使用：`GoWidgetRuntime`

原因：
- 语义清晰：这是 Go 的 Widget Runtime，而不是业务层 Widget 代码
- 便于未来并存：后续可同时存在 `JSCoreWidgetRuntime`
- 与 App 源码解耦：当前放在 `SmartBook/GoWidgetRuntime`，避免影响主 target 编译

## 当前结构

- `go-src/ffi/widget_runtime/main.go`
  - 迁移过来的 Go 导出骨架（wr_init/wr_create/wr_start/wr_run/wr_on/wr_stop/wr_destroy）
- `include/widget_runtime.h`
  - FFI 头文件（稳定接口）
- `scripts/build_local_go_src.sh`
  - 直接从当前目录 `go-src` 构建本地 `c-archive`
- `artifacts/`
  - 构建产物目录（`libwidget_runtime.a` + 生成头文件）

## 最小流程（先跑通）

1. 在本目录运行本地构建脚本：

```bash
cd SmartBook/GoWidgetRuntime/scripts
./build_local_go_src.sh
```

> 该脚本默认输出 iOS（`GOOS=ios`, `GOARCH=arm64`）静态库，避免出现
> `built for 'macOS'` 但在 iOS target 链接的错误。

2. 产物会输出到：
- `SmartBook/GoWidgetRuntime/artifacts/libwidget_runtime_local.a`
- `SmartBook/GoWidgetRuntime/artifacts/libwidget_runtime_local.h`

3. 之后在 Xcode 里做最小接入：
- 添加 `.a` 到 Link Binary With Libraries
- 添加 `include` 到 Header Search Paths
- 新增 Swift Adapter（下一步再做）

## 说明

- `include/widget_runtime.generated.h` 是每次构建后从 Go 自动生成头文件同步过来的版本。
- 当前 `include/widget_runtime.h` 作为人工维护的稳定接口声明。

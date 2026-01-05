# 开发说明

## 目标
- 共享代码走 SwiftPM：`YunjianCore / EditorEngine / StorageService / SyncEngine / UIComponents`
- App 层仅负责组装依赖与平台差异
- 同步/协同只预留接口，后续接入 CloudKit / 多人协作不返工

## 目录
- `Sources/`：SwiftPM 模块
- `Apps/YunjianApp/`：SwiftUI App 入口代码（给 Xcode 工程使用）
- `project.yml`：XcodeGen 配置（生成 iOS/macOS 双 target）
- `scripts/bootstrap.sh`：生成 Xcode 工程脚本

## 生成 Xcode 工程（推荐）
1. 安装 XcodeGen：`brew install xcodegen`
2. 在仓库根目录执行：`./scripts/bootstrap.sh`
3. 用 Xcode 打开 `Yunjian.xcodeproj`

## 在 VS Code 里直接跑（macOS）
如果你只想在 VS Code 里快速跑起来看界面（macOS 桌面窗口），可以直接：

- 编译：`swift build`
- 运行：`swift run YunjianDev`

如果 `swift run` 后进程在跑但看不到窗口（常见于窗口被压到后台/其它桌面空间），优先试：

- 在 Dock 里找到 `YunjianDev` 并点一下
- 或在终端执行脚本（会构建 .app 并 `open`）：`./scripts/run-macos.sh`

说明：iOS 模拟器/真机运行依赖 Xcode，因此仍建议走上面的 XcodeGen 方案。

## 关键扩展点（后续不会返工的“接口”）
- 同步：`SyncEngineProtocol`（在 `Sources/YunjianCore/Protocols.swift`）
- 协同：`CollaborationEngineProtocol`（同上）
- 存储：`StorageServiceProtocol`（同上）

## 菜单栏（Commands + Menu Bar Extra）
- App 菜单栏提供“同步/协同”入口：`YunjianCommands`
- macOS 顶部菜单栏（状态栏图标）提供同步状态与快捷操作：`YunjianMenuBarExtra`

## 多语言（Localization）
UI 文案使用 SwiftPM 资源包本地化（UIComponents/Resources）：

- `en.lproj/Localizable.strings`
- `zh-Hans.lproj/Localizable.strings`

新增文案时：加 key 到 strings，并在代码里用 `L10n.text("...")`。

你后续把 `InMemoryStorageService` 替换为 Core Data 实现、把 `StubSyncEngine` 替换为 CloudKit/CoreData 镜像实现即可。

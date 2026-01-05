import Foundation

public protocol StorageServiceProtocol: Sendable {
    func listDocuments() async throws -> [Document]
    func loadDocument(id: DocumentID) async throws -> Document
    func upsertDocument(_ document: Document) async throws
    func deleteDocument(id: DocumentID) async throws
}

public enum SyncState: Hashable, Sendable {
    case idle
    case syncing
    case error(String)
}

public protocol SyncEngineProtocol: Sendable {
    var stateStream: AsyncStream<SyncState> { get }
    func start() async
    func stop() async

    /// 未来协同/同步接入点：
    /// - 你后续可在此实现：CloudKit 增量拉取、推送、冲突解决、以及协同编辑会话。
    func requestSync(reason: String) async
}

public protocol CollaborationEngineProtocol: Sendable {
    /// 预留“多人协同编辑”接入点。
    /// 当前只定义协议，保证后期添加 CRDT/OT 或 CloudKit 共享记录时不需要重构 UI 层。
    func join(documentID: DocumentID) async throws
    func leave(documentID: DocumentID) async
    func applyLocalChange(documentID: DocumentID, newBody: String) async
}

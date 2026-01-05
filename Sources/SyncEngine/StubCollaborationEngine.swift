import Foundation
import YunjianCore

public actor StubCollaborationEngine: CollaborationEngineProtocol {
    public init() {}

    public func join(documentID: DocumentID) async throws {
        // 占位：后续替换为 OT/CRDT 会话建立、权限校验等。
    }

    public func leave(documentID: DocumentID) async {
        // 占位：会话清理。
    }

    public func applyLocalChange(documentID: DocumentID, newBody: String) async {
        // 占位：把本地变更封装成 patch/ops 并广播。
    }
}

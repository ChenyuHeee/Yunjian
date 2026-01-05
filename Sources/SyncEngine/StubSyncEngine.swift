import Foundation
import StorageService
import YunjianCore

public actor StubSyncEngine: SyncEngineProtocol {
    private let storage: StorageServiceProtocol
    private var continuation: AsyncStream<SyncState>.Continuation
    public nonisolated let stateStream: AsyncStream<SyncState>

    public init(storage: StorageServiceProtocol) {
        self.storage = storage
        var localContinuation: AsyncStream<SyncState>.Continuation!
        let stream = AsyncStream<SyncState> { continuation in
            localContinuation = continuation
        }
        self.stateStream = stream
        self.continuation = localContinuation
        self.continuation.yield(.idle)
    }

    public func start() async {
        continuation.yield(.idle)
    }

    public func stop() async {
        continuation.yield(.idle)
    }

    public func requestSync(reason: String) async {
        // 占位：未来在这里接 CloudKit/CoreData 镜像 + 冲突解决。
        continuation.yield(.syncing)
        try? await Task.sleep(nanoseconds: 150_000_000)
        continuation.yield(.idle)
    }
}

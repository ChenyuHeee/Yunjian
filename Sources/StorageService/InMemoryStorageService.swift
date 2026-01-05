import Foundation
import YunjianCore

public actor InMemoryStorageService: StorageServiceProtocol {
    private var store: [DocumentID: Document] = [:]

    public init(seed: [Document] = []) {
        for doc in seed {
            store[doc.id] = doc
        }
    }

    public func listDocuments() async throws -> [Document] {
        store.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func loadDocument(id: DocumentID) async throws -> Document {
        guard let doc = store[id] else { throw YunjianError.notFound }
        return doc
    }

    public func upsertDocument(_ document: Document) async throws {
        store[document.id] = document
    }

    public func deleteDocument(id: DocumentID) async throws {
        store[id] = nil
    }
}

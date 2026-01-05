import Foundation

public struct DocumentID: Hashable, Codable, Sendable {
    public var rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct Document: Identifiable, Hashable, Codable, Sendable {
    public var id: DocumentID
    public var title: String
    public var body: String

    public var fileURL: URL?

    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: DocumentID = .init(),
        title: String,
        body: String,
        fileURL: URL? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct TextSelection: Hashable, Codable, Sendable {
    public var location: Int
    public var length: Int

    public init(location: Int = 0, length: Int = 0) {
        self.location = location
        self.length = length
    }

    public static let empty = TextSelection(location: 0, length: 0)
}

public enum YunjianError: Error, LocalizedError, Sendable {
    case notFound
    case invalidState(String)
    case storage(String)
    case sync(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Not found"
        case let .invalidState(message):
            return "Invalid state: \(message)"
        case let .storage(message):
            return "Storage error: \(message)"
        case let .sync(message):
            return "Sync error: \(message)"
        }
    }
}

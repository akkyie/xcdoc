import ArgumentParser
import Foundation
import SwiftDocC

struct ShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show a documentation article"
    )

    @Argument(help: "Documentation path or doc:// link (e.g., /documentation/uikit/uiview, doc://com.apple.uikit/documentation/UIKit/UIView)")
    var path: String

    func run() async throws {
        let basePath = try await Xcdoc.basePath()
        let cacheDB = CacheDB(basePath: basePath)
        let fileChunkStore = FileChunkStore(basePath: basePath)

        let renderNode: RenderNode
        if let uuid = DocumentationUUID(rawValue: path) {
            renderNode = try await fetchRenderNode(uuid: uuid, cacheDB: cacheDB, fileChunkStore: fileChunkStore)
        } else {
            renderNode = try await fetchRenderNode(path: path, cacheDB: cacheDB, fileChunkStore: fileChunkStore)
        }

        let markdown = renderNode.renderAsMarkdown()
        print(markdown)
    }

    private func fetchRenderNode(uuid: DocumentationUUID, cacheDB: CacheDB, fileChunkStore: FileChunkStore) async throws -> RenderNode {
        guard let ref = try cacheDB.fetchChunkReference(uuid: uuid) else {
            throw ShowCommandError.notFound(input: uuid.rawValue, normalized: uuid.rawValue)
        }
        return try await fileChunkStore.extractRenderNode(ref: ref, uuid: uuid.rawValue)
    }

    private func fetchRenderNode(path: String, cacheDB: CacheDB, fileChunkStore: FileChunkStore) async throws -> RenderNode {
        let normalizedPath = normalizePath(path)
        let uuids = DocumentationLanguage.allCases.map {
            DocumentationUUID(path: normalizedPath, language: $0)
        }
        let refs = try cacheDB.fetchChunkReferences(uuids: uuids)
        for uuid in uuids {
            if let ref = refs[uuid.rawValue] {
                return try await fileChunkStore.extractRenderNode(ref: ref, uuid: uuid.rawValue)
            }
        }
        throw ShowCommandError.notFound(input: path, normalized: normalizedPath)
    }

    private func normalizePath(_ path: String) -> String {
        var path = path.lowercased()

        if let lang = DocumentationLanguage.allCases.first(where: { path.hasPrefix($0.pathPrefix) }) {
            path = "/" + String(path.dropFirst(lang.pathPrefix.count))
        }

        guard var components = URLComponents(string: path) else {
            return path
        }

        if !components.path.hasPrefix("/") {
            components.path = "/" + components.path
        }

        if !components.path.hasPrefix("/documentation") && !components.path.hasPrefix("/tutorial") {
            components.path = "/documentation" + components.path
        }

        while components.path.hasSuffix("/") && !components.path.isEmpty {
            components.path.removeLast()
        }

        return components.path
    }
}

enum ShowCommandError: Error, LocalizedError {
    case notFound(input: String, normalized: String)

    var errorDescription: String? {
        switch self {
        case let .notFound(input, normalized) where input == normalized:
            return "Page not found: \(input)"
        case let .notFound(input, normalized):
            return """
            Page not found.
                Input: \(input)
                Normalized: \(normalized)
            """
        }
    }
}

import ArgumentParser
import Foundation
import SwiftDocC

struct ShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show a documentation article"
    )

    @Argument(help: "UUID, documentation path, or doc:// link (e.g., lsqwUNJTw9, /documentation/uikit/uiview, doc://com.apple.uikit/documentation/UIKit/UIView)")
    var pathOrUUID: String

    func run() async throws {
        let basePath = try await Xcdoc.basePath()
        let cacheDB = CacheDB(basePath: basePath)
        let fileChunkStore = FileChunkStore(basePath: basePath)

        let renderNode: RenderNode
        if let uuid = DocumentationUUID(rawValue: pathOrUUID) {
            renderNode = try await fetchRenderNode(uuid: uuid, cacheDB: cacheDB, fileChunkStore: fileChunkStore)
        } else {
            renderNode = try await fetchRenderNode(path: pathOrUUID, cacheDB: cacheDB, fileChunkStore: fileChunkStore)
        }

        let markdown = renderNode.renderAsMarkdown()
        print(markdown)
    }

    private func fetchRenderNode(uuid: DocumentationUUID, cacheDB: CacheDB, fileChunkStore: FileChunkStore) async throws -> RenderNode {
        guard let ref = try cacheDB.fetchChunkReference(uuid: uuid) else {
            throw ShowCommandError.notFound(identifier: uuid.rawValue)
        }
        return try await fileChunkStore.extractRenderNode(ref: ref, uuid: uuid.rawValue)
    }

    private func fetchRenderNode(path: String, cacheDB: CacheDB, fileChunkStore: FileChunkStore) async throws -> RenderNode {
        var searchPath = path.lowercased()

        if searchPath.hasPrefix("doc://") {
            searchPath = extractPathFromDocLink(searchPath)
        }

        for lang in DocumentationLanguage.allCases {
            if searchPath.hasPrefix(lang.pathPrefix) {
                searchPath = "/" + String(searchPath.dropFirst(lang.pathPrefix.count))
                break
            }
        }

        if !searchPath.hasPrefix("/") {
            searchPath = "/documentation/" + searchPath
        } else if !searchPath.hasPrefix("/documentation/") {
            searchPath = "/documentation" + searchPath
        }
        let uuids = DocumentationLanguage.allCases.map { DocumentationUUID(path: searchPath, language: $0) }
        let refs = try cacheDB.fetchChunkReferences(uuids: uuids)
        for uuid in uuids {
            if let ref = refs[uuid.rawValue] {
                return try await fileChunkStore.extractRenderNode(ref: ref, uuid: uuid.rawValue)
            }
        }
        throw ShowCommandError.notFound(identifier: path)
    }

    private func extractPathFromDocLink(_ link: String) -> String {
        guard let url = URL(string: link),
              url.scheme == "doc",
              let _ = url.host else {
            return link
        }
        let pathWithDoc = url.path
        if let range = pathWithDoc.range(of: "/documentation/") {
            return String(pathWithDoc[range.lowerBound...])
        }
        return pathWithDoc
    }
}

enum ShowCommandError: Error, LocalizedError {
    case notFound(identifier: String)

    var errorDescription: String? {
        switch self {
        case .notFound(let identifier):
            return "Article not found: \(identifier)"
        }
    }
}

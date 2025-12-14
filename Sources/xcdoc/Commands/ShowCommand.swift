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

    @Flag(name: .long, help: "Show Swift documentation")
    var swift: Bool = false

    @Flag(name: .long, help: "Show Objective-C documentation")
    var objc: Bool = false

    @Flag(name: [.customLong("other"), .customLong("data")], help: "Show other (data) documentation")
    var other: Bool = false

    func run() async throws {
        let basePath = try await Xcdoc.basePath()
        let cacheDB = CacheDB(basePath: basePath)
        let fileChunkStore = FileChunkStore(basePath: basePath)

        let languageFlags = [swift, objc, other].filter { $0 }
        if 1 < languageFlags.count {
            throw ValidationError("Cannot specify multiple language filters. Use only one of --swift, --objc, or --other.")
        }

        let language: DocumentationLanguage? = if swift {
            .swift
        } else if objc {
            .objc
        } else if other {
            .other
        } else {
            nil
        }

        let renderNode: RenderNode
        if let uuid = DocumentationUUID(rawValue: path) {
            if let language, !uuid.rawValue.hasPrefix(language.uuidPrefix) {
                throw ValidationError("UUID does not match the specified language filter.")
            }

            renderNode = try await fetchRenderNode(
                uuid: uuid,
                cacheDB: cacheDB,
                fileChunkStore: fileChunkStore
            )
        } else {
            renderNode = try await fetchRenderNode(
                path: path,
                language: language,
                cacheDB: cacheDB,
                fileChunkStore: fileChunkStore
            )
        }

        let markdown = renderNode.renderAsMarkdown()
        print(markdown)
    }

    private func fetchRenderNode(
        uuid: DocumentationUUID,
        cacheDB: CacheDB,
        fileChunkStore: FileChunkStore
    ) async throws -> RenderNode {
        guard let ref = try cacheDB.fetchChunkReference(uuid: uuid) else {
            throw ShowCommandError.notFound(input: uuid.rawValue, normalized: uuid.rawValue)
        }
        return try await fileChunkStore.extractRenderNode(ref: ref, uuid: uuid.rawValue)
    }

    private func fetchRenderNode(
        path: String,
        language: DocumentationLanguage?,
        cacheDB: CacheDB,
        fileChunkStore: FileChunkStore
    ) async throws -> RenderNode {
        let (normalizedPath, langInPath) = normalizePath(path)
        let languages = if let language = langInPath ?? language {
            [language]
        } else {
            DocumentationLanguage.allCases
        }

        let uuids = languages.map {
            DocumentationUUID(path: normalizedPath, language: $0)
        }

        let refs = try cacheDB.fetchChunkReferences(uuids: uuids)
        for uuid in uuids {
            do {
                guard let ref = refs[uuid.rawValue] else { continue }
                return try await fileChunkStore.extractRenderNode(ref: ref, uuid: uuid.rawValue)
            } catch {
                continue
            }
        }
        throw ShowCommandError.notFound(input: path, normalized: normalizedPath)
    }

    private func normalizePath(_ path: String) -> (String, DocumentationLanguage?) {
        var path = path.lowercased()
        var language: DocumentationLanguage?

        if let lang = DocumentationLanguage.allCases.first(where: { path.hasPrefix($0.pathPrefix) }) {
            path = "/" + String(path.dropFirst(lang.pathPrefix.count))
            language = lang
        }

        guard var components = URLComponents(string: path) else {
            return (path, language)
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

        if let languageQuery = components.queryItems?.first(where: { $0.name == "language" })?.value {
            switch languageQuery {
            case "swift": language = .swift
            case "objc", "objective-c": language = .objc
            case "data": language = .other
            default: break
            }
        }

        return (components.path, language)
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

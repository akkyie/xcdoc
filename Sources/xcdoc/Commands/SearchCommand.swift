import ArgumentParser
import Foundation

struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search documentation by keyword"
    )

    @Argument(help: "The search keywords")
    var queries: [String]

    @Flag(name: .long, help: "Filter to Swift documentation only")
    var swift: Bool = false

    @Flag(name: [.long, .customLong("objective-c")], help: "Filter to Objective-C documentation only")
    var objc: Bool = false

    @Flag(name: [.long, .customLong("data")], help: "Filter to other (data) documentation only")
    var other: Bool = false

    @Option(name: [.short, .long], help: "Maximum number of results")
    var limit: Int = 20

    func run() async throws {
        let basePath = try await Xcdoc.basePath()
        let cacheDB = CacheDB(basePath: basePath)
        let fileChunkStore = FileChunkStore(basePath: basePath)

        let keywords = queries
            .flatMap { $0.split { $0.isWhitespace || $0 == "." }.map(String.init) }

        guard !keywords.isEmpty else {
            throw ValidationError("Please provide at least one search keyword.")
        }

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

        let pathSearchIndex = try PathSearchIndex(basePath: basePath)
        let pathResults = try pathSearchIndex.search(keywords: keywords, language: language, limit: limit)

        let textSearchIndex = TextSearchIndex(basePath: basePath)

        let results = try await fetchMetadata(
            for: pathResults.results,
            language: language,
            textSearchIndex: textSearchIndex,
            cacheDB: cacheDB,
            fileChunkStore: fileChunkStore
        )

        guard !results.isEmpty else {
            throw SearchCommandError.notFound(keywords: keywords)
        }

        if pathResults.truncated {
            fputs("warning: Search terminated early due to too many matches. Results may be incomplete. Try a more specific query.\n\n", stderr)
        }

        for result in results {
            let typeLabel = result.pageType.label
            let title = result.title
            let module = result.moduleName.map { " - \($0)" } ?? ""
            print("[\(result.language.name)] \(title) (\(typeLabel)\(module)) \(result.path)")
        }

        if 0 < pathResults.overflowCount {
            print("\n... and \(pathResults.overflowCount) more results. Use --limit to show more.")
        }
    }

    private func fetchMetadata(
        for results: [PathSearchResult],
        language: DocumentationLanguage?,
        textSearchIndex: TextSearchIndex,
        cacheDB: CacheDB,
        fileChunkStore: FileChunkStore
    ) async throws -> [SearchResult] {
        let textResults = await textSearchIndex.search(uuids: results.map(\.uuid), language: language)

        let uuids = results.compactMap { DocumentationUUID(rawValue: $0.uuid) }
        let refs = try cacheDB.fetchChunkReferences(uuids: uuids)

        let renderNodes = await fileChunkStore.extractRenderNodes(refs: refs)

        var titledResults: [SearchResult] = []
        titledResults.reserveCapacity(results.count)

        for result in results {
            guard let renderNode = renderNodes[result.uuid] else {
                continue
            }

            let textResult = textResults[result.uuid]

            let titledResult = SearchResult(
                uuid: result.uuid,
                path: renderNode.identifier.url.path,
                title: renderNode.metadata.title ?? "",
                pageType: textResult?.pageType ?? .unknown,
                language: result.language,
                moduleName: renderNode.metadata.modules?.first?.name
            )
            titledResults.append(titledResult)
        }

        return titledResults
    }

    struct SearchResult {
        let uuid: String
        let path: String
        let title: String
        let pageType: PageType
        let language: DocumentationLanguage
        let moduleName: String?
    }
}

enum SearchCommandError: Error, LocalizedError {
    case notFound(keywords: [String])

    var errorDescription: String? {
        switch self {
        case .notFound(let keywords):
            return "No results found for: \"\(keywords.joined(separator: " "))\""
        }
    }
}

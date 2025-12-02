import Foundation
import CLMDB
import HeapModule

struct PathSearchResult {
    let path: String
    let language: DocumentationLanguage
    var uuid: String { DocumentationUUID(path: pathWithoutLanguage, language: language).rawValue }

    private var pathWithoutLanguage: String {
        let prefix = language.pathPrefix
        guard path.hasPrefix(prefix) else { return path }
        return String(path.dropFirst(prefix.count - 1))
    }
}

struct PathSearchResults {
    let results: [PathSearchResult]
    let overflowCount: Int
    let truncated: Bool
}

/// Provides path lookup and keyword search over Xcode's LMDB database (`index/data.mdb`).
///
/// The database `index` contains two keyspaces:
/// - `id-to-path`: node ID (UInt32) → documentation path string (e.g., `/documentation/swift/array`).
/// - `path-to-id`: SHA1 hash of path → node ID.
///
/// Paths are prefixed by language: `/documentation/swift/` (Swift), `/documentation/objc/` (ObjC),
/// or `/documentation/data/` (Data/REST API).
final class PathSearchIndex {
    private let env: OpaquePointer
    private let txn: OpaquePointer
    private let dbi: MDB_dbi

    init(basePath: URL) throws {
        let dbPath = basePath
            .appendingPathComponent("index")
            .appendingPathComponent("data.mdb")
            .path

        var _env: OpaquePointer?
        guard mdb_env_create(&_env) == 0, let env = _env else {
            throw PathSearchError.environmentCreationFailed
        }
        guard mdb_env_set_maxdbs(env, 10) == 0 else {
            mdb_env_close(env)
            throw PathSearchError.configurationFailed
        }
        let flags = UInt32(MDB_RDONLY | MDB_NOSUBDIR | MDB_NOLOCK)
        guard mdb_env_open(env, dbPath, flags, 0o644) == 0 else {
            mdb_env_close(env)
            throw PathSearchError.environmentOpenFailed(path: dbPath)
        }

        var _txn: OpaquePointer?
        guard mdb_txn_begin(env, nil, UInt32(MDB_RDONLY), &_txn) == 0, let txn = _txn else {
            mdb_env_close(env)
            throw PathSearchError.transactionFailed
        }

        var _dbi: MDB_dbi = 0
        guard mdb_dbi_open(txn, "index", 0, &_dbi) == 0 else {
            mdb_txn_abort(txn)
            mdb_env_close(env)
            throw PathSearchError.databaseOpenFailed
        }

        self.env = env
        self.txn = txn
        self.dbi = _dbi
    }

    deinit {
        mdb_txn_abort(txn)
        mdb_env_close(env)
    }

    func path(for nodeID: UInt32) -> String? {
        var id = nodeID
        return withUnsafeMutablePointer(to: &id) { idPtr in
            var key = MDB_val(mv_size: MemoryLayout<UInt32>.size, mv_data: idPtr)
            var value = MDB_val()

            guard mdb_get(txn, dbi, &key, &value) == 0 else { return nil }

            let buffer = UnsafeBufferPointer(
                start: value.mv_data.assumingMemoryBound(to: UInt8.self),
                count: value.mv_size
            )
            return String(decoding: buffer, as: UTF8.self)
        }
    }

    func search(
        keywords: [String],
        language: DocumentationLanguage?,
        limit: Int
    ) throws -> PathSearchResults {
        let languages = language.map { [$0] } ?? DocumentationLanguage.allCases
        let loweredKeywords = keywords.map { $0.lowercased() }
        var collector = PathResultCollector(limit: limit)

        var cursor: OpaquePointer?
        guard mdb_cursor_open(txn, dbi, &cursor) == 0 else {
            throw PathSearchError.cursorOpenFailed
        }
        defer { mdb_cursor_close(cursor) }

        var key = MDB_val()
        var value = MDB_val()
        var op = MDB_cursor_op(MDB_FIRST.rawValue)

        let loweredKeywordBytes = loweredKeywords.map { Array($0.utf8) }

        while mdb_cursor_get(cursor, &key, &value, op) == 0 {
            op = MDB_cursor_op(MDB_NEXT.rawValue)

            guard key.mv_size == 4 else { continue }

            let pathBuffer = UnsafeBufferPointer(
                start: value.mv_data.assumingMemoryBound(to: UInt8.self),
                count: value.mv_size
            )

            guard
                let lang = Self.detectLanguage(from: pathBuffer),
                languages.contains(lang)
            else { continue }

            let matched = loweredKeywordBytes.allSatisfy { keyword in
                keyword.withUnsafeBufferPointer { needle in
                    Self.memmemContains(pathBuffer, needle: needle)
                }
            }
            guard matched else { continue }

            let path = String(decoding: pathBuffer, as: UTF8.self)
            let result = PathSearchResult(path: path, language: lang)
            let rank = PathSearchRank(path: path, loweredKeywords: loweredKeywords, language: lang)
            collector.append(PathRankedResult(result: result, rank: rank))

            if collector.shouldStop { break }
        }

        return collector.finalize()
    }

    private static func detectLanguage(from buffer: UnsafeBufferPointer<UInt8>) -> DocumentationLanguage? {
        for lang in DocumentationLanguage.allCases {
            let prefix = lang.pathPrefix
            if buffer.count >= prefix.count, buffer.starts(with: prefix.utf8) {
                return lang
            }
        }
        return nil
    }

    private static func memmemContains(
        _ haystack: UnsafeBufferPointer<UInt8>,
        needle: UnsafeBufferPointer<UInt8>
    ) -> Bool {
        guard
            let haystackBase = haystack.baseAddress,
            let needleBase = needle.baseAddress,
            needle.count > 0
        else {
            return needle.count == 0
        }

        return memmem(haystackBase, haystack.count, needleBase, needle.count) != nil
    }
}

private struct PathResultCollector {
    private let limit: Int
    private let maxMatches: Int

    private var heap: Heap<PathRankedResult>
    private var ids: Set<String> = []
    private var order: Int = 0
    private var overflowCount: Int = 0
    private(set) var shouldStop: Bool = false

    init(limit: Int) {
        self.limit = limit
        self.maxMatches = limit * 5000
        self.heap = Heap(minimumCapacity: limit)
    }

    mutating func append(_ rankedResult: PathRankedResult) {
        let uuid = rankedResult.result.uuid
        guard !ids.contains(uuid) else { return }
        ids.insert(uuid)

        order += 1
        let ranked = rankedResult.with(order: order)
        if heap.count < limit {
            heap.insert(ranked)
            return
        }

        if let worst = heap.max, ranked < worst {
            _ = heap.replaceMax(with: ranked)
        }
        overflowCount += 1

        if overflowCount >= maxMatches {
            shouldStop = true
        }
    }

    func finalize() -> PathSearchResults {
        PathSearchResults(
            results: heap.unordered.sorted().map(\.result),
            overflowCount: overflowCount,
            truncated: shouldStop
        )
    }
}

private struct PathRankedResult {
    let result: PathSearchResult
    let rank: PathSearchRank
    let order: Int

    init(result: PathSearchResult, rank: PathSearchRank, order: Int = 0) {
        self.result = result
        self.rank = rank
        self.order = order
    }

    func with(order: Int) -> PathRankedResult {
        PathRankedResult(result: result, rank: rank, order: order)
    }
}

extension PathRankedResult: Comparable {
    static func < (lhs: PathRankedResult, rhs: PathRankedResult) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        return lhs.order < rhs.order
    }

    static func == (lhs: PathRankedResult, rhs: PathRankedResult) -> Bool {
        lhs.rank == rhs.rank && lhs.order == rhs.order
    }
}

private struct PathSearchRank: Comparable {
    let componentRatio: Double
    let matchedBaseComponentCount: Int
    let pathLength: Int
    let languageOrder: Int
    let path: String

    init(path: String, loweredKeywords: [String], language: DocumentationLanguage) {
        self.path = path

        let components = path.split(separator: "/")

        guard let lastComponent = components.last else {
            componentRatio = 0
            matchedBaseComponentCount = 0
            pathLength = .max
            languageOrder = .max
            return
        }

        let baseComponents = components.dropLast()
        matchedBaseComponentCount = baseComponents.count { component in
            loweredKeywords.contains { component == $0 }
        }

        let baseName = if let index = lastComponent.firstIndex(of: "(") {
            lastComponent[..<index]
        } else {
            lastComponent
        }

        let matchedLength = loweredKeywords
            .lazy
            .filter { baseName.contains($0) }
            .reduce(0) { $0 + $1.count }

        let totalKeywordLength = loweredKeywords.reduce(0) { $0 + $1.count }

        componentRatio = Double(matchedLength) / Double(max(baseName.count, totalKeywordLength))
        pathLength = path.count
        languageOrder = language.searchOrder
    }

    static func < (lhs: PathSearchRank, rhs: PathSearchRank) -> Bool {
        // Higher keyword match ratio wins
        if lhs.componentRatio != rhs.componentRatio {
            return lhs.componentRatio > rhs.componentRatio
        }
        // More exact base component matches wins
        if lhs.matchedBaseComponentCount != rhs.matchedBaseComponentCount {
            return lhs.matchedBaseComponentCount > rhs.matchedBaseComponentCount
        }
        // Shorter base name wins
        if lhs.pathLength != rhs.pathLength {
            return lhs.pathLength < rhs.pathLength
        }
        // Language priority
        if lhs.languageOrder != rhs.languageOrder {
            return lhs.languageOrder < rhs.languageOrder
        }
        return lhs.path < rhs.path
    }

}

enum PathSearchError: Error, LocalizedError {
    case environmentCreationFailed
    case configurationFailed
    case environmentOpenFailed(path: String)
    case transactionFailed
    case databaseOpenFailed
    case cursorOpenFailed

    var errorDescription: String? {
        switch self {
        case .environmentCreationFailed:
            return "Failed to create LMDB environment"
        case .configurationFailed:
            return "Failed to configure LMDB environment"
        case .environmentOpenFailed(let path):
            return "Failed to open LMDB environment at '\(path)'"
        case .transactionFailed:
            return "Failed to begin LMDB transaction"
        case .databaseOpenFailed:
            return "Failed to open LMDB database"
        case .cursorOpenFailed:
            return "Failed to open LMDB cursor"
        }
    }
}

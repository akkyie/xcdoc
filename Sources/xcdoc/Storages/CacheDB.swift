import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Points to a specific byte range within a data chunk file.
///
/// Used to locate documentation content within Xcode's chunked storage format.
struct FileChunkReference {
    let dataID: Int
    let offset: Int
    let length: Int
}

/// Provides read-only access to Xcode's `cache.db` lookup database.
///
/// `cache.db` contains:
/// - `refs(uuid, data_id, offset, length)`: maps doc UUIDs to byte ranges inside
///   chunk files under `fs/{data_id}`.
/// - `data(data BLOB, is_compressed)`: optional compressed chunk blobs.
///
/// This type opens the database at `<basePath>/cache.db` and fetches the offsets
/// needed to locate render nodes in the chunk store.
final class CacheDB {
    let path: URL
    private var db: OpaquePointer?
    private var singleStmt: OpaquePointer?

    init(basePath: URL) {
        self.path = basePath.appendingPathComponent("cache.db")
    }

    deinit {
        if let stmt = singleStmt {
            sqlite3_finalize(stmt)
        }
        if let db = db {
            sqlite3_close(db)
        }
    }

    private func ensureOpen() throws {
        if db != nil { return }
        guard sqlite3_open_v2(path.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw CacheDBError.openFailed(path: path.path)
        }
        let query = "SELECT data_id, offset, length FROM refs WHERE uuid = ?"
        guard sqlite3_prepare_v2(db, query, -1, &singleStmt, nil) == SQLITE_OK else {
            sqlite3_close(db)
            db = nil
            throw CacheDBError.queryFailed(query: query)
        }
    }

    func fetchChunkReference(uuid: DocumentationUUID) throws -> FileChunkReference? {
        try ensureOpen()
        guard let stmt = singleStmt else { return nil }

        sqlite3_reset(stmt)
        sqlite3_bind_text(stmt, 1, uuid.rawValue, Int32(uuid.rawValue.utf8.count), sqliteTransient)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        return FileChunkReference(
            dataID: Int(sqlite3_column_int(stmt, 0)),
            offset: Int(sqlite3_column_int(stmt, 1)),
            length: Int(sqlite3_column_int(stmt, 2))
        )
    }

    func fetchChunkReferences(uuids: [DocumentationUUID]) throws -> [String: FileChunkReference] {
        guard !uuids.isEmpty else { return [:] }
        try ensureOpen()
        guard let db = db else { return [:] }

        let placeholders = uuids.map { _ in "?" }.joined(separator: ",")
        let query = "SELECT uuid, data_id, offset, length FROM refs WHERE uuid IN (\(placeholders))"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            throw CacheDBError.queryFailed(query: query)
        }
        defer { sqlite3_finalize(stmt) }

        for (index, uuid) in uuids.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), uuid.rawValue, Int32(uuid.rawValue.utf8.count), sqliteTransient)
        }

        var results: [String: FileChunkReference] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let uuidPtr = sqlite3_column_text(stmt, 0) else { continue }
            let uuid = String(cString: uuidPtr)
            results[uuid] = FileChunkReference(
                dataID: Int(sqlite3_column_int(stmt, 1)),
                offset: Int(sqlite3_column_int(stmt, 2)),
                length: Int(sqlite3_column_int(stmt, 3))
            )
        }
        return results
    }
}

enum CacheDBError: Error, LocalizedError {
    case openFailed(path: String)
    case queryFailed(query: String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let path):
            return "Failed to open database: \(path)"
        case .queryFailed(let query):
            return "Database query failed: \(query)"
        }
    }
}

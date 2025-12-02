import Foundation
import SwiftDocC
import Compression

/// Extracts documentation render nodes from Xcode's chunk storage.
///
/// The `fs/{id}` files hold concatenated render-node JSON slices, Brotli
/// compressed when `cache.db.data.is_compressed` is 1. This actor decompresses
/// a chunk once, caches it in memory, and slices out the `[offset, length]`
/// range described by `FileChunkReference` to decode a `RenderNode`.
actor FileChunkStore {
    let basePath: URL

    private var chunkCache: [Int: Data] = [:]

    init(basePath: URL) {
        self.basePath = basePath
    }

    func extractRenderNodes(refs: [String: FileChunkReference]) -> [String: RenderNode] {
        guard !refs.isEmpty else { return [:] }

        let grouped = Dictionary(grouping: refs, by: { $0.value.dataID })
        var results: [String: RenderNode] = [:]
        results.reserveCapacity(refs.count)

        for (dataID, entries) in grouped {
            guard let data = try? chunk(for: dataID) else { continue }
            for (uuid, ref) in entries {
                guard let node = try? extractRenderNode(from: data, ref: ref, uuid: uuid) else { continue }
                results[uuid] = node
            }
        }

        return results
    }

    func extractRenderNode(ref: FileChunkReference, uuid: String? = nil) throws -> RenderNode {
        let data = try chunk(for: ref.dataID)
        return try extractRenderNode(from: data, ref: ref, uuid: uuid)
    }

    private func chunk(for dataID: Int) throws -> Data {
        if let cached = chunkCache[dataID] {
            return cached
        }
        let data = try loadChunk(dataID: dataID)
        chunkCache[dataID] = data
        return data
    }

    private func loadChunk(dataID: Int) throws -> Data {
        let chunkURL = basePath
            .appendingPathComponent("fs")
            .appendingPathComponent(String(dataID))

        let compressedData: Data
        do {
            compressedData = try Data(contentsOf: chunkURL)
        } catch {
            throw FileChunkStoreError.chunkNotFound(dataID: dataID)
        }

        do {
            return try compressedData.decompressedBrotli()
        } catch {
            throw FileChunkStoreError.decompressionFailed(dataID: dataID)
        }
    }

    private func extractRenderNode(from data: Data, ref: FileChunkReference, uuid: String?) throws -> RenderNode {
        guard ref.offset + ref.length <= data.count else {
            throw FileChunkStoreError.offsetOutOfBounds(
                dataID: ref.dataID,
                offset: ref.offset,
                length: ref.length,
                actual: data.count
            )
        }
        let slice = data[ref.offset ..< ref.offset + ref.length]
        do {
            return try JSONDecoder().decode(RenderNode.self, from: Data(slice))
        } catch {
            throw FileChunkStoreError.decodeFailed(uuid: uuid ?? "unknown")
        }
    }
}

enum FileChunkStoreError: Error, LocalizedError {
    case chunkNotFound(dataID: Int)
    case decompressionFailed(dataID: Int)
    case offsetOutOfBounds(dataID: Int, offset: Int, length: Int, actual: Int)
    case decodeFailed(uuid: String)

    var errorDescription: String? {
        switch self {
        case .chunkNotFound(let dataID):
            return "Chunk file not found: fs/\(dataID)"
        case .decompressionFailed(let dataID):
            return "Failed to decompress chunk: fs/\(dataID)"
        case .offsetOutOfBounds(let dataID, let offset, let length, let actual):
            return "Chunk offset out of bounds: fs/\(dataID) (offset=\(offset), length=\(length), actual=\(actual))"
        case .decodeFailed(let uuid):
            return "Failed to decode render node: \(uuid)"
        }
    }
}

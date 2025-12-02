import Foundation
import HeapModule

/// Represents a single documentation search result with metadata.
struct TextSearchResult {
    let uuid: String
    let text: String
    let pageType: PageType
    let language: DocumentationLanguage
}

/// Provides UUID-based lookup over Xcode's text index files (`0.txt`, `1.txt`, `3.txt`).
///
/// These files are apparently full-text search indexes, but this class uses them for UUID → pageType lookup.
/// Each line is `{searchable_text}\0{pageType}\0{UUID}\n`, stored per language (Swift, ObjC, Other/Data).
struct TextSearchIndex {
    let basePath: URL

    func search(
        uuids: [String],
        language: DocumentationLanguage?
    ) async -> [String: TextSearchResult] {
        let languages = language.map { [$0] } ?? DocumentationLanguage.allCases
        let uuidSet = Set(uuids)

        return await withTaskGroup(of: [String: TextSearchResult].self) { group in
            for lang in languages {
                let fileURL = basePath.appendingPathComponent(lang.indexFilename)
                group.addTask {
                    searchFile(by: uuidSet, fileURL: fileURL, language: lang)
                }
            }

            var results: [String: TextSearchResult] = [:]
            for await groupResult in group {
                results.merge(groupResult) { $1 }
            }
            return results
        }
    }

    private func searchFile(
        by uuids: Set<String>,
        fileURL: URL,
        language: DocumentationLanguage
    ) -> [String: TextSearchResult] {
        guard let data = try? Data(contentsOf: fileURL, options: .alwaysMapped) else { return [:] }

        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return [:]
            }

            let buffer = UnsafeBufferPointer(start: baseAddress, count: rawBuffer.count)

            var results: [String: TextSearchResult] = [:]
            var lineStart = 0

            func processLine(end: Int) {
                guard let result = parseLineIfMatch(
                    uuidSet: uuids,
                    buffer: buffer,
                    lineRange: lineStart ..< end,
                    language: language
                ) else { return }
                results[result.uuid] = result
            }

            var index = 0
            while index < buffer.count {
                if buffer[index] == UInt8(ascii: "\n") {
                    processLine(end: index)
                    lineStart = index + 1
                }
                index += 1
            }

            if lineStart < buffer.count {
                processLine(end: buffer.count)
            }

            return results
        }
    }

    private func parseLineIfMatch(
        uuidSet: Set<String>,
        buffer: UnsafeBufferPointer<UInt8>,
        lineRange: Range<Int>,
        language: DocumentationLanguage
    ) -> TextSearchResult? {
        guard let baseAddress = buffer.baseAddress, !lineRange.isEmpty else {
            return nil
        }

        var fields: [Range<Int>] = []
        fields.reserveCapacity(4)

        var fieldStart = lineRange.lowerBound
        var index = lineRange.lowerBound
        while index < lineRange.upperBound {
            if buffer[index] == 0 {
                fields.append(fieldStart..<index)
                fieldStart = index + 1
            }
            index += 1
        }
        fields.append(fieldStart..<lineRange.upperBound)

        guard fields.count >= 3 else { return nil }

        let textRange = fields[0]
        let pageTypeRange = fields[1]
        let uuidRange = fields[2]

        let uuidPointer = UnsafeBufferPointer(
            start: baseAddress.advanced(by: uuidRange.lowerBound),
            count: uuidRange.count
        )
        let uuid = String(decoding: uuidPointer, as: UTF8.self)

        guard uuidSet.contains(uuid) else { return nil }

        let pageTypePointer = UnsafeBufferPointer(
            start: baseAddress.advanced(by: pageTypeRange.lowerBound),
            count: pageTypeRange.count
        )
        guard let pageTypeValue = UInt8(String(decoding: pageTypePointer, as: UTF8.self)),
              let pageType = PageType(rawValue: pageTypeValue) else {
            return nil
        }

        let textPointer = UnsafeBufferPointer(
            start: baseAddress.advanced(by: textRange.lowerBound),
            count: textRange.count
        )
        let text = String(decoding: textPointer, as: UTF8.self)

        return TextSearchResult(
            uuid: uuid,
            text: text,
            pageType: pageType,
            language: language
        )
    }
}

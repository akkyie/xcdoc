import Compression
import Foundation

extension Data {
    func decompressedBrotli() throws -> Data {
        var index = 0
        let inputFilter = try InputFilter<Data>(.decompress, using: .brotli) { length in
            let rangeLength = Swift.min(length, self.count - index)
            guard rangeLength > 0 else { return nil }
            defer { index += rangeLength }
            return self.subdata(in: index ..< index + rangeLength)
        }

        var decompressed = Data()
        while let page = try inputFilter.readData(ofLength: 64 * 1024) {
            decompressed.append(page)
        }
        return decompressed
    }
}

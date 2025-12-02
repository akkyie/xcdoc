import CryptoKit
import Foundation

/// Documentation identifier computed from a language prefix and a path.
///
/// UUID format: `<lang_prefix><base64url(SHA1(path)[:6])>` where prefixes are
/// `ls` (Swift), `lc` (ObjC), and `ld` (Data). The same algorithm is used in
/// Xcode's `cache.db.refs` table for O(1) article lookup.
struct DocumentationUUID: CustomStringConvertible {
    let rawValue: String

    init?(rawValue: String) {
        let prefixes = DocumentationLanguage.allCases.map(\.uuidPrefix)
        guard prefixes.contains(where: { rawValue.hasPrefix($0) }), rawValue.count >= 10 else {
            return nil
        }
        self.rawValue = rawValue
    }

    init(path: String, language: DocumentationLanguage) {
        let digest = Insecure.SHA1.hash(data: Data(path.utf8))
        let first6Bytes = Array(digest.prefix(6))
        let base64 = Data(first6Bytes).base64EncodedString()
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        self.rawValue = language.uuidPrefix + base64url
    }

    var description: String { rawValue }
}

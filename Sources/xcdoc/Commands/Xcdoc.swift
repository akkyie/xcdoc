import ArgumentParser
import Foundation
import Subprocess

@main
struct Xcdoc: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcdoc",
        abstract: "A tool for exploring Xcode's offline documentation",
        discussion: """
            EXAMPLES:
              Search by keyword(s):
                $ xcdoc search UIView
                $ xcdoc search Objective-C Swift
                $ xcdoc search String +

              Show documentation:
                $ xcdoc show /documentation/swiftui/view
                $ xcdoc show "doc://com.apple.uikit/documentation/UIKit/UIView"
                $ xcdoc show xcdoc show "/documentation/swift/string/+(_:_:)-9fm57"

              Filter by language:
                $ xcdoc search NSView --objc
                $ xcdoc search View --swift
            """,
        subcommands: [ShowCommand.self, SearchCommand.self, ListCommand.self]
    )

    /// Resolves the root of Xcode's bundled offline documentation catalog.
    ///
    /// The catalog files live under
    /// `/Applications/Xcode.app/Contents/SharedFrameworks/DNTDocumentationSupport.framework/Resources/external`.
    /// We discover the active Xcode via `xcode-select -p`, then walk up to that
    /// `external` directory so every command can locate `navigator.index`,
    /// `cache.db`, the `fs/` chunk files, and the text search indexes.
    static func basePath() async throws -> URL {
        let developerDir: String
        do {
            let result = try await Subprocess.run(.name("xcode-select"), arguments: ["-p"], output: .string(limit: 1024))
            if let dir = result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines), !dir.isEmpty {
                developerDir = dir
            } else {
                developerDir = "/Applications/Xcode.app/Contents/Developer"
            }
        } catch {
            developerDir = "/Applications/Xcode.app/Contents/Developer"
        }

        let developerURL = URL(fileURLWithPath: developerDir)
        let xcodeApp = developerURL.deletingLastPathComponent().deletingLastPathComponent()

        guard FileManager.default.fileExists(atPath: xcodeApp.path) else {
            throw XcdocError.xcodeNotFound(path: xcodeApp.path)
        }

        let basePath = xcodeApp
            .appendingPathComponent("Contents")
            .appendingPathComponent("SharedFrameworks")
            .appendingPathComponent("DNTDocumentationSupport.framework")
            .appendingPathComponent("Resources")
            .appendingPathComponent("external")

        guard FileManager.default.fileExists(atPath: basePath.path) else {
            throw XcdocError.documentationNotFound(path: basePath)
        }

        return basePath
    }
}

enum XcdocError: Error, LocalizedError {
    case xcodeNotFound(path: String)
    case documentationNotFound(path: URL)

    var errorDescription: String? {
        switch self {
        case .xcodeNotFound(let path):
            return """
                Xcode not found at: \(path)

                Make sure Xcode is installed and selected:
                  $ xcode-select -p
                  $ sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
                """
        case .documentationNotFound(let path):
            return "Documentation not found at: \(path.path)"
        }
    }
}

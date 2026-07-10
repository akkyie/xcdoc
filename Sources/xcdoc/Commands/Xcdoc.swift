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

    /// Resolves the root of Xcode's offline documentation catalog.
    ///
    /// Through Xcode 26, the catalog files live under
    /// `/Applications/Xcode.app/Contents/SharedFrameworks/DNTDocumentationSupport.framework/Resources/external`.
    /// We discover the active Xcode via `xcode-select -p`, then walk up to that
    /// `external` directory so every command can locate `navigator.index`,
    /// `cache.db`, the `fs/` chunk files, and the text search indexes.
    ///
    /// Starting with Xcode 27, the app bundle no longer ships the catalog (its
    /// `external` directory only contains a `deleted` marker file). Instead the
    /// documentation is fetched as a MobileAsset under
    /// `/System/Library/AssetsV2/com_apple_MobileAsset_AppleDeveloperDocumentation`,
    /// but in the same on-disk format, so we fall back to locating it there.
    static func basePath() async throws -> URL {
        let developerDir: String
        do {
            let result = try await Subprocess.run(.name("xcode-select"), arguments: ["-p"], output: .string(limit: 1024))
            if result.terminationStatus.isSuccess,
                let dir = result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines), !dir.isEmpty
            {
                developerDir = dir
            } else {
                developerDir = "/Applications/Xcode.app/Contents/Developer"
            }
        } catch {
            developerDir = "/Applications/Xcode.app/Contents/Developer"
        }

        let developerURL = URL(fileURLWithPath: developerDir)
        let xcodeApp = developerURL.deletingLastPathComponent().deletingLastPathComponent()

        guard FileManager.default.fileExists(atPath: xcodeApp.appendingPathComponent("Contents/Info.plist").path) else {
            throw XcdocError.xcodeNotFound(path: xcodeApp.path)
        }

        let bundledPath = xcodeApp
            .appendingPathComponent("Contents")
            .appendingPathComponent("SharedFrameworks")
            .appendingPathComponent("DNTDocumentationSupport.framework")
            .appendingPathComponent("Resources")
            .appendingPathComponent("external")

        if FileManager.default.fileExists(atPath: bundledPath.appendingPathComponent("index/navigator.index").path) {
            return bundledPath
        }

        if let mobileAssetPath = mobileAssetDocumentationPath(xcodeApp: xcodeApp) {
            return mobileAssetPath
        }

        throw XcdocError.documentationNotFound(path: bundledPath)
    }

    /// Locates a downloaded MobileAsset documentation cache (Xcode 27+).
    ///
    /// Enumerates `*.asset` directories under the MobileAsset catalog and keeps
    /// only those containing a `documentation-cache` (some assets in the same
    /// catalog use an unrelated `documentation-db/index.sql` format). Among the
    /// candidates, prefers the one whose `XcodeVersion` matches the active Xcode;
    /// otherwise picks the one with the highest `DocumentationRelease`.
    private static func mobileAssetDocumentationPath(xcodeApp: URL) -> URL? {
        let xcodeVersion = (try? Data(contentsOf: xcodeApp.appendingPathComponent("Contents/Info.plist")))
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
            .flatMap { $0["CFBundleShortVersionString"] as? String }

        let catalogPath = URL(fileURLWithPath: "/System/Library/AssetsV2/com_apple_MobileAsset_AppleDeveloperDocumentation")
        guard let assetDirs = try? FileManager.default.contentsOfDirectory(at: catalogPath, includingPropertiesForKeys: nil) else {
            return nil
        }

        var bestRelease: (path: URL, release: Int)?

        for assetDir in assetDirs {
            let cachePath = assetDir.appendingPathComponent("AssetData/documentation-cache")
            guard FileManager.default.fileExists(atPath: cachePath.appendingPathComponent("index/navigator.index").path) else {
                continue
            }

            guard
                let plistData = try? Data(contentsOf: assetDir.appendingPathComponent("Info.plist")),
                let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                let properties = plist["MobileAssetProperties"] as? [String: Any]
            else {
                continue
            }

            if let assetXcodeVersion = properties["XcodeVersion"] as? String, assetXcodeVersion == xcodeVersion {
                return cachePath
            }

            if let releaseString = properties["DocumentationRelease"] as? String, let release = Int(releaseString) {
                if bestRelease == nil || release > bestRelease!.release {
                    bestRelease = (cachePath, release)
                }
            }
        }

        return bestRelease?.path
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
            return """
                Documentation not found at: \(path.path)

                Make sure the documentation has been downloaded in Xcode.
                """
        }
    }
}

import Foundation
import Subprocess
import System
import Testing

struct ShowTestCase: CustomTestStringConvertible, Sendable {
    let path: String

    var fullArguments: [String] {
        ["show", path]
    }

    var testDescription: String {
        (["xcdoc"] + fullArguments).joined(separator: " ")
    }
}

struct ShowCommandTests {
    static let testCases: [ShowTestCase] = [
        ShowTestCase(path: "/documentation/uikit/uiview"),
        ShowTestCase(path: "/documentation/uikit/uiview?language=objc"),
        ShowTestCase(path: "/documentation/uikit/uiview#Declaration"),
        ShowTestCase(path: "doc://com.apple.uikit/documentation/UIKit/UIView"),
        ShowTestCase(path: "swift/documentation/UIKit/UIView"),
        ShowTestCase(path: "/documentation/swift/string"),
        ShowTestCase(path: "/documentation/swift/string/+(_:_:)"),
        ShowTestCase(path: "/documentation/uikit/about-app-development-with-uikit"),
        // doc:// 形式のリンク
        ShowTestCase(path: "doc://com.apple.SwiftUI/documentation/SwiftUI/Text"),
        ShowTestCase(path: "doc://com.apple.uikit/documentation/UIKit/UIView#Alternatives-to-subclassing"),
        ShowTestCase(path: "doc://com.apple.documentation/documentation/Swift/String"),
        ShowTestCase(path: "/tutorials/swiftui/handling-user-input"),
        ShowTestCase(path: "data/documentation/appstoreserverapi"),
    ]

    static var xcdocPath: String {
        if let testBundlePath = ProcessInfo.processInfo.environment["XCTestBundlePath"] {
            return URL(fileURLWithPath: testBundlePath)
                .deletingLastPathComponent()
                .appendingPathComponent("xcdoc").path
        }

        let packageDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return packageDir.appendingPathComponent(".build/debug/xcdoc").path
    }

    @Test(arguments: testCases)
    func showCommand(_ testCase: ShowTestCase) async throws {
        let result = try await Subprocess.run(
            .path(FilePath(Self.xcdocPath)),
            arguments: Arguments(testCase.fullArguments),
            output: .string(limit: 1024 * 1024),
            error: .string(limit: 1024)
        )

        #expect(result.terminationStatus.isSuccess)
        #expect(result.standardError == "")
    }
}

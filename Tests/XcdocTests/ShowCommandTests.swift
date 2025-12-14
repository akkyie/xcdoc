import Foundation
import Subprocess
import System
import Testing

struct ShowTestCase: CustomTestStringConvertible, Sendable {
    let path: String
    let expected: String

    var fullArguments: [String] {
        ["show", path]
    }

    var testDescription: String {
        (["xcdoc"] + fullArguments).joined(separator: " ")
    }
}

struct ShowCommandTests {
    // Results captured with Xcode 26.1.1
    static let testCases: [ShowTestCase] = [
        ShowTestCase(
            path: "/documentation/uikit/uiview",
            expected: """
            # UIView

            Class
            """
        ),
        ShowTestCase(
            path: "/documentation/uikit/uiview?language=objc",
            expected: """
            # UIView

            Class
            """
        ),
        ShowTestCase(
            path: "/documentation/uikit/uiview#Declaration",
            expected: """
            # UIView

            Class
            """
        ),
        ShowTestCase(
            path: "doc://com.apple.uikit/documentation/UIKit/UIView",
            expected: """
            # UIView
            
            Class
            """
        ),
        ShowTestCase(
            path: "swift/documentation/UIKit/UIView",
            expected: """
            # UIView
            
            Class
            """
        ),
        ShowTestCase(
            path: "/documentation/swift/string",
            expected: """
            # String

            Structure
            """
        ),
        ShowTestCase(
            path: "/documentation/swift/string/+(_:_:)",
            expected: """
            # +(_:_:)
            
            Operator
            """
        ),
        ShowTestCase(
            path: "/documentation/uikit/about-app-development-with-uikit",
            expected: """
            # About App Development with UIKit

            Article
            """
        ),
        // doc:// 形式のリンク
        ShowTestCase(
            path: "doc://com.apple.SwiftUI/documentation/SwiftUI/Text",
            expected: """
            # Text

            Structure
            """
        ),
        ShowTestCase(
            path: "doc://com.apple.uikit/documentation/UIKit/UIView#Alternatives-to-subclassing",
            expected: """
            # UIView

            Class
            """
        ),
        ShowTestCase(
            path: "doc://com.apple.documentation/documentation/Swift/String",
            expected: """
            # String

            Structure
            """
        ),
        ShowTestCase(
            path: "/tutorials/swiftui/handling-user-input",
            expected: """
            # Handling user input
            """
        ),
        ShowTestCase(
            path: "data/documentation/appstoreserverapi",
            expected: """
            # App Store Server API

            Web Service
            """
        ),
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

        let actual = result.standardOutput ?? ""
        #expect(actual.starts(with: testCase.expected))

        #expect(result.standardError == "")
    }
}

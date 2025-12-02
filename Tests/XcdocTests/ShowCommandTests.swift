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

@Suite("Show Command E2E Tests")
struct ShowCommandTests {
    static let testCases: [ShowTestCase] = [
        ShowTestCase(
            path: "/documentation/uikit/uiview",
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
            path: "/documentation/swift/equatable",
            expected: """
            # Equatable

            Protocol
            """
        ),
        ShowTestCase(
            path: "/documentation/swift/result",
            expected: """
            # Result

            Enumeration
            """
        ),
        ShowTestCase(
            path: "/documentation/uikit/about-app-development-with-uikit",
            expected: """
            # About App Development with UIKit

            Article
            """
        ),
        ShowTestCase(
            path: "/documentation/swiftui/view",
            expected: """
            # View

            Protocol
            """
        ),
    ]

    static var xcdocPath: String {
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
            output: .string(limit: 1024 * 1024)
        )

        let actual = result.standardOutput ?? ""
        #expect(actual.starts(with: testCase.expected))
    }
}

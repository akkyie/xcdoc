import Foundation
import Subprocess
import System
import Testing

struct SearchTestCase: CustomTestStringConvertible, Sendable {
    let args: String

    var fullArguments: [String] {
        ["search", "--limit", "5"] + args.split(separator: " ").map(String.init)
    }

    var testDescription: String {
        (["xcdoc"] + fullArguments).joined(separator: " ")
    }
}

@Suite
struct SearchCommandTests {
    static let testCases: [SearchTestCase] = [
        SearchTestCase(args: "UIView --swift"),
        SearchTestCase(args: "UIView --objc"),
        SearchTestCase(args: "UIView"),
        SearchTestCase(args: "--swift UIView controller"),
        SearchTestCase(args: "table view cell --swift"),
        SearchTestCase(args: "life cycle app"),
        SearchTestCase(args: "--swift String +"),
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
    func searchCommand(_ testCase: SearchTestCase) async throws {
        let result = try await Subprocess.run(
            .path(FilePath(Self.xcdocPath)),
            arguments: Arguments(testCase.fullArguments),
            output: .string(limit: 1024),
            error: .string(limit: 1024)
        )

        #expect(result.terminationStatus.isSuccess)
        #expect(result.standardError == "")
    }
}

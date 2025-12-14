import Foundation
import Subprocess
import System
import Testing

struct SearchTestCase: CustomTestStringConvertible, Sendable {
    let args: String
    let expected: String

    var fullArguments: [String] {
        ["search", "--limit", "5"] + args.split(separator: " ").map(String.init)
    }

    var testDescription: String {
        (["xcdoc"] + fullArguments).joined(separator: " ")
    }
}

@Suite
struct SearchCommandTests {
    // Results captured with Xcode 26.1.1
    static let testCases: [SearchTestCase] = [
        SearchTestCase(
            args: "UIView --swift",
            expected: """
            [swift] UIView (Class - UIKit) /documentation/uikit/uiview
            [swift] uiView (Instance Property - UIKit) /documentation/uikit/nsuiviewtoolbaritem/uiview
            [swift] TipUIView (Class - TipKit) /documentation/tipkit/tipuiview
            [swift] UIViewType (Associated Type - SwiftUI) /documentation/swiftui/uiviewrepresentable/uiviewtype
            [swift] makeUIView(context:) (Instance Method - SwiftUI) /documentation/swiftui/uiviewrepresentable/makeuiview(context:)
            """
        ),
        SearchTestCase(
            args: "UIView --objc",
            expected: """
            [objc] UIView (Class - UIKit) /documentation/uikit/uiview
            [objc] uiView (Instance Property - UIKit) /documentation/uikit/nsuiviewtoolbaritem/uiview
            [objc] IKFilterUIView (Class - Quartz) /documentation/quartz/ikfilteruiview
            [objc] UIViewAnimating (Protocol - UIKit) /documentation/uikit/uiviewanimating
            [objc] UIViewController (Class - UIKit) /documentation/uikit/uiviewcontroller
            """
        ),
        SearchTestCase(
            args: "UIView",
            expected: """
            [swift] UIView (Class - UIKit) /documentation/uikit/uiview
            [objc] UIView (Class - UIKit) /documentation/uikit/uiview
            [swift] uiView (Instance Property - UIKit) /documentation/uikit/nsuiviewtoolbaritem/uiview
            [objc] uiView (Instance Property - UIKit) /documentation/uikit/nsuiviewtoolbaritem/uiview
            [swift] TipUIView (Class - TipKit) /documentation/tipkit/tipuiview
            """
        ),
        SearchTestCase(
            args: "--swift UIView controller",
            expected: """
            [swift] UIViewController (Class - UIKit) /documentation/uikit/uiviewcontroller
            [swift] UIViewControllerType (Associated Type - SwiftUI) /documentation/swiftui/uiviewcontrollerrepresentable/uiviewcontrollertype
            [swift] makeUIViewController(context:) (Instance Method - SwiftUI) /documentation/swiftui/uiviewcontrollerrepresentable/makeuiviewcontroller(context:)
            [swift] updateUIViewController(_:context:) (Instance Method - SwiftUI) /documentation/swiftui/uiviewcontrollerrepresentable/updateuiviewcontroller(_:context:)
            [swift] dismantleUIViewController(_:coordinator:) (Instance Method - SwiftUI) /documentation/swiftui/uiviewcontrollerrepresentable/dismantleuiviewcontroller(_:coordinator:)
            """
        ),
        SearchTestCase(
            args: "table view cell --swift",
            expected: """
            [swift] UITableViewCell (Class - UIKit) /documentation/uikit/uitableviewcell
            [swift] NSTableCellView (Class - AppKit) /documentation/appkit/nstablecellview
            [swift] tableView(_:cellForRowAt:) (Instance Method - UIKit) /documentation/uikit/uitableviewdatasource/tableview(_:cellforrowat:)
            [swift] tableView(_:dataCellFor:row:) (Instance Method - AppKit) /documentation/appkit/nstableviewdelegate/tableview(_:datacellfor:row:)
            [swift] tableView(_:shouldTrackCell:for:row:) (Instance Method - AppKit) /documentation/appkit/nstableviewdelegate/tableview(_:shouldtrackcell:for:row:)
            """
        ),
        SearchTestCase(
            args: "life cycle app",
            expected: """
            [swift] Managing your app’s life cycle (API Collection - UIKit) /documentation/uikit/managing-your-app-s-life-cycle
            [objc] Managing your app’s life cycle (API Collection - UIKit) /documentation/uikit/managing-your-app-s-life-cycle
            [swift] Managing state and life cycle (Tutorial) /tutorials/app-dev-training/managing-state-and-life-cycle
            [swift] Working with the watchOS app life cycle (Article - WatchKit) /documentation/watchkit/working-with-the-watchos-app-life-cycle
            [objc] Working with the watchOS app life cycle (Article - WatchKit) /documentation/watchkit/working-with-the-watchos-app-life-cycle
            """
        ),
        SearchTestCase(
            args: "--swift String +",
            expected: """
            [swift] +(_:_:) (Operator - Swift) /documentation/swift/string/+(_:_:)
            [swift] +=(_:_:) (Operator - Swift) /documentation/swift/string/+=(_:_:)
            [swift] +(_:_:) (Operator - Swift) /documentation/swift/string/+(_:_:)-n329
            [swift] +(_:_:) (Operator - Swift) /documentation/swift/string/+(_:_:)-6h59y
            [swift] +(_:_:) (Operator - Swift) /documentation/swift/string/+(_:_:)-9fm57
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
    func searchCommand(_ testCase: SearchTestCase) async throws {
        let result = try await Subprocess.run(
            .path(FilePath(Self.xcdocPath)),
            arguments: Arguments(testCase.fullArguments),
            output: .string(limit: 1024)
        )

        let output = result.standardOutput ?? ""
        let actual = output.components(separatedBy: "\n")
            .filter { !$0.isEmpty && !$0.hasPrefix("...") }
            .joined(separator: "\n")

        #expect(actual == testCase.expected.trimmingCharacters(in: .newlines))
    }
}

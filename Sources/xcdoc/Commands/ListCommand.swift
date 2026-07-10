import ArgumentParser
import Foundation
import SwiftDocC

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List documentation categories"
    )

    @Option(name: .shortAndLong, help: "Maximum depth to display (default: 2)")
    var depth: Int = 2

    func run() async throws {
        let basePath = try await Xcdoc.basePath()
        let url = basePath
            .appendingPathComponent("index")
            .appendingPathComponent("navigator.index")
        let tree = NavigatorTree()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            do {
                try tree.read(
                    from: url,
                    timeout: 5,
                    queue: DispatchQueue.global()
                ) { _, isCompleted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if isCompleted {
                        continuation.resume()
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }

        let pathIndex = try PathSearchIndex(basePath: basePath)
        printChildren(
            children: tree.root.children,
            currentDepth: 0,
            indentLevel: 0,
            maxDepth: depth,
            pathIndex: pathIndex
        )
    }

    private func printChildren(
        children: [NavigatorTree.Node],
        currentDepth: Int,
        indentLevel: Int,
        maxDepth: Int,
        pathIndex: PathSearchIndex
    ) {
        guard currentDepth < maxDepth else { return }

        var memberIndentLevel = indentLevel
        for child in children {
            let item = child.item
            let isGroupMarker = item.pageType == NavigatorIndex.PageType.groupMarker.rawValue
            let displayIndentLevel = isGroupMarker ? indentLevel : memberIndentLevel
            let indent = String(repeating: "  ", count: displayIndentLevel)
            let path = child.id.flatMap { pathIndex.path(for: $0) } ?? ""
            if path.isEmpty {
                print("\(indent)- \(item.title)")
            } else {
                print("\(indent)- \(item.title) \(path)")
            }

            if isGroupMarker {
                memberIndentLevel = indentLevel + 1
            } else {
                printChildren(
                    children: child.children,
                    currentDepth: currentDepth + 1,
                    indentLevel: memberIndentLevel + 1,
                    maxDepth: maxDepth,
                    pathIndex: pathIndex
                )
            }
        }
    }
}

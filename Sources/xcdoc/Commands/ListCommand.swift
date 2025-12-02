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
            maxDepth: depth,
            pathIndex: pathIndex
        )
    }

    private func printChildren(
        children: [NavigatorTree.Node],
        currentDepth: Int,
        maxDepth: Int,
        pathIndex: PathSearchIndex
    ) {
        guard currentDepth < maxDepth else { return }

        for child in children {
            let item = child.item
            let indent = String(repeating: "  ", count: currentDepth)
            let path = child.id.flatMap { pathIndex.path(for: $0) } ?? ""
            if path.isEmpty {
                print("\(indent)- \(item.title)")
            } else {
                print("\(indent)- \(item.title) \(path)")
            }

            printChildren(
                children: child.children,
                currentDepth: currentDepth + 1,
                maxDepth: maxDepth,
                pathIndex: pathIndex
            )
        }
    }
}

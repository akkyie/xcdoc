enum DocumentationLanguage: Int, CaseIterable {
    case swift = 0
    case objc = 1
    case other = 3

    var uuidPrefix: String {
        switch self {
        case .swift: return "ls"
        case .objc: return "lc"
        case .other: return "ld"
        }
    }

    var pathPrefix: String {
        switch self {
        case .swift: return "swift/"
        case .objc: return "objective-c/"
        case .other: return "data/"
        }
    }

    var indexFilename: String { "\(rawValue).txt" }

    var searchOrder: Int {
        switch self {
        case .swift: return 0
        case .objc: return 1
        case .other: return 2
        }
    }

    var name: String {
        switch self {
        case .swift: return "swift"
        case .objc: return "objc"
        case .other: return "other"
        }
    }
}

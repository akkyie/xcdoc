enum PageType: UInt8 {
    case unknown = 0
    case framework = 1
    case apiCollection = 2
    case globalVariable = 7
    case typeAlias = 8
    case associatedType = 9
    case function = 10
    case `operator` = 11
    case macro = 12
    case enumeration = 14
    case enumerationCase = 15
    case structure = 16
    case `class` = 17
    case `protocol` = 18
    case initializer = 19
    case instanceMethod = 20
    case instanceProperty = 21
    case shaderGraphNode = 22
    case typeMethod = 24
    case typeProperty = 25
    case article = 28
    case sampleCode = 29
    case propertyListKey = 32
    case tutorial = 34
    case featured = 35
    case tutorialTop = 36

    var label: String {
        switch self {
        case .unknown: return "Unknown"
        case .framework: return "Framework"
        case .apiCollection: return "API Collection"
        case .globalVariable: return "Global Variable"
        case .typeAlias: return "Type Alias"
        case .associatedType: return "Associated Type"
        case .function: return "Function"
        case .operator: return "Operator"
        case .macro: return "Macro"
        case .enumeration: return "Enumeration"
        case .enumerationCase: return "Case"
        case .structure: return "Structure"
        case .class: return "Class"
        case .protocol: return "Protocol"
        case .initializer: return "Initializer"
        case .instanceMethod: return "Instance Method"
        case .instanceProperty: return "Instance Property"
        case .shaderGraphNode: return "ShaderGraph Node"
        case .typeMethod: return "Type Method"
        case .typeProperty: return "Type Property"
        case .article: return "Article"
        case .sampleCode: return "Sample Code"
        case .propertyListKey: return "Property List Key"
        case .tutorial: return "Tutorial"
        case .featured: return "Featured"
        case .tutorialTop: return "Tutorial"
        }
    }
}

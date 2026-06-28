import Foundation

struct AutocompleteSuggestion: Identifiable, Equatable {
    enum Kind: Int, Equatable {
        case variable
        case function
        case builtInConstant
        case builtInFunction
    }

    let id: String
    let name: String
    let insertionText: String
    let displayText: String
    let detailText: String?
    let kind: Kind

    init(name: String, insertionText: String? = nil, displayText: String? = nil, detailText: String? = nil, kind: Kind) {
        self.name = name
        self.insertionText = insertionText ?? name
        self.displayText = displayText ?? name
        self.detailText = detailText
        self.kind = kind
        id = "\(kind.rawValue):\(name)"
    }
}

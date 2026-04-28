import Foundation

enum SourceKind: String, Codable, CaseIterable, Hashable {
    case claudeSkills
    case codexSkills
    case cursorSkills
    case cursorRules

    var displayName: String {
        switch self {
        case .claudeSkills: return "Claude Skills"
        case .codexSkills:  return "Codex Skills"
        case .cursorSkills: return "Cursor Skills"
        case .cursorRules:  return "Cursor Rules"
        }
    }

    var iconSymbol: String {
        switch self {
        case .claudeSkills: return "brain"
        case .codexSkills:  return "bolt"
        case .cursorSkills: return "target"
        case .cursorRules:  return "ruler"
        }
    }
}

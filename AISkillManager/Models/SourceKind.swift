import Foundation

enum SourceKind: String, Codable, CaseIterable, Hashable {
    case claudeSkills
    case codexSkills
    case cursorSkills
    case cursorRules
    case agentsMd

    var displayName: String {
        switch self {
        case .claudeSkills: return "Claude Skills"
        case .codexSkills:  return "Codex Skills"
        case .cursorSkills: return "Cursor Skills"
        case .cursorRules:  return "Cursor Rules"
        case .agentsMd:     return "Agents.md"
        }
    }

    var iconSymbol: String {
        switch self {
        case .claudeSkills: return "brain"
        case .codexSkills:  return "bolt"
        case .cursorSkills: return "target"
        case .cursorRules:  return "ruler"
        case .agentsMd:     return "doc.plaintext"
        }
    }
}

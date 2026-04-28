import Foundation
import CryptoKit

struct SkillItemID: Hashable, Codable {
    let kind: SourceKind
    let scopeKey: String
    let pathFingerprint: String

    static func make(kind: SourceKind, scope: SourceScope, mainFileURL: URL) -> SkillItemID {
        let path = mainFileURL.standardizedFileURL.path
        let digest = Insecure.SHA1.hash(data: Data(path.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return SkillItemID(
            kind: kind,
            scopeKey: scope.key,
            pathFingerprint: String(hex.prefix(12))
        )
    }
}

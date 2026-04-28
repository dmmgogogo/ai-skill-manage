import Foundation
import Yams

enum YAMLFrontmatter {
    struct Shallow {
        var name: String?
        var description: String?
    }

    /// Shallow-parses YAML frontmatter from a markdown file's content. Only extracts `name` and `description`.
    /// Returns empty fields on parse failure (does not throw).
    static func parseShallow(from content: String) -> Shallow {
        guard let yamlBlock = extractFrontmatterBlock(content) else {
            return Shallow()
        }

        do {
            guard let dict = try Yams.load(yaml: yamlBlock) as? [String: Any] else {
                return Shallow()
            }
            return Shallow(
                name: dict["name"] as? String,
                description: dict["description"] as? String
            )
        } catch {
            return Shallow()
        }
    }

    /// Extracts content between the first `---` ... `---` pair. Returns nil if file doesn't start with `---`.
    private static func extractFrontmatterBlock(_ content: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        guard let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" else {
            return nil
        }
        var block: [String] = []
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                return block.joined(separator: "\n")
            }
            block.append(line)
        }
        return nil
    }
}

import XCTest
@testable import AISkillManager

final class YAMLFrontmatterTests: XCTestCase {
    func test_parse_normal_frontmatter() {
        let content = """
        ---
        name: design
        description: Use when building UI
        ---

        # Design skill
        body content
        """

        let result = YAMLFrontmatter.parseShallow(from: content)
        XCTAssertEqual(result.name, "design")
        XCTAssertEqual(result.description, "Use when building UI")
    }

    func test_parse_no_frontmatter() {
        let content = "Just markdown without frontmatter"
        let result = YAMLFrontmatter.parseShallow(from: content)
        XCTAssertNil(result.name)
        XCTAssertNil(result.description)
    }

    func test_parse_invalid_yaml() {
        let content = """
        ---
        name: design
        description: : invalid : yaml :
        ---

        body
        """

        let result = YAMLFrontmatter.parseShallow(from: content)
        // Parse failure must NOT throw — return nil fields
        XCTAssertNil(result.name)
        XCTAssertNil(result.description)
    }

    func test_parse_quoted_strings() {
        let content = """
        ---
        name: "playwright"
        description: "Use when automating a browser"
        ---
        """

        let result = YAMLFrontmatter.parseShallow(from: content)
        XCTAssertEqual(result.name, "playwright")
        XCTAssertEqual(result.description, "Use when automating a browser")
    }

    func test_parse_only_name() {
        let content = """
        ---
        name: minimal
        ---
        """

        let result = YAMLFrontmatter.parseShallow(from: content)
        XCTAssertEqual(result.name, "minimal")
        XCTAssertNil(result.description)
    }

    func test_parse_with_extra_fields() {
        // Extra fields must not break name/description extraction
        let content = """
        ---
        name: design
        description: foo
        metadata:
          version: "3.8.0"
        alwaysApply: true
        ---
        """

        let result = YAMLFrontmatter.parseShallow(from: content)
        XCTAssertEqual(result.name, "design")
        XCTAssertEqual(result.description, "foo")
    }
}

# AGENTS.md Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `agentsMd` SourceKind 和 `AgentsMdRepo`，让 App 能扫描并展示 `~/AGENTS.md`、`~/.codex/README.md`（用户级）以及 `<project>/AGENTS.md`（项目级）。

**Architecture:** 遵循现有 `CursorRulesRepo` 模式——单文件型 repo，`listAll()` 遍历候选 URL 列表，文件存在则返回 SkillItem，不存在跳过。`AgentsMdRepo` 通过 `candidates: [URL]` 注入候选路径，方便测试。

**Tech Stack:** Swift, XCTest, macOS FileManager

---

## File Map

| 操作 | 文件 |
|------|------|
| 新建 | `AISkillManager/Repositories/AgentsMdRepo.swift` |
| 新建 | `AISkillManagerTests/AgentsMdRepoTests.swift` |
| 新建 | `AISkillManagerTests/Fixtures/agents-md/AGENTS.md` |
| 新建 | `AISkillManagerTests/Fixtures/agents-md/codex-readme/README.md` |
| 修改 | `AISkillManager/Models/SourceKind.swift` |
| 修改 | `AISkillManager/ViewModels/AppStore.swift` |
| 修改 | `AISkillManagerTests/AppStoreTests.swift` |
| 修改 | `AISkillManager/Views/SidebarView.swift` |

---

### Task 1: 在 `SourceKind` 加 `.agentsMd` case

**Files:**
- Modify: `AISkillManager/Models/SourceKind.swift`

- [ ] **Step 1: 修改 SourceKind.swift**

将文件改为：

```swift
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
```

- [ ] **Step 2: 编译确认无报错**

```bash
cd /Users/mmx/Documents/work/Github/ai-skill-manage
xcodebuild build -scheme AISkillManager -destination 'platform=macOS' 2>&1 | tail -5
```

期望：`** BUILD SUCCEEDED **`

- [ ] **Step 3: commit**

```bash
git add AISkillManager/Models/SourceKind.swift
git commit -m "feat: add agentsMd to SourceKind"
```

---

### Task 2: 创建测试 Fixture 文件

**Files:**
- Create: `AISkillManagerTests/Fixtures/agents-md/AGENTS.md`
- Create: `AISkillManagerTests/Fixtures/agents-md/codex-readme/README.md`

- [ ] **Step 1: 创建 agents-md fixture 目录并写 AGENTS.md**

```
AISkillManagerTests/Fixtures/agents-md/AGENTS.md 内容：
```

```markdown
# AGENTS.md

本文件为 Codex 在项目中工作时提供指导。

## 规则

- 禁止使用 git worktree
```

- [ ] **Step 2: 创建 codex-readme fixture**

```
AISkillManagerTests/Fixtures/agents-md/codex-readme/README.md 内容：
```

```markdown
# Codex README

用户级 Codex 全局指导文件。
```

- [ ] **Step 3: 将两个 fixture 文件加入 Xcode target**

在 Xcode 中把这两个文件加入 `AISkillManagerTests` target 的 `Copy Bundle Resources` build phase（和已有的 cursor-rules、dir-source fixtures 方式相同）。

> 注意：如果项目用 `project.yml` (xcodegen) 管理，需要确认 fixture 目录已包含在 `AISkillManagerTests` sources 或 resources 中。

- [ ] **Step 4: commit**

```bash
git add AISkillManagerTests/Fixtures/agents-md/
git commit -m "test: add agents-md fixtures"
```

---

### Task 3: 写失败的 `AgentsMdRepoTests`

**Files:**
- Create: `AISkillManagerTests/AgentsMdRepoTests.swift`

- [ ] **Step 1: 创建测试文件**

```swift
import XCTest
@testable import AISkillManager

final class AgentsMdRepoTests: XCTestCase {

    // MARK: - Helpers

    private var fixtureBase: URL {
        Bundle(for: type(of: self))
            .url(forResource: "agents-md", withExtension: nil)!
    }

    private var agentsMdURL: URL {
        fixtureBase.appendingPathComponent("AGENTS.md")
    }

    private var codexReadmeURL: URL {
        fixtureBase.appendingPathComponent("codex-readme/README.md")
    }

    private func makeUserRepo(candidates: [URL]? = nil) -> AgentsMdRepo {
        AgentsMdRepo(scope: .user, candidates: candidates ?? [agentsMdURL, codexReadmeURL])
    }

    private func makeProjectRepo(projectRoot: URL) -> AgentsMdRepo {
        AgentsMdRepo(scope: .project(Project(name: "test", path: projectRoot)),
                     candidates: [projectRoot.appendingPathComponent("AGENTS.md")])
    }

    // MARK: - listAll

    func test_listAll_finds_both_candidates_when_both_exist() throws {
        let items = try makeUserRepo().listAll()
        XCTAssertEqual(items.count, 2)
    }

    func test_listAll_skips_missing_candidate() throws {
        let bogus = fixtureBase.appendingPathComponent("does-not-exist.md")
        let repo = AgentsMdRepo(scope: .user, candidates: [agentsMdURL, bogus])
        let items = try repo.listAll()
        XCTAssertEqual(items.count, 1)
    }

    func test_listAll_returns_empty_when_no_candidates_exist() throws {
        let bogus1 = fixtureBase.appendingPathComponent("no1.md")
        let bogus2 = fixtureBase.appendingPathComponent("no2.md")
        let repo = AgentsMdRepo(scope: .user, candidates: [bogus1, bogus2])
        let items = try repo.listAll()
        XCTAssertTrue(items.isEmpty)
    }

    func test_listAll_name_is_filename_without_extension() throws {
        let repo = AgentsMdRepo(scope: .user, candidates: [agentsMdURL])
        let items = try repo.listAll()
        XCTAssertEqual(items.first?.name, "AGENTS")
    }

    func test_listAll_containerURL_is_nil() throws {
        let items = try makeUserRepo().listAll()
        XCTAssertTrue(items.allSatisfy { $0.containerURL == nil })
    }

    func test_listAll_hasSubdirectories_is_false() throws {
        let items = try makeUserRepo().listAll()
        XCTAssertTrue(items.allSatisfy { $0.hasSubdirectories == false })
    }

    func test_listAll_rawContent_is_not_empty() throws {
        let repo = AgentsMdRepo(scope: .user, candidates: [agentsMdURL])
        let items = try repo.listAll()
        XCTAssertFalse(items.first?.rawContent.isEmpty ?? true)
    }

    func test_listAll_kind_is_agentsMd() throws {
        let items = try makeUserRepo().listAll()
        XCTAssertTrue(items.allSatisfy { $0.kind == .agentsMd })
    }

    // MARK: - rootExists

    func test_rootExists_always_true() {
        XCTAssertTrue(makeUserRepo().rootExists)
    }

    // MARK: - createSkill

    func test_createSkill_creates_agents_md_when_not_present() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentsMd-create-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let target = tmp.appendingPathComponent("AGENTS.md")
        let repo = AgentsMdRepo(scope: .user, candidates: [target])
        let item = try repo.createSkill(name: "ignored")

        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        XCTAssertEqual(item.kind, .agentsMd)
        XCTAssertFalse(item.rawContent.isEmpty)
    }

    func test_createSkill_throws_nameCollision_when_file_exists() throws {
        let repo = AgentsMdRepo(scope: .user, candidates: [agentsMdURL])
        XCTAssertThrowsError(try repo.createSkill(name: "anything")) { error in
            guard case SkillRepositoryError.nameCollision = error else {
                XCTFail("Expected nameCollision, got \(error)")
                return
            }
        }
    }

    // MARK: - save

    func test_save_writes_new_content() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentsMd-save-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let target = tmp.appendingPathComponent("AGENTS.md")
        let repo = AgentsMdRepo(scope: .user, candidates: [target])
        let created = try repo.createSkill(name: "x")

        let updated = try repo.save(item: created, content: "# Updated\n\nNew content.")
        XCTAssertEqual(updated.rawContent, "# Updated\n\nNew content.")
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "# Updated\n\nNew content.")
    }

    // MARK: - deleteItem

    func test_deleteItem_removes_file() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentsMd-delete-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let target = tmp.appendingPathComponent("AGENTS.md")
        let repo = AgentsMdRepo(scope: .user, candidates: [target])
        let item = try repo.createSkill(name: "x")

        try repo.deleteItem(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }
}
```

- [ ] **Step 2: 运行测试，确认编译失败（AgentsMdRepo 未定义）**

```bash
xcodebuild test -scheme AISkillManager \
  -destination 'platform=macOS' \
  -only-testing AISkillManagerTests/AgentsMdRepoTests \
  2>&1 | grep -E "(error:|FAILED|PASSED)"
```

期望：编译错误 `cannot find type 'AgentsMdRepo'`

- [ ] **Step 3: commit**

```bash
git add AISkillManagerTests/AgentsMdRepoTests.swift
git commit -m "test: add AgentsMdRepoTests (failing)"
```

---

### Task 4: 实现 `AgentsMdRepo`

**Files:**
- Create: `AISkillManager/Repositories/AgentsMdRepo.swift`

- [ ] **Step 1: 创建 AgentsMdRepo.swift**

```swift
import Foundation

final class AgentsMdRepo: SkillRepository {
    let kind: SourceKind = .agentsMd
    let scope: SourceScope

    // 候选文件 URL 列表，按顺序检查。listAll() 返回所有存在的；
    // createSkill() 在第一个候选路径创建文件。
    private let candidateURLs: [URL]

    static func defaultUserCandidates() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("AGENTS.md"),
            home.appendingPathComponent(".codex/README.md"),
        ]
    }

    /// 通用初始化器，测试时通过 candidates 注入 mock 路径。
    init(scope: SourceScope = .user, candidates: [URL]? = nil) {
        self.scope = scope
        self.candidateURLs = candidates ?? Self.defaultUserCandidates()
    }

    /// 项目级便捷初始化器。
    convenience init(scope: SourceScope, projectRoot: URL) {
        self.init(scope: scope,
                  candidates: [projectRoot.appendingPathComponent("AGENTS.md")])
    }

    // rootExists 始终为 true：候选文件散落在固定位置，无统一根目录。
    var rootExists: Bool { true }

    func listAll() throws -> [SkillItem] {
        let fm = FileManager.default
        return candidateURLs.compactMap { url in
            guard fm.fileExists(atPath: url.path) else { return nil }
            return makeItem(fileURL: url)
        }
    }

    private func makeItem(fileURL: URL) -> SkillItem? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        let attrs = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)) ?? [:]
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        let size  = (attrs[.size] as? Int) ?? 0
        let name  = fileURL.deletingPathExtension().lastPathComponent
        return SkillItem(
            id: SkillItemID.make(kind: kind, scope: scope, mainFileURL: fileURL),
            kind: kind,
            scope: scope,
            mainFileURL: fileURL,
            containerURL: nil,
            name: name,
            description: "",
            rawContent: content,
            fileModifiedAt: mtime,
            sizeBytes: size,
            hasSubdirectories: false
        )
    }

    func save(item: SkillItem, content: String) throws -> SkillItem {
        try AtomicWriter.write(content, to: item.mainFileURL)
        let attrs = try FileManager.default.attributesOfItem(atPath: item.mainFileURL.path)
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        let size  = (attrs[.size] as? Int) ?? 0
        return SkillItem(
            id: item.id,
            kind: item.kind,
            scope: item.scope,
            mainFileURL: item.mainFileURL,
            containerURL: nil,
            name: item.name,
            description: item.description,
            rawContent: content,
            fileModifiedAt: mtime,
            sizeBytes: size,
            hasSubdirectories: false
        )
    }

    func createSkill(name: String) throws -> SkillItem {
        guard let target = candidateURLs.first else {
            throw SkillRepositoryError.invalidName(reason: "无候选文件路径")
        }
        if FileManager.default.fileExists(atPath: target.path) {
            throw SkillRepositoryError.nameCollision(name: target.lastPathComponent,
                                                     existingPath: target)
        }
        // 确保父目录存在（如 ~/.codex/）
        let parent = target.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        let template = """
        # \(target.lastPathComponent)

        在这里写项目级 Codex 指导内容。
        """
        try template.write(to: target, atomically: true, encoding: .utf8)

        let attrs = (try? FileManager.default.attributesOfItem(atPath: target.path)) ?? [:]
        let mtime = (attrs[.modificationDate] as? Date) ?? Date()
        let size  = (attrs[.size] as? Int) ?? 0
        let itemName = target.deletingPathExtension().lastPathComponent

        return SkillItem(
            id: SkillItemID.make(kind: kind, scope: scope, mainFileURL: target),
            kind: kind,
            scope: scope,
            mainFileURL: target,
            containerURL: nil,
            name: itemName,
            description: "",
            rawContent: template,
            fileModifiedAt: mtime,
            sizeBytes: size,
            hasSubdirectories: false
        )
    }

    func deleteItem(_ item: SkillItem) throws {
        try FileManager.default.trashItem(at: item.mainFileURL, resultingItemURL: nil)
    }
}
```

- [ ] **Step 2: 运行 AgentsMdRepoTests，确认全部通过**

```bash
xcodebuild test -scheme AISkillManager \
  -destination 'platform=macOS' \
  -only-testing AISkillManagerTests/AgentsMdRepoTests \
  2>&1 | grep -E "(error:|Test.*passed|Test.*failed|FAILED|PASSED)"
```

期望：所有测试 PASSED。

- [ ] **Step 3: commit**

```bash
git add AISkillManager/Repositories/AgentsMdRepo.swift
git commit -m "feat: implement AgentsMdRepo"
```

---

### Task 5: 更新 `AppStore`，接入 `AgentsMdRepo`

**Files:**
- Modify: `AISkillManager/ViewModels/AppStore.swift:32-51`

- [ ] **Step 1: 修改 `makeDefault()` 和 `makeProjectRepos(for:)`**

将 `AppStore.swift` 中这两个方法改为：

```swift
static func makeDefault(registry: ProjectRegistry? = nil) -> AppStore {
    AppStore(
        repos: [
            ClaudeSkillsRepo(),
            CodexSkillsRepo(),
            CursorSkillsRepo(),
            CursorRulesRepo(),
            AgentsMdRepo(),                          // 用户级：~/AGENTS.md + ~/.codex/README.md
        ],
        registry: registry
    )
}

static func makeProjectRepos(for project: Project) -> [SkillRepository] {
    let scope: SourceScope = .project(project)
    return [
        DirectorySkillRepoBase(kind: .claudeSkills, scope: scope, root: project.path.appendingPathComponent(".claude/skills")),
        DirectorySkillRepoBase(kind: .codexSkills,  scope: scope, root: project.path.appendingPathComponent(".codex/skills")),
        DirectorySkillRepoBase(kind: .cursorSkills, scope: scope, root: project.path.appendingPathComponent(".cursor/skills")),
        CursorRulesRepo(scope: scope, root: project.path.appendingPathComponent(".cursor/rules")),
        AgentsMdRepo(scope: scope, projectRoot: project.path),  // 项目级：<project>/AGENTS.md
    ]
}
```

- [ ] **Step 2: 编译确认无报错**

```bash
xcodebuild build -scheme AISkillManager -destination 'platform=macOS' 2>&1 | tail -5
```

期望：`** BUILD SUCCEEDED **`

- [ ] **Step 3: commit**

```bash
git add AISkillManager/ViewModels/AppStore.swift
git commit -m "feat: wire AgentsMdRepo into AppStore"
```

---

### Task 6: 修复 `AppStoreTests` 中硬编码的 repo 数量断言

**Files:**
- Modify: `AISkillManagerTests/AppStoreTests.swift`

背景：`makeProjectRepos()` 现在返回 5 个 repo（原来是 4 个），导致两个计数断言失效：
- `test_addProject_appends_4_repos`：stub 有 4 个用户级 repo，加一个项目后 4+5=9
- `test_removeProject_removes_repos`：移除项目后回到 4

- [ ] **Step 1: 更新断言**

在 `test_addProject_appends_4_repos` 中：

```swift
// 修改前：
XCTAssertEqual(store.repos.count, 8)
// 修改后：
XCTAssertEqual(store.repos.count, 9)
```

在 `test_removeProject_removes_repos` 中：

```swift
// 修改前：
XCTAssertEqual(store.repos.count, 8)
// 修改后：
XCTAssertEqual(store.repos.count, 9)

// 修改前：
XCTAssertEqual(store.repos.count, 4)
// 修改后（移除后回到 stub 的 4 个）：
XCTAssertEqual(store.repos.count, 4)   // 这行不变
```

- [ ] **Step 2: 运行全部测试，确认全部通过**

```bash
xcodebuild test -scheme AISkillManager \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|Test.*failed|FAILED|PASSED|** TEST)"
```

期望：`** TEST SUCCEEDED **`

- [ ] **Step 3: commit**

```bash
git add AISkillManagerTests/AppStoreTests.swift
git commit -m "test: update repo count assertions for agentsMd"
```

---

### Task 7: 更新 `SidebarView` 提示文案

**Files:**
- Modify: `AISkillManager/Views/SidebarView.swift:145`

- [ ] **Step 1: 更新 Open Panel 提示文字**

将：

```swift
panel.message = "选择一个项目根目录（包含 .claude/skills、.codex/skills、.cursor/rules 任一即可）"
```

改为：

```swift
panel.message = "选择一个项目根目录（包含 .claude/skills、.codex/skills、.cursor/rules、AGENTS.md 任一即可）"
```

- [ ] **Step 2: 编译 + 全量测试**

```bash
xcodebuild test -scheme AISkillManager \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|FAILED|PASSED|** TEST)"
```

期望：`** TEST SUCCEEDED **`

- [ ] **Step 3: commit**

```bash
git add AISkillManager/Views/SidebarView.swift
git commit -m "feat: add AGENTS.md support — complete"
```

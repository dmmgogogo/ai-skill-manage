# AI Skill Manager — 设计文档

**日期**: 2026-04-28
**作者**: mmx + Claude
**状态**: Draft（待用户最终确认）

---

## 1. 一句话定位

一款 macOS 原生 App，把本机上 **Claude / Codex / Cursor** 三家工具的 skill / rule 配置文件聚合在一个三栏窗口里，支持读、改、新建、删除。

非目标（明确不做）：
- 不做 iOS 端
- 不做云端同步、iCloud 镜像、跨机器协作
- 不做 ChatGPT / Custom GPT / 自定义指令
- 不做"启停"（enabled toggle）、收藏、标签、版本历史
- 不上 Mac App Store（分发走 Developer ID + 公证 + Sparkle）
- 不做 frontmatter 表单编辑（MVP 走纯 Raw 模式）

---

## 2. 用户与场景

**单一用户**：开发者本人。常用 Claude Code、Codex CLI、Cursor IDE，三家各自维护 skill / rule 文件已成日常。

**核心痛点**：要在三个不同目录之间跳来跳去查找"我有没有写过类似的 skill"、"这条 rule 内容是什么"，效率低。

**核心场景**：
1. 想知道当前所有 skill / rule 的总览（看 List）
2. 找某条具体 skill 的内容（搜索 + 读 Detail）
3. 调整某条 skill 的写法（编辑 + 保存）
4. 新建一条 skill 到指定平台
5. 删除不再用的旧 skill

---

## 3. 数据源与目录约定

### 3.1 用户级（4 个源 × 1 个位置）

| 源 | 路径 | 形态 |
|---|---|---|
| Claude Skills | `~/.claude/skills/<name>/SKILL.md` | 目录式 |
| Codex Skills | `~/.codex/skills/<name>/SKILL.md` | 目录式 |
| Cursor Rules | `~/.cursor/rules/*.mdc` | 单文件 |
| Cursor Skills | `~/.cursor/skills/<name>/SKILL.md` | 目录式 |

**显式排除**：`~/.claude/plugins/cache/` 下的插件 skill 不展示（只读、会被同步覆盖）。

### 3.2 项目级（用户手动添加）

用户在 Sidebar 通过 "＋ 添加项目目录" 按钮选择项目根目录后，App 自动扫描该目录下：

- `<proj>/.claude/skills/`
- `<proj>/.codex/skills/`
- `<proj>/.cursor/rules/`
- `<proj>/.cursor/skills/`

并在 Sidebar 把项目展开为可见的子源（每个子源用与用户级相同的 List/Detail 展示）。

### 3.3 文件形态约定

- **目录式（Claude / Codex / Cursor Skills）**: 一条 skill = 一个目录，主文件 `SKILL.md`，可能包含 `references/`、`scripts/`、`assets/`、`agents/` 子目录（**MVP 不展示也不编辑这些子目录**——通过"在 Finder 中显示"按钮跳转）。
- **单文件式（Cursor Rules）**: 一条 rule = 一个 `*.mdc` 文件。

### 3.4 Frontmatter 字段（仅供浅解析显示用）

App **不强约束** frontmatter schema，只用浅解析提取以下字段填充列表：

- `name`（缺省 = 文件/目录名）
- `description`（缺省 = 空）
- 其余字段一律视为不透明（用户在 Raw 编辑器里完全自由）

---

## 4. 信息架构（IA）

经典 macOS 三栏布局：

```
┌────────────┬─────────────────┬──────────────────────────┐
│  Sidebar   │     List        │       Detail (Raw 编辑器) │
│  数据源 +   │  当前源条目      │  YAML+Markdown 高亮       │
│  项目      │                 │                          │
│            │                 │                          │
│  [+ 添加项目]│                │                          │
└────────────┴─────────────────┴──────────────────────────┘
```

- **Sidebar**（230px）: 用户级 4 个源 + 已添加项目（每个项目展开后显示其内部子源）
- **List**（320px）: 选中源的所有条目（name / 截断 description / 来源徽章 / 修改时间）
- **Detail**（剩余）: VS Code 风格深色编辑器（YAML+Markdown 双语法高亮 / 行号 / 光标行高亮）+ 顶部面包屑工具栏（显示路径、显示在 Finder、复制路径、删除、保存 ⌘S）+ 底部状态栏（编码 / 语言 / Ln,Col / 修改状态）

**主题**：跟随 macOS 系统设置（深 / 浅自动）。无应用内主题切换。

**全局工具栏**：刷新 / ＋新建 / 全局搜索 ⌘F / 显示 Finder / 设置。

---

## 5. 数据模型（Swift）

```swift
enum SourceKind: String, Codable, CaseIterable {
    case claudeSkills, codexSkills, cursorSkills, cursorRules
}

enum SourceScope: Equatable, Hashable {
    case user
    case project(Project)
}

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String       // 默认 = 目录名
    var path: URL
    var addedAt: Date
}

struct SkillItemID: Hashable, Codable {
    let kind: SourceKind
    let scopeKey: String          // "user" 或 "project:<UUID>"
    let pathFingerprint: String   // standardizedPath 的 SHA-1 前 12 位
}

struct SkillItem: Identifiable, Hashable {
    let id: SkillItemID
    let kind: SourceKind
    let scope: SourceScope
    let mainFileURL: URL          // SKILL.md 或 *.mdc 的绝对路径
    let containerURL: URL?        // 目录式才有
    var name: String
    var description: String
    var rawContent: String        // 整个文件原文（含 frontmatter 和 body）
    var fileModifiedAt: Date
    var sizeBytes: Int
    var hasSubdirectories: Bool
}
```

**关键设计**：

- `rawContent` 保存整个文件原文，**不做 frontmatter 反序列化**（MVP 是 Raw 编辑模式，避免任何字段层信息丢失）
- `SkillItemID` 基于路径指纹，刷新后选中状态可保持
- 用户偏好（项目列表、窗口尺寸、上次选中 ID）存到 `~/Library/Application Support/AISkillManager/preferences.json`
- 磁盘文件是唯一真相，不做 App 内的本地缓存数据库

---

## 6. 组件拆分（4 层）

```
View 层 (SwiftUI)
  AppRoot, SidebarView, ItemListView, DetailView,
  NewItemSheet, AddProjectSheet, DeleteConfirmAlert
        ↓ 观察
ViewModel 层 (@Observable)
  AppStore           // 单例，持有所有源、当前选中、搜索
  DetailEditorVM     // 编辑缓冲、脏标记、保存
        ↓ 调用
Repository 层 (协议化)
  SkillRepository (协议)
    ├─ DirectorySkillRepoBase (公共逻辑)
    │     ├─ ClaudeSkillsRepo
    │     ├─ CodexSkillsRepo
    │     └─ CursorSkillsRepo
    └─ CursorRulesRepo (单文件式)
  ProjectRegistry    // 项目增删 + 持久化
        ↓ 用
Infrastructure 层
  FileSystem, YAMLFrontmatter (浅解析), PreferencesStore
```

**核心约束**：

- 每层只依赖下层
- `SkillRepository` 协议化，新平台只需新增一个 Repo 实现
- `AppStore` 是唯一可观察源，避免 ViewModel 间互相同步

---

## 7. 关键交互流程

### 7.1 启动 → 显示首屏

1. 加载 `preferences.json` → 拿到项目列表
2. 并发触发所有 Repo `listAll()` 扫描
3. 收集结果 → 按 source 分组 → UI 显示
4. 初始选中：上次选中 ID（若文件还在）或第一个非空源

### 7.2 编辑 → 保存

1. 点列表行 → `DetailEditorVM` 加载 `rawContent` 到编辑缓冲
2. 用户改字 → 缓冲变 → `isDirty = true`
3. ⌘S 触发：
   - 写临时文件 `<mainFileURL>.tmp.<uuid>`（同目录）
   - `FileManager.replaceItemAt(...)` 原子替换
   - 刷新 `fileModifiedAt` / `sizeBytes`，`isDirty = false`
4. 失败 → Toast 提示，临时文件清理，缓冲保留

### 7.3 新建

1. Toolbar "＋ 新建" → 弹 Sheet
2. 选目标平台 + 范围（用户级 / 已添加项目）+ 名字
3. 名字校验：非空、不含 `/`、目录式校验目录不存在、单文件式校验文件不存在
4. Repo 创建：
   - 目录式：建 `<root>/<name>/SKILL.md`（带最小 frontmatter 模板）
   - 单文件式：写 `<root>/<name>.mdc`（带最小 frontmatter）
5. 自动选中新条目，光标定位到 description 末尾

### 7.4 删除

1. 选中条目 → 点删除 → 二次确认 alert
2. 移到 macOS 废纸篓（`FileManager.trashItem`），不立即删除
3. 从内存中移除，自动选中下一条

### 7.5 聚焦时刷新（外部改动同步 — 简化版）

1. 窗口激活（`NSApplication.didBecomeActiveNotification`）
2. 全部 Repo 重扫
3. Diff 处理：
   - 新增 → 加列表
   - 删除 → 移出列表（若是当前选中且 isDirty：仅在内存里保留缓冲，状态栏标"原文件已删除"）
   - 修改 → 比 `fileModifiedAt`：
     - 当前不在编辑该条 → 静默更新
     - **当前正在编辑该条**（`isDirty == true`）→ **保留内存内容不动**，⌘S 时直接覆盖磁盘
4. 不做冲突弹窗、不做 banner、不做 diff 视图（基于"单人单机、冲突极少"假设）

### 7.6 搜索 ⌘F

- 全局工具栏搜索框，输入即过滤
- 范围：当前所有源（用户级 + 已加项目）的 name + description + body 全文
- 实现：内存里 case-insensitive `contains`，规模千条以下完全够用

---

## 8. 错误处理与边界

| 场景 | 行为 |
|---|---|
| Frontmatter YAML 解析失败 | 仍展示该条，name 用文件名、description 显示"⚠️ 元数据解析失败"。Raw 编辑器照常工作。 |
| 单个文件 > 5 MB | List 行显示，Detail 拒绝加载并提示"文件过大，请用 IDE 打开" |
| 路径权限被拒 | 整个 Repo 显示空 + 警告条："无访问权限：<path>" |
| 项目目录被外部删除 | Sidebar 该项目灰显，子源不再扫；提示"目录已不存在 [移除项目]" |
| 文件是 symlink | 跟随读写（用户实际有这种用法，例 `find-skills` 是 symlink） |
| `.DS_Store` 等系统文件 | 扫描时按文件名前缀 `.` 过滤掉 |
| 保存时磁盘满 / 写权限拒绝 | 临时文件不留，Toast 提示具体原因，缓冲不丢 |
| 新建时名字已存在 | 校验阶段拦截，不允许提交 |
| App 内重命名 | **MVP 不支持**，要改名走 Finder 重命名后 App 聚焦自动重扫 |

---

## 9. 技术栈与分发

- **语言/框架**: Swift 5.9+ / SwiftUI / `@Observable`（iOS 17+ / macOS 14+ Sonoma 起）
- **YAML 解析**: [Yams](https://github.com/jpsim/Yams)（事实标准）
- **Markdown 渲染** *(MVP 不需要，Raw 编辑器无预览)*
- **代码编辑器**: 基于 `NSTextView` 自建（YAML + Markdown 简单高亮，规则用正则即可），未来需要可换为 `CodeEditor` SwiftUI 包装
- **自动更新**: [Sparkle](https://sparkle-project.org/)
- **公证**: Apple Developer ID（$99/年）+ Xcode 自动公证流程
- **最低 macOS 版本**: macOS 14 Sonoma（用 `@Observable` 必需）

**分发流程**：

1. Xcode Archive → Distribute App → Developer ID
2. Sparkle 生成 appcast.xml
3. GitHub Release 挂 DMG + appcast 链接
4. 不上 Mac App Store（避免 sandbox 改造工作量）

---

## 10. 测试策略

| 层 | 测试类型 | 工具 |
|---|---|---|
| Repository | 单元测试（在临时目录建模拟数据，验证扫描/读/写/删） | XCTest + 临时目录 fixture |
| YAMLFrontmatter | 单元测试（合法 / 异常 / 空 / 仅 body 等场景） | XCTest |
| AppStore | 集成测试（启动 → 加载 → 编辑 → 保存 → 聚焦刷新 完整流程） | XCTest |
| 关键 View | Snapshot 测试（Sidebar / List 行 / Detail toolbar） | swift-snapshot-testing |
| E2E | **MVP 不做**，手测覆盖 | — |

**关键 fixture**: 在 `Tests/Fixtures/` 下放一组标准 skill 样本（Claude / Codex / Cursor 各 2-3 条，含异常 frontmatter 1 条、空 description 1 条、子目录 1 条）。

---

## 11. 实施里程碑（粗粒度）

> 详细任务由 writing-plans skill 在下一阶段产出，此处只作整体节奏。

- **M1（基线）**: 项目初始化、4 层骨架、`SkillRepository` 协议、用户级 4 个源扫描 + 显示 List。**目标：能看，不能改。** ✅ **完成于 2026-04-28**，实施计划 `docs/superpowers/plans/2026-04-28-m1-baseline.md`，git tag `m1-baseline`，32 个单元测试 PASS。
- **M2（编辑闭环）**: Raw 编辑器、保存、聚焦刷新（简化版）、状态栏。**目标：能完整 read+edit+save。**
- **M3（CRUD 完整）**: 新建 / 删除 / 项目添加。**目标：能 CRUD。**
- **M4（打磨）**: 全局搜索、错误处理细节、空态/异常文案、键盘快捷键完善。**目标：日常可用。**
- **M5（分发）**: Sparkle 集成、CI 自动 sign + 公证、首个 GitHub Release。**目标：能给朋友发 DMG。**

---

## 12. 已确定取舍记录（避免后期反悔）

| 项 | 选项 | 决策 | 理由 |
|---|---|---|---|
| 操作集 | 只读 / 读改 / 全 CRUD | 全 CRUD（无启停） | 自己用，简单足够 |
| 编辑器 | Raw / Form / Form+Raw | Raw（最简） | 字段差异多、MVP 优先 |
| 子目录处理 | 不管 / 展示 / 全编辑 | 不管（MVP） | 通过 Finder 兜底 |
| 文件外部变化 | 手动 / 聚焦 / 实时监听 | 聚焦时刷新 | 平衡复杂度 |
| 冲突解决 | modal / banner / 静默 | 静默：编辑中保留内存、保存覆盖磁盘 | 单人单机、冲突极少 |
| 跨平台 | iOS / Win / Linux | 仅 Mac | 砍掉所有跨端复杂度 |
| 项目级扫描 | 不扫 / 自动 / 手动加 | 手动加 | 控制感 + 性能 |
| 技术栈 | SwiftUI / Tauri / Electron | SwiftUI 原生 | 体验最好、未来 iOS 零迁移成本 |
| 上架 MAS | 上 / 不上 | 不上 | 避免 sandbox 文件访问改造 |

---

## 附录 A — 第一版最小 frontmatter 模板

新建条目时写入主文件的初始内容：

**目录式（Claude / Codex / Cursor Skills）— `SKILL.md`**:

```markdown
---
name: <用户输入的 name>
description: <一句话描述何时调用此 skill>
---

# <用户输入的 name>

<在这里写 skill 内容>
```

**单文件式（Cursor Rules）— `<name>.mdc`**:

```markdown
---
alwaysApply: false
description: <一句话描述此 rule 何时生效>
---

# <用户输入的 name>

<在这里写 rule 内容>
```

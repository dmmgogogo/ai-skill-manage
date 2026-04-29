# Skill Analysis Feature Design

Date: 2026-04-29

## Overview

Add an AI-powered skill analysis feature to Triskill. Users can manually trigger analysis of any skill's content via ChatGPT, view the Chinese-language result in a right-side drawer, and have results persisted across sessions. A Settings Sheet in the sidebar bottom lets users configure their OpenAI API key and preferred model. A version number is also added to the sidebar bottom.

## Requirements

- Manual trigger: user clicks an "分析" button in the Detail toolbar
- Analysis result returned in Chinese
- Results cached in `~/Library/Application Support/Triskill/analysis-cache.json` (keyed by absolute file path)
- Cached results shown immediately; user can force-refresh via a "刷新" button
- Right-side drawer (≈300pt wide) displays analysis alongside the editor without obscuring it
- Settings Sheet: OpenAI API Key (SecureField) + model picker (gpt-4o / gpt-4o-mini / gpt-4-turbo)
- API key and model persisted in existing `Preferences` / `PreferencesStore`
- Version number displayed in sidebar bottom-left (read from `Bundle.main`)
- Gear icon + "设置" button in sidebar bottom-left opens Settings Sheet

## Architecture

### New Files

```
Infrastructure/
  AnalysisService.swift      # URLSession → OpenAI chat/completions, returns String
  AnalysisCacheStore.swift   # Read/write analysis-cache.json (key = file path)

ViewModels/
  AnalysisStore.swift        # @Observable: isAnalyzing, result, error, showDrawer

Views/
  AnalysisDrawer.swift       # Right-side drawer panel
  SettingsSheet.swift        # API key + model picker sheet
```

### Modified Files

```
Models/Preferences.swift         # Add: apiKey: String, model: String
Infrastructure/PreferencesStore  # No change needed (already generic)
Views/DetailView.swift           # Add AnalysisStore state + drawer + toolbar button
Views/SidebarView.swift          # Add bottom bar: gear button + version label
App/AppRoot.swift                # Pass AnalysisStore to DetailView if needed
```

## Data Flow

1. User clicks "分析" in Detail toolbar
2. `AnalysisStore.analyze(item:)` called
   - Check `AnalysisCacheStore` for cached entry at item's file path
   - Cache hit → set `result`, open drawer
   - Cache miss → call `AnalysisService.analyze(content:apiKey:model:)`
3. `AnalysisService` sends POST to `https://api.openai.com/v1/chat/completions`
   - System prompt: "请用中文分析这个 AI skill 文件，说明它的用途、触发时机和主要步骤，语言简洁。"
  - Model options: gpt-4.5 / gpt-4o (default) / gpt-4o-mini / gpt-4-turbo
   - User message: raw skill content
4. Response text written to `AnalysisCacheStore` with timestamp
5. `AnalysisStore.result` updated → drawer opens automatically

## UI Layout

### Detail View (with drawer open)

```
┌─────────────────────────────────────┬──────────────────┐
│ [path]          [分析] [Finder] [保存] │ AI 分析    [↺][×] │  ← toolbar
├─────────────────────────────────────┼──────────────────┤
│                                     │                  │
│  TextEditor (editing content)       │  ScrollView      │
│                                     │  (Chinese text)  │
│                                     │                  │
├─────────────────────────────────────┴──────────────────┤
│ UTF-8  YAML+Markdown  7,133 bytes             已保存   │  ← status bar
└─────────────────────────────────────────────────────────┘
```

### Sidebar Bottom Bar

```
┌──────────────────────────────┐
│ ⚙ 设置              v0.1.0  │
└──────────────────────────────┘
```

### Settings Sheet

- Title: 设置
- Row 1: "OpenAI API Key" — SecureField (masked)
- Row 2: "模型" — Picker（含新旧主流模型，默认 gpt-4o）：
  gpt-4.5 / gpt-4o / gpt-4o-mini / gpt-4-turbo
- Footer buttons: 取消 / 保存

## Storage

**`~/Library/Application Support/Triskill/analysis-cache.json`**

```json
{
  "/Users/mmx/.claude/skills/foo/SKILL.md": {
    "result": "这个 skill 用于...",
    "analyzedAt": "2026-04-29T10:00:00Z"
  }
}
```

**`preferences.json`** (extended)

```json
{
  "projects": [...],
  "apiKey": "sk-...",
  "model": "gpt-4o"
}
```

## Error Handling

- No API key configured → show inline warning in drawer: "请先在设置中填写 OpenAI API Key"
- Network error / non-200 response → show error message in drawer with retry button
- Empty skill content → disable "分析" button

## Out of Scope

- Streaming responses (use non-streaming for simplicity)
- Per-project API key overrides
- Analysis of non-skill files

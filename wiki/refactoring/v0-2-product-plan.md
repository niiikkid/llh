# v0.2 Product Plan

> Sources: Cursor planning discussion, 2026-05-27; llh implementation, 2026-05-27
> Raw: [v0.2 product plan](../../raw/refactoring/2026-05-27-v0-2-product-plan.md); [v0.2 increment 1 UI polish completion](../../raw/refactoring/2026-05-27-v0-2-increment-1-ui-polish-completion.md); [v0.2 increment 2 session navigation completion](../../raw/refactoring/2026-05-27-v0-2-increment-2-session-navigation-completion.md); [v0.2 increment 3 settings page completion](../../raw/refactoring/2026-05-27-v0-2-increment-3-settings-page-completion.md); [v0.2 increment 4 translation result state completion](../../raw/refactoring/2026-05-27-v0-2-increment-4-translation-result-state-completion.md); [v0.2 increment 10 single window completion](../../raw/refactoring/2026-05-27-v0-2-increment-10-single-window-completion.md)
> Updated: 2026-05-27

## Overview

`v0.2` is a product polish and learning-flow release for `llh`. The main goal is to make sessions easier to manage, make translation results clearer, and turn word translation plus grammar explanation into session-level modes that can run automatically after the main formatting/translation step.

**Shipped so far (2026-05-27):** UI polish (Inc. 1); session list page with create/open/delete/rename and `AppMainRoute` navigation (Inc. 2); settings page layout in main window (Inc. 3); unified translation result state without raw/formatted tabs (Inc. 4); single main window (Inc. 10). Remaining: study tabs, automation, overlay close, reading overview details, Dock badge.

## Release progress

| Increment | Topic | Status |
|-----------|--------|--------|
| 1 | Quick UI polish | **Done** (2026-05-27) |
| 2 | Session list page | **Done** (2026-05-27) |
| 3 | Settings page | **Done** (2026-05-27) |
| 4 | Translation result state | **Done** (2026-05-27) |
| 5 | Words and grammar tabs | Planned |
| 6 | Session-level automation | Planned |
| 7 | Overlay closing | Planned |
| 8 | Session reading overview details | Planned |
| 9 | Dock language badge | Planned |
| 10 | Single main window | **Done** (2026-05-27) |

## Product Decisions

- Keep the product term `сессии`; do not rename it to chats, profiles, collections, or sections.
- Automatic learning-material generation is configured per session, not globally.
- Session language is selected when the session is created and is not editable in `v0.2`.
- Word translation and grammar are shown in the main window. The compact overlay remains focused on the main translation and manual closing behavior.
- Dock language indication targets the macOS Dock icon, not only the menu bar.

## Increment 1: Quick UI Polish

**Status: done** (2026-05-27). UI-only; no persistence or workflow changes.

Goal: remove obvious friction without changing data flow.

Scope (all delivered):

- Remove the visible `Движок OCR` label from the toolbar and widen the OCR picker so selected values fit.
- Make `Скрыть сессии` and `Настройки` toolbar actions icon-only, with help text/tooltips preserving clarity.
- Remove dates from the left translation list inside the selected session.
- Show the session language with a language icon/flag plus localized language title.
- Translate remaining English UI strings to Russian, including menu bar actions such as `Capture`, `Open Window`, app panel title text, and default session labels where user-visible.

### Implemented

| Area | What shipped |
|------|----------------|
| Toolbar | `MainChromeView`: hidden OCR label, picker width 200, icon-only sidebar/settings with `.help` |
| Translation list | `HistoryView`: no dates in entry list; `SessionLanguageBadge` in list rows (later moved to `Presentation/Shared/`) |
| Localization | `AppDisplayStrings.productName` → «Помощник по изучению языков»; menu bar «Захват» / «Открыть окно» |
| Default session | `LearningProfile.displayName` maps stored `"Default"` → «По умолчанию» in UI only |
| Permissions banner | `CapturePermissionBannerView` fully Russian, including settings button |
| Domain helpers | `LearningLanguage.flagEmoji`; `HistoryViewModel.selectedProfileDisplayName` |

New file: `Presentation/Shared/AppDisplayStrings.swift`.

### Not in this increment

- Settings tab label **OpenAI** kept as product brand.

Risk:

- Low. Kept as a focused UI-only change.

## Increment 2: Main Window And Session Navigation

**Status: done** (2026-05-27).

Goal: replace the cramped session picker flow with a real session management page.

Scope (all delivered):

- Main-window page for all sessions with create, open, delete, rename.
- Language immutable after creation (picker only on create sheet).
- Workspace keeps translation list for the opened session (`HistoryView` sidebar).
- `AppMainRoute` navigation: `sessions`, `workspace`, `settings` in `ContentView` (settings no longer a sheet).
- Rename/delete via `ManageProfilesUseCase`; persist through existing save path.

### Implemented

| Area | What shipped |
|------|----------------|
| Routes | `AppMainRoute`; `MainChromeView` toolbar: all sessions, back, settings with return route |
| Sessions page | `SessionsListView` — list, create/rename sheets, delete alert |
| Workspace sidebar | `HistoryView` — translations only; group box «Переводы» |
| Domain | `renameProfile`, `deleteProfile(profileID:)`, `canDeleteProfile(profileID:)` |
| Shared UI | `SessionLanguageBadge` extracted to `Presentation/Shared/` |

New files: `SessionsListView.swift`, `AppMainRoute.swift`, `SessionLanguageBadge.swift`.

### Overlap with Increment 3

Increment 2 introduced in-window settings route; Increment 3 completed layout and removed sheet-era chrome.

## Increment 3: Settings As A Page

**Status: done** (2026-05-27).

Goal: make settings feel native and spacious.

Scope (all delivered):

- Re-layout settings groups so controls align and the page uses available width.
- Keep tabs such as `Общие` and `OpenAI`.
- Keep existing settings ownership in `SettingsViewModel`; UI should remain thin.
- Remove modal sheet remnants (fixed size, «Закрыть»); navigation via `MainChromeView` «Назад».

### Implemented

| Area | What shipped |
|------|----------------|
| Layout | Full-route `TabView`; `GroupBox` + `PanelGroupBoxStyle` sections |
| Alignment | `SettingsLabeledControlRow`, `SettingsShortcutRow`, `SettingsDurationSliderRow` |
| OpenAI | Groups «Подключение» / «Модель»; `statusMessage` under actions |
| Routing | From Inc. 2: `AppMainRoute.settings`, back restores prior route |

### Shipped with Increment 2

- `SettingsView` embedded in main window via route navigation (no sheet).

Risk:

- Low. UI-only in `SettingsView` (+ UI test for back navigation).

## Increment 4: Translation Result State

**Status: done** (2026-05-27).

Goal: remove raw/formatted tabs and make loading/error state understandable.

Scope (all delivered):

- Remove `Сырой текст` and `Форматированный` tabs.
- While formatting is running, show the raw OCR text with a loading indicator.
- After successful formatting, show the formatted translation using the existing formatted style.
- If formatting fails, show a clear Russian error and keep the raw text visible.
- Remove the always-visible refresh action.
- Show an icon-only retry action only when the current content failed to load.

### Implemented

| Area | What shipped |
|------|----------------|
| Presentation state | `TranslationResultPresentation` + `TranslationResultPresentationResolver` from `FormattingStatus` |
| Editor UI | `TranslationEditorView`: loading banner + raw text; failure banner + raw; formatted scroll + study |
| Retry | Icon-only `arrow.clockwise` in footer when `.failed`; removed centered retry in `FormattedTranslationContentView` |
| Cleanup | Removed `TranslationTextTab` and `selectedTextTab` bindings from `ContentView` / workspace shell |

New files: `TranslationResultPresentation.swift`, `llhTests/TranslationResultPresentationResolverTests.swift`.

Implementation notes (as built):

- Resolver is pure; `EditorViewModel.translationResultPresentation` delegates to it.
- `formattingFailureMessage` prefers `statusMessage` when it starts with «Не удалось отформатировать».

Risk:

- Low. Presentation-only; formatting pipeline unchanged.

## Increment 5: Words And Grammar Tabs

Goal: make learning materials first-class in the main window.

Scope:

- Replace the current word-study presentation with two tabs: `Перевод слов` and `Грамматика`.
- Keep `Перевод слов` based on `WordStudyPayload`.
- Reintroduce grammar as a real product feature with a separate request, status, retry action, and UI.
- Grammar should be short, compact, and useful for a Russian-speaking learner: explain how sentence parts connect and why they create this meaning.
- Loading and retry behavior should apply to the active learning tab.

Implementation notes:

- `StudyMaterials` already has `grammar` and `grammarStatus`; reuse or adapt it instead of adding parallel storage.
- Add a dedicated grammar request/use case/service path, not a bundled words+grammar request.
- Keep prompts centralized in `OpenAIPromptBuilder` and covered by focused tests.

## Increment 6: Session-Level Automation

Goal: let a session automatically continue into learning materials after the main translation.

Scope:

- Add per-session settings for:
  - automatically load word translations;
  - automatically load grammar.
- After formatting succeeds, start enabled follow-up jobs.
- Word translation and grammar must be separate requests.
- Do not start follow-up requests when formatting fails.
- Preserve explicit manual retry for failed words or grammar.

Implementation notes:

- Store these flags on `LearningProfile` so they travel with the session.
- Add Codable defaults for existing persisted sessions.
- Trigger automation from the ViewModel/use-case coordination point after `applyFormattingSuccess`, but avoid expanding `MainViewModel`.

## Increment 7: Compact Overlay Closing

Goal: make the compact translation overlay dismissible and predictable.

Scope:

- Add a visible close button in the top-right of the overlay.
- Support Escape to close the visible overlay.
- Stop ignoring mouse events when the overlay contains interactive controls.
- Preserve manual close behavior for the persistent last-translation overlay.
- If future overlay content waits for additional data, disable auto-hide until the user closes it.

Implementation notes:

- This is AppKit-sensitive because the current overlay panel is borderless, nonactivating, and ignores mouse events.
- Keep lifecycle in `TranslationOverlayService` / coordinator rather than SwiftUI views.

## Increment 8: Session Reading Overview Details

Goal: make `Весь текст сессии` useful for review, not only plain reading.

Scope:

- Add a small details/eye button per entry in the session reading overview.
- Expanding an entry shows available details below it.
- Include word translations when available.
- Keep the overview readable; collapsed state should remain compact.

Implementation notes:

- Extend `SessionReadingSequenceItem` or provide a richer view model item with entry ID and available study materials.
- Avoid loading missing words implicitly from the overview unless the session automation setting says so.

## Increment 9: Dock Language Badge

Goal: show the active session language on the app icon in Dock.

Scope:

- For `Автоопределение`, show a neutral/empty badge.
- For concrete languages, show a short badge or flag for the selected session language.
- Update badge when selected session changes.
- Clear/update badge on startup based on restored selected session.

Implementation notes:

- The simplest native path is `NSApp.dockTile.badgeLabel`.
- A full custom flag overlay on the icon is a separate AppKit task and should only be done if the badge label is not visually acceptable.

## Increment 10: Single Main Window Behavior

**Status: done** (2026-05-27).

Goal: fix menu bar `Open Window` so it activates the existing main window instead of creating duplicates.

Scope (all delivered):

- Replace blind `openWindow(id: "main-window")` behavior with single-window activation.
- If the main window exists, bring it forward (including deminiaturize when minimized).
- If it does not exist, create it once via `openWindow`.
- Keep `NSApp.activate(ignoringOtherApps: true)`.

### Implemented

| Area | What shipped |
|------|----------------|
| Activation | `MainWindowActivator.activateExisting()` — finds window by `accessibilityIdentifier` |
| Window tag | `MainWindowIdentityView` on `ContentView` sets `llh.main-window` on host `NSWindow` |
| Menu bar | `MenuBarPanelView` calls `openWindow` only when no existing main window |

New file: `App/MainWindowActivator.swift`.

## Suggested Order

1. ~~Quick UI polish and Russian localization.~~ **Done.**
2. ~~Single main window bug fix.~~ **Done.**
3. ~~Session list page and rename.~~ **Done.**
4. ~~Settings page layout and routing polish.~~ **Done.**
5. ~~Translation result state cleanup.~~ **Done.**
6. Words/grammar tabs and grammar OpenAI path. **Next recommended.**
7. Session-level automation flags.
8. Overlay close/Escape behavior.
9. Session reading overview details.
10. Dock language badge.

## Testing Focus

- Settings route: `testSettingsRouteOpensAndReturns` (toolbar «Настройки» → «Общие» → «Назад»); launch chrome uses Russian product name.
- **Inc. 4 (done):** `TranslationResultPresentationResolverTests` — loading / formatted / failed / rawOnly from `FormattingStatus`.
- Session rename persists and does not change language.
- Existing sessions decode with default automation flags.
- Formatting failure shows raw text and icon-only retry (manual UI verification).
- Successful formatting triggers enabled words/grammar requests exactly once.
- Words and grammar failures are independently retryable.
- `Open Window` does not create duplicate windows.
- Dock badge updates when selected session changes.
- Prompt construction for grammar stays short and Russian-learner-oriented.

## See Also

- [Refactoring Phase 3 Use Cases](refactoring-phase-3-use-cases.md) — `ManageProfilesUseCase` rename/delete by ID
- [Refactoring Phase 4 Presentation](refactoring-phase-4-presentation.md)
- [Refactoring Phase 6 OpenAI Integration](refactoring-phase-6-openai-integration.md)
- [Refactoring Phase 8 UI Decomposition](refactoring-phase-8-ui-decomposition.md)
- [Refactoring Phase 9 Testing Strategy](refactoring-phase-9-testing-strategy.md) — UI smoke (inc. 1–3); resolver tests (inc. 4)
- [Refactoring Phase 10 Cleanup](refactoring-phase-10-cleanup.md)

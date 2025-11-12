# Changelog

All notable changes to WindowSmartMover will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Debug log viewer with clear and copy functionality (in-memory only, no file storage)
- Window restore timing configuration (0.1-10.0 seconds, default 1.5s)
- `debugPrint()` function for centralized logging
- `DebugLogger` class for managing log entries (max 1000 entries)
- `WindowTimingSettings` class for managing restore delay configuration

### Changed
- Unified settings dialog and renamed menu item from "Shortcut Settings..." to "Settings..."
- Settings window now includes both hotkey and timing configurations
- Settings window size increased from 400x400 to 500x600
- "Cancel" button changed to "Reset to Defaults" with full functionality

### Fixed
- Window position calculation bug - restored relative positioning logic instead of center alignment
- Removed all compiler warnings:
  - Deleted unused `found` variable
  - Changed `nextScreenIndex` from `var` to `let`
  - Changed `gMyHotKeyID1` from `var` to `let`
  - Changed `gMyHotKeyID2` from `var` to `let`

### Security
- Debug logs are stored in memory only and cleared on app termination
- No sensitive information is written to disk

### Planned
- Multi-language support (internationalization)
  - Phase 1: English as default UI and debug logs (in progress)
  - Phase 2: Japanese localization
  - Phase 3: Community-contributed languages

## [Planned Features]

### Internationalization (i18n)
Multi-language support to make the app accessible to international users.

**Scope:**
- **User-facing UI and messages** - Menu items, dialogs, buttons, settings, and all user-visible text
- **Debug logs** - Translate to English for global accessibility

**Current state:**
- All UI text is in Japanese
- Debug logs are currently in Japanese, which prevents non-Japanese speakers from independently troubleshooting issues

**Implementation approach:**

**Phase 1: English default (Priority)**
1. Translate all UI strings to English
   - Menu items
   - Settings dialog
   - Debug log viewer
   - About window
   - Alert messages
2. Translate all debug logs to English
   - This enables international users to troubleshoot issues independently
   - Facilitates collaboration on bug reports
   - Enables effective Stack Overflow/GitHub issue searches
3. Translate code comments to English
   - Improves code readability for international contributors
   - Facilitates open-source collaboration
   - Makes the codebase more maintainable globally
4. Implement NSLocalizedString framework for all user-facing text
   - Prepares infrastructure for future localizations

**Phase 2: Japanese localization**
1. Create Japanese .strings files
2. Add language auto-detection based on system preferences
3. Test both English and Japanese interfaces thoroughly

**Phase 3: Additional languages (Future)**
- Community contributions welcome
- Consider: Chinese, Korean, Spanish, French, German

**Rationale:**
- English debug logs are essential for international troubleshooting
- English as the default UI maximizes the global user base
- Phased approach enables stable implementation without major refactoring
- Separating UI localization from debug logging optimizes both developer and user experience

## [1.1.0] - 2025-10-18

### Added
- Initial release
- Multi-display window management with keyboard shortcuts
- Customizable hotkey modifiers (Control, Option, Shift, Command)
- Window position memory across display configurations
- Automatic window restoration when external displays reconnect
- Menu bar integration with system tray icon

### Technical Details
- Built as macOS menu bar application
- Used Accessibility API for window manipulation
- Implemented in Swift 5.x with SwiftUI for settings interface
- Utilized Carbon API for global hotkey registration

# Changelog

[Chinese version](CHANGELOG.zh-CN.md)

All notable GreenRAM release changes are recorded here.

## v0.1.8 - 2026-06-08

- Updated cleanup policy: Auto-Quit Apps only wait for their non-frontmost time; ordinary non-whitelisted apps also require RAM or Swap limits to be exceeded; whitelisted apps are never quit.
- Updated Settings and README wording to match the new cleanup policy.
- Removed the obsolete MVP notes document.

## v0.1.7 - 2026-06-08

- Set the minimum configurable background time to 3 minutes.
- Changed timeout cleanup to use an explicit Auto-Quit Apps list.
- Made the Auto-Quit Apps list and whitelist mutually exclusive.
- Renamed memory threshold UI language to status-limit language.
- Clarified that automatic cleanup does not wait for RAM or Swap limits to be exceeded.
- Clarified Auto-Quit Apps wording in Settings and README: listed apps exit once their non-frontmost time limit is met.

## v0.1.6 - 2026-06-08

- Shipped Universal 2 release packages for Apple Silicon (`arm64`) and Intel (`x86_64`) Macs.
- Added app-specific background-time overrides in Settings.
- Added policy and settings-store support for per-Bundle ID background-time thresholds.
- Updated reset behavior to remove app-specific background-time overrides.
- Added README compatibility notes and this changelog.

## v0.1.5 - 2026-06-08

- Added app-bundle picking for whitelist entries in Settings.
- Improved whitelist rows with app names, icons, and Bundle ID details.
- Cached selected app paths for whitelist display and removed cached paths when entries are removed.

## v0.1.4 - 2026-06-08

- Added whitelist management directly in Settings.
- Made default system whitelist entries editable instead of permanently protected.
- Changed duplicate quit cooldown tracking from PID to Bundle ID.

## v0.1.3 - 2026-06-08

- Changed cleanup policy to use non-frontmost duration instead of memory size as the app-level cleanup condition.
- Added a configurable background-time threshold with a 30-minute default.
- Removed app type, Bundle ID keyword, app-name keyword, and risk-classifier checks from cleanup decisions.
- Kept RAM and Swap as status/threshold display signals instead of app-level cleanup gates.

## v0.1.2 - 2026-06-08

- Updated menu wording to distinguish cleanable and non-cleanable apps.
- Added the Settings screenshot to project docs.
- Refined localization text around cleanup candidates.

## v0.1.1 - 2026-06-08

- Bumped the app version to 0.1.1.

## v0.1.0 - 2026-06-05

- First tagged GreenRAM release.
- Added menu bar memory status, Settings, whitelist support, event logging, and localized UI.
- Added multi-process memory accounting for app process trees.

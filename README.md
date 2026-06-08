# GreenRAM

[中文说明](README.zh-CN.md) | [Changelog](CHANGELOG.md)

GreenRAM is a macOS menu bar app that watches memory usage and force quits idle background apps after a configurable non-frontmost duration.

It is built for a simple case: keep the frontmost app responsive by removing apps that have stayed in the background too long.

## Screenshots

### Menu

![GreenRAM menu](docs/screenshots/menu.png)

### Settings

![GreenRAM settings window](docs/screenshots/settings.png)

## Features

- Menu bar memory status with a green/red leaf icon.
- RAM and Swap status with configurable display thresholds.
- Automatic app termination for Auto-Quit Apps after the configured background time.
- Memory-limit-based cleanup for ordinary non-whitelisted apps after the default background time.
- Manual "Clean Apps Now" action.
- Editable whitelist support for apps that should not be quit.
- Multi-process memory accounting for browsers, Electron apps, Xcode helpers, and similar app trees.
- Localized UI for Simplified Chinese, Traditional Chinese, English, Japanese, German, and French.

## Supported macOS Versions and Architectures

- macOS 13.0 Ventura or later, including macOS 14 Sonoma and macOS 15 Sequoia.
- Release packages are Universal 2 and support both Apple Silicon (`arm64`) and Intel (`x86_64`) Macs.
- Local SwiftPM builds use the current Mac architecture unless you explicitly build a Universal 2 binary.

## Current Cleanup Policy

GreenRAM first applies these base checks:

- It is a regular macOS GUI app with a Bundle ID.
- It is not GreenRAM itself.
- It is not the current macOS frontmost app.
- It is not in the whitelist. Finder, Dock, WindowServer, System Settings, and System Preferences are included by default, but every whitelist item can be removed in Settings.

After that, cleanability depends on the app's list status:

- Auto-Quit Apps exit as soon as their configured non-frontmost time limit is met. RAM and Swap status do not delay the action.
- Ordinary apps outside the Auto-Quit Apps list exit only when RAM or Swap status limits are exceeded and their non-frontmost time reaches the default background-time threshold.

The default background time is 30 minutes. It can be changed in Settings, with a minimum of 3 minutes. Auto-Quit Apps can also have per-app background-time rules.

The Auto-Quit Apps list and whitelist are mutually exclusive. Adding an app to one list removes it from the other.

App type, Bundle ID keywords, app-name keywords, and per-app memory usage do not decide whether an app is cleanable. RAM and Swap status only gate ordinary apps outside the Auto-Quit Apps list.

When multiple apps are cleanable, GreenRAM handles the apps that have stayed in the background longest first. Per-app memory is only used as a tie-breaker and for display.

Each automatic sweep force quits at most 3 cleanable apps by default. Automatic sweeps have a 60-second cooldown, and the same Bundle ID is not requested again for 10 minutes. Manual "Clean Apps Now" uses the same cleanable-app criteria.

## Never Quit Rules

GreenRAM never quits:

- the frontmost app
- whitelisted apps
- background apps that have not reached the configured background-time threshold
- ordinary apps outside the Auto-Quit Apps list while RAM and Swap status are below their configured limits

## Download

Download the latest signed and notarized DMG from the [Releases](../../releases) page.

## Build

```sh
swift build -c release
```

Run locally:

```sh
swift run GreenRAM
```

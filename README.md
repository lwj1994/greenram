# GreenRAM

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
- Automatic cleanable app termination after the configured background time.
- Manual "Clean Apps Now" action.
- Editable whitelist support for apps that should not be quit.
- Multi-process memory accounting for browsers, Electron apps, Xcode helpers, and similar app trees.
- Localized UI for Simplified Chinese, Traditional Chinese, English, Japanese, German, and French.

## Current Cleanup Policy

An app is considered cleanable only when all of these conditions are true:

- It is a regular macOS GUI app with a Bundle ID.
- It is not GreenRAM itself.
- It is not the current macOS frontmost app.
- It is not in the whitelist. Finder, Dock, WindowServer, System Settings, and System Preferences are included by default, but every whitelist item can be removed in Settings.
- Its non-frontmost time is at least the configured background-time threshold.

The default background-time threshold is 30 minutes. It can be changed in Settings.

App type, Bundle ID keywords, app-name keywords, and memory usage do not decide whether an app is cleanable.

When multiple apps are cleanable, GreenRAM handles the apps that have stayed in the background longest first. Memory is only used as a tie-breaker and for display.

Each automatic sweep force quits at most 3 cleanable apps by default. Automatic sweeps have a 60-second cooldown, and the same Bundle ID is not requested again for 10 minutes. Manual "Clean Apps Now" uses the same cleanable-app criteria.

## Never Quit Rules

GreenRAM never quits:

- the frontmost app
- whitelisted apps
- background apps that have not reached the configured background-time threshold

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

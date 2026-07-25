# sonos-menu

A lightweight macOS menu-bar app that controls Sonos speakers directly, without requiring the Sonos desktop app.

Built with SwiftUI as a `MenuBarExtra`. Uses manual SSDP discovery, UPnP/SOAP, and Sonos zone-group topology to manage households, groups, and rooms.

## Features

- Discover Sonos devices on the local network via SSDP
- View and select households and groups
- Now Playing with album art
- Playback controls (play/pause, previous, next)
- Per-room volume and mute
- Manual refresh / scan

## Architecture

- `Models/` — Domain model: `Household`, `Group`, `Room`, `Device`, `Playback`
- `Services/` — `SSDPDiscoveryService`, `SonosController`, `SonosRepository`, `HouseholdMapper`
- `ViewModels/` — `SonosMenuViewModel`
- `Views/` — SwiftUI views for the menu window

## Requirements

- macOS 26.5+
- Xcode 17+
- Swift 5

## Build

```bash
xcodebuild -project sonos-menu.xcodeproj -scheme sonos-menu -destination 'platform=macOS,arch=arm64' build
```

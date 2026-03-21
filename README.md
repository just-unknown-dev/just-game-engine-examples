# Just Game Engine Examples

Example application for the Just Game Engine monorepo.

This Flutter app showcases engine subsystems through focused demo screens (desktop split-view + mobile push navigation), while the local package dependency points to `packages/just_game_engine` for active engine development.

## Overview

The app boots a singleton `Engine`, then exposes feature demos from `lib/features/features_list.dart`:

- Core Engine (ECS architecture)
- Rendering Engine
- Sprite System
- Animation System
- Particle System
- Physics Engine
- Raycasting Engine
- Input System
- Audio Engine
- Parallax System
- Tiled Map
- Storage and Signals
- Database and Signals

## Quick Start

### Prerequisites

- Flutter SDK 3.11.0+
- Dart SDK 3.11.0+

### Run

```bash
flutter pub get
flutter run
```

### Analyze and Test

```bash
flutter analyze
flutter test
```

## Project Layout

```text
just_game_engine_workspace/
|-- lib/
|   |-- main.dart
|   |-- core/
|   |   |-- di/
|   |   |-- models/
|   |   |-- screens/
|   |   `-- widgets/
|   `-- features/
|       |-- features_list.dart
|       |-- animation/
|       |-- audio/
|       |-- core_engine/
|       |-- database/
|       |-- input/
|       |-- parallax/
|       |-- particle/
|       |-- physics/
|       |-- raycasting/
|       |-- rendering/
|       |-- sprite/
|       |-- storage/
|       `-- tiled/
|-- assets/
|   |-- audio/
|   |-- data/
|   |-- images/
|   |-- maps/
|   `-- sprites/
`-- packages/
    |-- just_game_engine/
    |-- just_audio/
    |-- just_signals/
    |-- just_tiled/
    `-- just_zstd/
```

## App Architecture Notes

- Entry point: `lib/main.dart`
- Home/navigation shell: `lib/core/screens/home_screen.dart`
- Feature registry: `lib/features/features_list.dart`
- DI setup: `lib/core/di/app_config.dart`

The app is responsive:

- Desktop/tablet: feature list + live showcase side-by-side
- Mobile: feature list pushes each demo to its own route

## Engine Package

The demo depends on the local package path:

```yaml
just_game_engine:
  path: packages/just_game_engine
```

For engine-specific docs and API details, see:

- `packages/just_game_engine/README.md`
- `packages/just_game_engine/API.md`
- `packages/just_game_engine/QUICKSTART.md`

## Supported Platforms

- Windows
- Web
- Android
- iOS
- macOS
- Linux

## Repository

- Examples repo: https://github.com/just-unknown-dev/just-game-engine-examples

## License

BSD-3-Clause

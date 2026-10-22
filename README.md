# Just Game Engine Examples

Example application for the Just Game Engine monorepo.

This Flutter app showcases engine subsystems through focused demo screens (desktop split-view + mobile push navigation), while `pubspec_overrides.yaml` points the engine packages at the local checkouts under `packages/` for active engine development.

It targets **just_game_engine 2.0.0-dev.2**.

## Overview

The app boots one shared 2-D `Engine` (`lib/core/engine/demo_engine.dart`) and exposes feature demos from `lib/features/features_list.dart`:

- Game Editor Overlay (debug, desktop)
- Core Engine & Rendering (lifecycle, ECS, tags, game loop; layers, shapes, hierarchy, particles, culling)
- Camera System (virtual cameras, framing, confiners, dolly, impulses)
- Sprite System and Animation System (atlases, animator graphs)
- Particle System
- Physics Engine (rigid bodies, colliders, joints, `CharacterBody2D`)
- Raycasting Engine (2-D physics queries)
- Input System (input actions, devices, on-screen controls, rebinding)
- Audio Engine (mixer, 3-D positional sound)
- Parallax System
- Post-Processing and Custom Shaders
- Tiled Map (level maps)
- 2-D Lighting & Shadows *(new in 2.x)*
- 2-D Materials & Screen Materials *(new in 2.x)*
- Timelines *(new in 2.x)*
- Scenes & Prefabs *(new in 2.x)*
- 3-D Graphics *(new in 2.x: Flutter GPU)*
- 3-D Physics *(new in 2.x: Jolt)*
- Deterministic Effects
- Storage & Signals, Database & Signals
- Narrative & Dialogue (Yarn Spinner)

## Quick Start

### Prerequisites

- Flutter SDK 3.47.1+ (the 3-D demos need Flutter GPU builds)
- Dart SDK 3.11.0+
- For the 3-D physics demo on desktop/mobile: a C/C++ toolchain, since `just_jolt` builds Jolt Physics from source (`hooks: user_defines: just_jolt: build: true` in `pubspec.yaml`)

### Run

```bash
flutter pub get
flutter run
```

Flutter GPU is switched on in each platform runner (`windows/runner/main.cpp`, `linux/runner/my_application.cc`, the Android manifest, the iOS and macOS `Info.plist`). Where 3-D cannot draw (the web, Android without Vulkan) the 3-D demos say why; the rest of the app runs everywhere.

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
|   |   |-- engine/        # shared 2-D engine, 3-D engine factory
|   |   |-- models/
|   |   |-- screens/
|   |   `-- widgets/
|   `-- features/
|       |-- features_list.dart
|       `-- <one folder per demo>/
|-- assets/
|   |-- audio/  data/  images/  maps/  sprites/  shaders/
|   |-- input/  materials/  timelines/  scenes/  prefabs/  models/
|-- docs/
|   `-- ENGINE_2_MIGRATION_BRIEF.md   # conventions for demo screens on 2.x
`-- packages/                          # local package checkouts
```

## App Architecture Notes

- Entry point: `lib/main.dart`
- Shared engine: `lib/core/engine/demo_engine.dart` (`demoEngine`, `DemoEngine.reset`, `Demo3DEngine.create`)
- Home/navigation shell: `lib/core/screens/home_screen.dart`
- Feature registry: `lib/features/features_list.dart`
- DI setup: `lib/core/di/app_config.dart`

In 2.x `Engine()` makes a new engine on every call, so demos never call it: they share the engine made in `main()`, which runs for the whole app and is driven by each `GameWidget`. A demo calls `DemoEngine.reset(engine, include: {...})` to get a clean world with the standard systems it needs. 3-D demos own an engine of their own and dispose it when they close.

The app is responsive:

- Desktop/tablet: feature list + live showcase side-by-side
- Mobile: feature list pushes each demo to its own route

## Engine Package

The demo depends on `just_game_engine: ^2.0.0-dev.2`; `pubspec_overrides.yaml` (not committed) points it and its sibling packages at `packages/`.

For engine-specific docs and API details, see:

- `packages/just_game_engine/README.md`
- `packages/just_game_engine/MIGRATION.md` (1.6 → 2.0)
- `packages/just_game_engine/API.md`
- `packages/just_game_engine/QUICKSTART.md`

## Supported Platforms

- Windows
- Web (no 3-D)
- Android
- iOS
- macOS
- Linux

## Repository

- Examples repo: https://github.com/just-unknown-dev/just-game-engine-examples

## License

BSD-3-Clause

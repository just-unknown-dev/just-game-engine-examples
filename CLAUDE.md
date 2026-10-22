# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run the demo app
flutter test             # Run tests
flutter analyze          # Static analysis
```

Requires Flutter 3.47.1+ (Flutter GPU builds for 3-D) and Dart 3.11.0+. The engine runs on
`just_game_engine` 2.x; local package checkouts are wired in through `pubspec_overrides.yaml`.

## Architecture

This is an interactive showcase/demo app for the **Just Game Engine** — a Flutter-based 2D ECS game engine. The app demonstrates each engine subsystem through interactive feature screens.

### Entry Point & Initialization

In `just_game_engine` 2.x, `Engine()` makes a **new** engine on every call. `lib/main.dart` builds the
app's one shared 2-D engine with `DemoEngine.boot()` (`lib/core/engine/demo_engine.dart`: initialize +
`start()`), registers it in DI (`setupDependencies(engine)`), then launches `JustEngineDemo`. Screens
reach it with `demoEngine` — never `Engine()`.

The engine is running for the whole app: every `GameWidget` showing it drives the game loop
(fixed-step `world.update`, the per-frame `world.frame`, input, audio), so screens never call
`world.update` themselves. `DemoEngine.reset(engine, include: {DefaultSystem.rendering, ...})` gives a
demo a clean world (entities, demo systems, stray bodies, camera, gravity, time scale) and adds the
engine's standard systems it asks for; screens call it when switching demos and in `dispose()`.

3-D screens own an engine of their own from `Demo3DEngine.create()` (Graphics3D, Physics3D on Jolt
where supported, silent audio) and dispose it when they go — 3-D must not share the 2-D engine.
`docs/ENGINE_2_MIGRATION_BRIEF.md` lists the conventions and the 1.6 → 2.x API changes.

### Navigation Shell

`lib/core/screens/home_screen.dart` drives responsive layout via an 800px breakpoint:
- **Desktop (≥800px)**: split-view with 300px feature-list sidebar + showcase panel
- **Mobile (<800px)**: full-screen feature list with push navigation

The `AppConfig.isMobile` flag is set on each build cycle and injected via `just_di`.

### Feature Registration

All feature demos are registered in `lib/features/features_list.dart` as a `List<FeatureItem>`. Adding a new feature means appending a `FeatureItem(title, icon, description, builder)` entry there — the home screen discovers it automatically.

Each feature screen is a `StatefulWidget` under `lib/features/<name>/`. The pattern is:
`DemoEngine.reset(...)` and create ECS entities in `initState`, demonstrate the subsystem,
`DemoEngine.reset(engine)` in `dispose`.

### Dependency Injection

`lib/core/di/app_config.dart` uses `just_di` (local package). The `getIt<T>()` helper wraps `JustDi.get<T>()`. New services are registered in `setupDependencies(engine)` with `JustDi.registerLazySingleton<T>()`; the shared `Engine` is registered there as a singleton.

### Local Packages

The monorepo hosts engine packages under `packages/`:

| Package | Purpose |
|---|---|
| `just_game_engine` | Core ECS engine (2.0.0-dev.2): 2-D, with opt-in 3-D graphics and physics |
| `just_game_engine_editor` | In-game level editor (debug, desktop) |
| `just_physics_engine` | 2-D physics (Box2D / pure Dart) and 3-D physics (Jolt) |
| `just_audio_engine` | Multi-channel audio mixer |
| `just_debugger` | Live ECS inspector overlay |
| `just_di` | Lightweight dependency injection |
| `just_signals` | Reactive signals system |
| `just_tiled` | Tiled TMX/TSX map support |
| `just_zstd` | Compression utilities |
| `just_memory` | Memory management helpers |

Each package has its own `README.md` and `pubspec.yaml`. The demo app references them via path dependencies.

### Engine Subsystems

Subsystems hang off the engine (`engine.rendering`, `engine.physics`, `engine.input`, `engine.audio`,
`engine.cameraSystem`, ...; `engine.subsystem<T>()` — `getSystem` is deprecated). They include:
rendering (layers, 2-D materials, screen materials, 2-D lighting and shadows), physics (`RigidBody2D` /
`Collider2D` / `CharacterBody2D`, queries, joints), sprite atlases and animator graphs, timelines,
virtual cameras, input actions (`just_inputs`), audio (incl. 3-D sound), particles, level maps (Tiled),
JSON scenes and prefabs, post-processing, parallax, deterministic effects, narrative (Yarn Spinner),
storage and database — plus 3-D graphics (`package:just_game_engine/graphics_3d.dart`) and 3-D physics
(`package:just_game_engine/physics_3d.dart`).

### Assets

```
assets/
├── audio/          # Sound files
├── images/         # UI images
├── sprites/        # characters/ and environment/
├── maps/           # Tiled TMX files
├── input/          # input action assets (.input.json)
├── materials/      # 2-D (.material2d.json) and 3-D (.material.json) materials
├── timelines/      # timeline assets
├── scenes/         # JSON scenes and scenes.json
├── prefabs/        # prefab files
├── models/         # glTF models for the 3-D demos
└── shaders/        # GLSL fragment programs
```

New asset directories must be declared in `pubspec.yaml` under `flutter.assets`.

### Theme

Dark theme: primary `#F5746F`, background `#07070F`. Defined in `lib/main.dart`.

# Demo app on just_game_engine 2.x — conventions for every screen

This app (`just_game_engine_examples`) is a showcase of the Just Game Engine.
It was written for engine 1.6 and now runs on **just_game_engine 2.0.0-dev.2**,
a breaking release. These are the rules every demo screen follows.

## Where to look things up

| What | Path |
|---|---|
| Upgrade guide, every removed/renamed API with before/after code | `packages/just_game_engine/MIGRATION.md` |
| What is new in 2.0.0-dev.1 and dev.2 | `packages/just_game_engine/CHANGELOG.md` |
| Engine source (the truth for every signature) | `packages/just_game_engine/lib/src/` |
| Engine tests (working usage of nearly every API) | `packages/just_game_engine/test/` |
| Engine docs | `packages/just_game_engine/{README,QUICKSTART,API,ARCHITECTURE}.md` |
| 2D reference game on 2.x | `D:/Development/GameDevelopment/GameEngine/JustGameEngineTemplates/just_platformer_template` (`lib/`, `assets/`) |
| 3D reference game on 2.x | `D:/Development/GameDevelopment/GameEngine/JustGameEngineTemplates/just_third_person_template` (`lib/`, `assets/`) |
| Input package (`just_inputs`), resolved from pub | `D:/Development/GameDevelopment/GameEngine/JustGameEngineTemplates/just_platformer_template/packages/just_inputs` |
| 3D renderer (`just_graphics_engine`) | `D:/Development/GameDevelopment/GameEngine/JustGameEngineTemplates/just_platformer_template/packages/just_graphics_engine` |

Never edit anything under `packages/` or the template folders: they are
read-only references.

## The shared 2-D engine

In 2.x `Engine()` makes a **new, uninitialized engine** on every call. The app
makes one engine in `main()` (`lib/core/engine/demo_engine.dart`), initializes
and **starts** it, and registers it in DI. Screens reach it with:

```dart
import '../../core/engine/demo_engine.dart';

late final Engine _engine = demoEngine; // never `Engine()`
late final World _world = _engine.world;
```

### The engine drives itself

The engine is running. Every `GameWidget(engine: _engine)` on screen ticks its
game loop: fixed-step `world.update`, the per-frame `world.frame` (render
interpolation, camera brain, audio), and input. So:

- **Do not call `_world.update(dt)` yourself.** Remove it from screen tickers.
  A screen may keep a `Ticker` (or a periodic timer) purely to `setState` for
  live HUD numbers.
- Time scale: `_engine.time.timeScale`. Pause/resume: `_engine.pause()` /
  `_engine.resume()` are fine, but the screen must leave the engine running
  when it goes (`DemoEngine.reset` does this).
- Never call `_engine.dispose()`, `_engine.stop()` or `_engine.initialize()`
  on the shared engine (a "lifecycle" demo may call `stop()`/`start()` while on
  screen as long as it leaves it running).

### A clean world per demo

```dart
DemoEngine.reset(_engine, include: {DefaultSystem.rendering});
```

destroys every entity, removes every system a demo added, removes stray
physics bodies, resets the camera, gravity and time scale, makes sure the
engine runs, then registers the engine's standard systems listed in
`include` (`registerDefaultSystems`). Use it:

- when building/switching a demo (instead of `destroyAllEntities()` +
  `clearSystems()` + `camera.reset()`), and
- in `dispose()` (`DemoEngine.reset(_engine);` with no `include`).

It also resets the shared camera brain (`engine.cameraSystem.brain`): its
blends, blend table, update mode, `driveOutput`, solo shot and callback.

Prefer `include: {DefaultSystem.rendering, ...}` over constructing
`RenderSystem` yourself: the default one is wired to the engine's stats and
clock (`RenderSystem(camera:, statsSink: engine.rendering, clock: () =>
engine.time.totalTime)`), which 2-D materials and lighting need. The values
are `input, physics, movement, audio, rendering, sprites, levelMaps,
mapCollision, cameras` (`DefaultSystems.all` = every one). `physics` adds
`PhysicsSystem(engine.physics, camera:)` and `PhysicsJointBindingSystem`.
Systems that are not defaults (`ParticleSystemECS`, `EffectSystemECS`,
`HealthSystem`, `LifetimeSystem`, `PostProcessSystem`, …) are added with
`_world.addSystem(...)`.

Anything a screen adds outside the world must be taken out in `dispose()`:
`engine.rendering.overlayHooks` / `backgroundHooks` entries, post-process
passes, event subscriptions (`world.events.on<...>` returns a subscription to
`cancel()`), input assets it loaded are fine to leave.

### 3-D screens own their engine

3-D cannot share the 2-D engine (`Graphics3D` draws a full GPU frame under
every view of its engine). A 3-D screen makes its own:

```dart
import 'package:just_game_engine/graphics_3d.dart';
import 'package:just_game_engine/physics_3d.dart';
import '../../core/engine/demo_engine.dart';

late final Future<Engine> _ready = Demo3DEngine.create(physics: true);
// dispose(): _ready.then((e) => e.dispose());   (fire and forget)
```

`Demo3DEngine.create` returns an initialized, started engine with
`Graphics3D()`, `Physics3D()` when `Physics3D.isSupported` (Jolt; null on the
web), pure-Dart 2-D physics, silent audio, and the default `input`,
`rendering`, `sprites` and `cameras` systems; its camera brain runs in
`CameraUpdateMode.frame`. Show `engine.graphics3D?.unsupportedReason` /
`Physics3D.unsupportedReason` when 3-D cannot run here (the web, no Vulkan).
The pubspec already builds Jolt (`hooks: user_defines: just_jolt: build:
true`) and Flutter GPU is switched on in every platform runner.

## API changes you will hit most

(Full tables in MIGRATION.md.)

- `transform.rotation` → `transform.angle`; `TransformComponent(rotation:)` →
  `TransformComponent(angle:)`.
- `HierarchySystem` gone (every world runs the hierarchy);
  `ParentComponent(localOffset:)` → `localPosition:` (a `Vector3`), and
  `localRotation` is an `EulerRotation`. No manual `ChildrenComponent` upkeep.
- `TextComponent`, `ButtonComponent`, `UIComponent` moved to `just_ui_editor`,
  which this app does **not** depend on. Use `RenderableComponent(renderable:
  TextRenderable(...))` for world-space labels, or a Flutter widget overlay
  (`GameWidget(overlay: ...)`).
- `PhysicsBodyComponent` → `RigidBody2D` (+ `Collider2D` for its shape; a
  `Collider2D` alone is static). Events: `CollisionEnter2DEvent`,
  `CollisionExit2DEvent`, `SensorEnter2DEvent`, `SensorExit2DEvent`.
  Defaults changed (friction 0.5, restitution 0, damping 0.05, mass from
  area). `PhysicsSystem(engine.physics, camera:)`. Queries:
  `Physics2DQueries`. New `CharacterBody2D`.
- Cameras: behaviours, `CameraFollowComponent`, `camera.shake`,
  `worldBounds`, springs are gone → virtual cameras (`VirtualCameraComponent`
  + stage components) and `engine.cameraSystem.brain`.
- Input: `engine.input` is a `just_inputs` `InputService` of named actions
  from an `InputActionAsset` (`.input.json`); `InputComponent(playerIndex:)`
  reads `vector('move')`, `isDown`, `wasPressed`. Devices:
  `engine.input.keyboard/mouse/touchscreen/gamepads`.
- Tiled: `TiledMapFactory`, `TileMapLayerComponent`, `TileMapRenderSystem`,
  `TiledCollisionSystem` → `LevelMapComponent(mapPath: 'assets/maps/x.tmx')`
  with `LevelMapSystem` / `MapCollisionSystem` (`DefaultSystem.levelMaps`,
  `mapCollision`), `LevelMaps.preload/primary/of`.
- Animation: `engine.animation`, tweens, `AnimationStateComponent`,
  `AnimationSystemECS`, `SpriteComponent.frame` gone →
  `SpriteAnimationComponent(atlasPath:, clip:)`, `AnimatorComponent(graphPath:)`
  (`.animator.json` state machines), effects (`MoveEffect`… via
  `EffectSystemECS`), timelines. `Easings.linear` etc.; `EasingType.transform`.
- Assets: `Sprite.fromAsset(path, assets: engine.assets)`,
  `SpriteSheet.fromAsset(..., assets: engine.assets)`,
  `SpriteAtlas.fromAsset(json, assets: engine.assets)`.
- Tags: `TagComponent.of([...])`, `entity.hasTag`, `world.findTagged`,
  `world.allTagged`; targets: `EntityTarget.name/tag/self`.
- Render hooks: `engine.rendering.overlayHooks.add(fn, order:)` /
  `.remove(fn)` (`onRenderOverlay` is deprecated). `GameWidget` always draws
  the world itself.
- Parallax: `engine.parallax` is deprecated → `ParallaxComponent(background:)`
  drawn by `ParallaxRenderSystem` (part of `DefaultSystem.rendering`).
- Legacy render path (`engine.rendering.addRenderable`, `addManagedEmitter`)
  is deprecated → entities with `RenderableComponent` /
  `ParticleEmitterComponent` (+ `ParticleSystemECS`).
- Widgets moved: `import 'package:just_game_engine/widgets.dart';` for
  `GameCameraControls`, `DialogueBoxWidget`, `DialogueChoicesWidget`,
  `SubtitleOverlay`, `LocalizedText`, `OnScreenControls`, `RebindList`, ….
- Re-exports are `show` lists: `just_inputs` asset model classes
  (`ActionMapDef`, `InputActionDef`, `ControlBindingDef`, …) need
  `import 'package:just_inputs/just_inputs.dart' show ...;` (the app depends
  on `just_inputs`, `just_audio_engine`, `just_physics_engine`,
  `just_graphics_engine`, `just_signals`).
- Localization: `LocalizationManager.instance` gone →
  `engine.context.localization`.
- `engine.getSystem<T>()` is deprecated → `engine.subsystem<T>()`.

## Screen style

Keep each screen's existing look: a dark header with a title, a row of demo
chips (`_Demo` enum with `label`, `icon`, `accentColor`, `description`,
`codeSnippet`), a description panel, a code snippet panel, the game canvas
(`GameCameraControls` / `CameraZoomControls` around `GameWidget(engine:
_engine, ...)`), and live stats. Colours: background `#07070F`/`#060D18`,
app primary `#F5746F`. New screens copy the structure of an existing one
(e.g. `lib/features/core_rendering/core_rendering_screen.dart`). Code snippets
shown to the user must be valid 2.x code.

## Done means

- `dart analyze <your files>` reports **no errors and no warnings** (infos
  are fine but keep them few; fix deprecations where the replacement is
  straightforward).
- No `Engine()` calls, no `_world.update(...)` calls, no `clearSystems()`.
- Only touch the files you were assigned (plus new assets under the asset
  folders you were given). Do **not** edit `pubspec.yaml`,
  `lib/features/features_list.dart`, `lib/core/**` or anything under
  `packages/`. Do not run `flutter pub get`, `flutter run` or `git` commands
  that change state. If you need something outside your files, say so in
  your report instead.
- Report back: what changed per file, new files/assets you created, which
  2.x features each screen now demonstrates, and anything you could not
  finish or verify.

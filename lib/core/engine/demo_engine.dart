import 'package:just_game_engine/graphics_3d.dart' show Graphics3D;
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/physics_3d.dart' show Physics3D;

import '../di/app_config.dart';
import 'silent_audio_backend.dart';

/// The app's one 2-D engine: made, initialized and started in `main()`, and
/// shared by every 2-D demo screen.
///
/// In just_game_engine 2.x `Engine()` makes a *new* engine on every call, so
/// screens must never call it to reach this one.
Engine get demoEngine => getIt<Engine>();

/// Builds the shared 2-D engine and gives each demo a clean world.
///
/// The engine is started once and runs for the whole app: every
/// `GameWidget` showing it drives its game loop (fixed-step
/// `world.update`, the per-frame `world.frame`, input and audio), so a demo
/// never calls `world.update` itself.
abstract final class DemoEngine {
  /// How the shared engine is built. No default systems: each demo adds the
  /// ones it shows through [reset]'s `include` or `world.addSystem`.
  static const EngineConfig config = EngineConfig();

  /// The physics engine's gravity when the engine was made, put back by
  /// [reset].
  static double _gravityX = 0;
  static double _gravityY = 981;

  /// Systems the engine put in its world itself; [reset] keeps them.
  static final Set<System> _baseline = Set.identity();

  /// Makes, initializes and starts the shared engine.
  static Future<Engine> boot() async {
    final engine = Engine(config: config);
    await engine.initialize();
    final gravity = engine.physics.gravity;
    _gravityX = gravity.x;
    _gravityY = gravity.y;
    _baseline
      ..clear()
      ..addAll(engine.world.systems);
    engine.start();
    return engine;
  }

  /// Clears [engine]'s world for a demo, then adds the engine's standard
  /// systems in [include] (see [DefaultSystems]).
  ///
  /// Every entity goes, then every system a demo added (the engine's own and
  /// a `GameWidget`'s collider debugger stay); bodies added straight to
  /// `engine.physics` are removed; the camera, gravity and time scale go back
  /// to their defaults; and the engine runs again if a demo paused or
  /// stopped it.
  static void reset(
    Engine engine, {
    Set<DefaultSystem> include = const {},
    List<String> inputMaps = const ['player'],
  }) {
    final world = engine.world;
    // Entities first, while the systems that made their bodies, sounds and
    // passes are still there to take them out.
    world.destroyAllEntities();
    for (final system in [...world.systems]) {
      if (_baseline.contains(system) || system is ColliderDebuggerSystem) {
        continue;
      }
      world.removeSystem(system);
    }
    final physics = engine.physics;
    for (final body in [...physics.bodies]) {
      physics.removeBody(body);
    }
    physics.setGravity(_gravityX, _gravityY);
    engine.cameraSystem.mainCamera.reset();
    // The brain is shared too: a demo's blends, callback or solo shot must
    // not carry over to the next one.
    engine.cameraSystem.brain
      ..reset()
      ..updateMode = CameraUpdateMode.fixed
      ..driveOutput = true
      ..defaultBlend = const CameraBlend()
      ..blendTable = CameraBlendTable()
      ..soloEntity = null
      ..viewportOverride = null
      ..onCameraActivated = null;
    engine.time.timeScale = 1.0;
    ensureRunning(engine);
    if (include.isNotEmpty) {
      registerDefaultSystems(
        world,
        engine,
        include: include,
        inputMaps: inputMaps,
      );
    }
  }

  /// Runs [engine] again if a demo paused or stopped it.
  static void ensureRunning(Engine engine) {
    if (engine.isPaused) {
      engine.resume();
    } else if (engine.state == EngineState.initialized) {
      engine.start();
    }
  }
}

/// Builds the engines the 3-D demos own.
///
/// 3-D lives in an engine of its own rather than in the shared 2-D one:
/// `Graphics3D` draws a full GPU frame under every view of its engine, which
/// a 2-D demo must not pay for. A 3-D screen makes one with [create] and
/// disposes it when it goes (`unawaited(engine.dispose())`).
abstract final class Demo3DEngine {
  /// Makes, initializes and starts a 3-D engine: 3-D graphics, 3-D physics
  /// on Jolt when [physics] and the platform supports it
  /// (`Physics3D.isSupported`), and the standard input, rendering,
  /// animation and camera systems.
  ///
  /// Its audio is silent: the native audio plugin is one per app, and the
  /// shared 2-D engine owns it — disposing a second real `AudioEngine` would
  /// shut it down for every other demo.
  static Future<Engine> create({bool physics = true}) async {
    final engine = Engine(
      config: EngineConfig(
        graphics3D: Graphics3D(),
        physics3D: physics && Physics3D.isSupported ? Physics3D() : null,
        // No 2-D physics system runs here; the pure-Dart engine loads no
        // native code.
        createPhysics: PhysicsEngine.pureDart,
        // ignore: invalid_use_of_visible_for_testing_member
        createAudio: () => AudioEngine.withBackend(SilentAudioBackend()),
        defaultSystems: const {
          DefaultSystem.input,
          DefaultSystem.rendering,
          DefaultSystem.sprites,
          DefaultSystem.cameras,
        },
      ),
    );
    await engine.initialize();
    // The camera follows its targets once per rendered frame, smooth at any
    // frame rate.
    engine.cameraSystem.brain.updateMode = CameraUpdateMode.frame;
    engine.start();
    return engine;
  }
}

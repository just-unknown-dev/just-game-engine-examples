part of 'core_rendering_screen.dart';

// The Core demos: lifecycle, time scale, ECS, subsystems and the game loop.

const Map<_Demo, String> _coreDescriptions = {
  _Demo.lifecycle:
      'EngineState: uninitialized → initializing → initialized → running ⇄ '
      'paused, failed when initialize() throws an EngineInitException, '
      'disposing → disposed (final). Drive the shared engine with '
      'pause/resume/stop/start, or run a throwaway Engine() end to end.',
  _Demo.timeScale:
      'engine.time.timeScale scales the fixed step every system gets. '
      '0 = frozen, 1 = realtime, 3 = triple speed. unscaledDeltaTime '
      'keeps real time for UI and camera effects.',
  _Demo.ecs:
      'Entities carry tags (TagComponent.of), found through the world\'s tag '
      'index: findTagged / allTagged / hasTag. The seeker points at its '
      'prey with an EntityTarget and destroys what it catches. Entity ids '
      'are never reused — watch "last id" keep climbing.',
  _Demo.subsystems:
      'The engine registers RenderingEngine, PhysicsEngine, InputService, '
      'AudioEngine, AssetManager, CacheManager, CameraSystem and the '
      'World, each found with engine.subsystem<T>(). An EnginePlugin gets '
      'every frame and draws over the world.',
  _Demo.gameLoop:
      'Systems run in the fixed step (update) and, with FrameSystem, once '
      'per rendered frame (frame, with alpha). Top: moved per step. '
      'Middle: per step + capturePrevious(), so RenderSystem interpolates. '
      'Bottom: moved in frame(). On a >60 Hz display the top one stutters.',
};

const Map<_Demo, String> _coreSnippets = {
  _Demo.lifecycle:
      'final engine = Engine(\n'
      '  config: const EngineConfig(defaultSystems: DefaultSystems.all),\n'
      ');\n'
      'engine.stateListenable.addListener(\n'
      "  () => debugPrint('\${engine.state}'),\n"
      ');\n'
      'try {\n'
      '  await engine.initialize(); // initializing → initialized\n'
      '} on EngineInitException catch (e) {\n'
      '  // state: failed; engine.lastError == e; may retry\n'
      "  debugPrint('failed at \${e.stage}: \${e.cause}');\n"
      '}\n'
      'engine.start();  // → running (StateError unless initialized)\n'
      'engine.pause();  // → paused: updates stop, drawing goes on\n'
      'engine.resume(); // → running\n'
      'engine.stop();   // → initialized; start() again later\n'
      'await engine.dispose(); // disposing → disposed: final',
  _Demo.timeScale:
      '// Slow motion:\n'
      'engine.time.timeScale = 0.5;\n\n'
      '// Freeze the simulation, keep drawing:\n'
      'engine.time.timeScale = 0.0;\n\n'
      '// Realtime:\n'
      'engine.time.timeScale = 1.0;\n\n'
      'engine.time.deltaTime;         // scaled\n'
      'engine.time.unscaledDeltaTime; // real time\n'
      'engine.time.totalTime;         // stands still while paused',
  _Demo.ecs:
      'final e = world.createEntityWithComponents([\n'
      '  TransformComponent(position: Vector3(100, 100, 0)),\n'
      '  RenderableComponent(renderable: CircleRenderable(\n'
      '    radius: 7, fillColor: Colors.green)),\n'
      "  TagComponent.of(['orbiter', 'green']),\n"
      ']);\n'
      "e.hasTag('green');          // true\n"
      "world.allTagged('green');   // every active #green\n"
      "world.findTagged('green');  // the oldest one\n"
      'world.destroyEntity(e);     // its id is never handed out again\n\n'
      '// Point at another entity by name, tag or self:\n'
      "const target = EntityTarget.tag('green');\n"
      'final prey = target.resolve(world, seeker);',
  _Demo.subsystems:
      '// Subsystems, by the type they were registered under:\n'
      'final rendering = engine.subsystem<RenderingEngine>();\n'
      'final physics   = engine.subsystem<PhysicsEngine>();\n'
      'final input     = engine.subsystem<InputService>();\n'
      '// getSystem<T>() is deprecated; ECS systems: world.getSystem<T>()\n\n'
      '// A plugin: every frame\'s update, plus an overlay:\n'
      'class FrameCounter extends EnginePlugin {\n'
      '  int frames = 0;\n'
      '  @override\n'
      "  String get id => 'demo.frame_counter';\n"
      '  @override\n'
      '  void update(double dt) => frames++;\n'
      '  @override\n'
      '  void renderOverlay(Canvas canvas, Size size) {/* … */}\n'
      '}\n'
      'await engine.plugins.register(FrameCounter());\n'
      "engine.plugins.unregister('demo.frame_counter');\n\n"
      '// Services start in initialize() and stop in dispose():\n'
      '// Engine(config: EngineConfig(services: [MyService()]))',
  _Demo.gameLoop:
      'class Lanes extends System implements FrameSystem {\n'
      '  @override\n'
      '  List<Type> get requiredComponents =>\n'
      '      const [TransformComponent, Lane];\n\n'
      '  @override\n'
      '  void update(double dt) { // the fixed step, scaled\n'
      '    for (final e in entities) {\n'
      '      final t = e.getComponent<TransformComponent>()!;\n'
      '      t.capturePrevious(); // drawn interpolated\n'
      '      t.position.x += speed * dt;\n'
      '    }\n'
      '  }\n\n'
      '  @override\n'
      '  void frame(double dt, double alpha) {\n'
      '    // once per rendered frame, after the steps\n'
      '  }\n'
      '}\n\n'
      'engine.gameLoop.fixedDeltaTime;          // 1/60 s\n'
      "engine.performanceStats['lastUpdateMs'];\n"
      "engine.performanceStats['systemTimesMs']; // per task",
};

// -----------------------------------------------------------------------------
// ECS helpers
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// ECS helpers
// -----------------------------------------------------------------------------

class _OrbitComponent extends Component {
  _OrbitComponent({
    required this.radius,
    required this.speed,
    required this.phase,
  }) : angle = phase;

  final double radius;
  final double speed;
  final double phase;
  double angle;
}

class _OrbitSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _OrbitComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final o = entity.getComponent<_OrbitComponent>()!;
      o.angle += o.speed * dt;
      t.position.setValues(
        math.cos(o.angle) * o.radius,
        math.sin(o.angle) * o.radius,
        0,
      );
    });
  }
}

/// Chases whatever its [target] resolves to and destroys what it catches.
class _SeekComponent extends Component {
  _SeekComponent(this.target);

  EntityTarget target;

  /// From the seeker to its prey, in its own space — for drawing.
  Offset? lineTo;

  int caught = 0;
}

class _SeekSystem extends System {
  static const double speed = 260;

  @override
  List<Type> get requiredComponents => [TransformComponent, _SeekComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final seek = entity.getComponent<_SeekComponent>()!;
      final t = entity.getComponent<TransformComponent>()!;
      final here = t.position.toOffset();
      // A tag target resolves to the oldest active entity with the tag.
      final prey = seek.target.resolve(world, entity);
      final there = prey == null
          ? Offset.zero
          : prey.getComponent<TransformComponent>()!.position.toOffset();
      final delta = there - here;
      final dist = delta.distance;
      seek.lineTo = prey == null ? null : delta;
      if (prey != null && dist < 14) {
        seek.caught++;
        world.commands.destroy(prey);
        return;
      }
      if (dist < 1) return;
      final step = math.min(dist, speed * dt);
      t.position.setValues(
        here.dx + delta.dx / dist * step,
        here.dy + delta.dy / dist * step,
        0,
      );
    });
  }
}

enum _LaneMode { fixed, interpolated, frame }

class _LaneComponent extends Component {
  _LaneComponent(this.mode, this.y);
  final _LaneMode mode;
  final double y;
  double phase = 0;
}

/// Moves the game-loop demo's three balls — two in the fixed step, one per
/// rendered frame — and counts both phases.
class _LaneSystem extends System implements FrameSystem {
  static const double speed = 1.8;
  static const double reach = 260;

  int fixedSteps = 0;
  int frames = 0;
  double lastAlpha = 0;

  @override
  List<Type> get requiredComponents => [TransformComponent, _LaneComponent];

  void _place(TransformComponent t, _LaneComponent lane) =>
      t.position.setValues(math.sin(lane.phase) * reach, lane.y, 0);

  @override
  void update(double dt) {
    fixedSteps++;
    forEach((entity) {
      final lane = entity.getComponent<_LaneComponent>()!;
      if (lane.mode == _LaneMode.frame) return;
      final t = entity.getComponent<TransformComponent>()!;
      // The pose before this step: RenderSystem draws between the two.
      if (lane.mode == _LaneMode.interpolated) t.capturePrevious();
      lane.phase += speed * dt;
      _place(t, lane);
    });
  }

  @override
  void frame(double deltaTime, double alpha) {
    frames++;
    lastAlpha = alpha;
    forEach((entity) {
      final lane = entity.getComponent<_LaneComponent>()!;
      if (lane.mode != _LaneMode.frame) return;
      lane.phase += speed * deltaTime;
      _place(entity.getComponent<TransformComponent>()!, lane);
    });
  }
}

/// A plugin: hears every frame's update (even while paused) and draws over
/// the world in screen space.
class _HudPlugin extends EnginePlugin {
  static const String pluginId = 'demo.core_engine.hud';

  int updates = 0;
  double seconds = 0;
  final TextPainter _painter = TextPainter(textDirection: TextDirection.ltr);

  @override
  String get id => pluginId;

  @override
  void update(double dt) {
    updates++;
    seconds += dt;
  }

  @override
  void renderOverlay(Canvas canvas, Size size) {
    _painter
      ..text = TextSpan(
        text:
            'EnginePlugin "$pluginId"\n'
            'updates $updates  ·  ${seconds.toStringAsFixed(1)} s real time',
        style: const TextStyle(
          color: Color(0xFFCE93D8),
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      )
      ..layout();
    _painter.paint(
      canvas,
      Offset(
        size.width - _painter.width - 12,
        size.height - _painter.height - 12,
      ),
    );
  }

  @override
  void detach() => _painter.dispose();
}

/// A service whose start fails, to show `EngineInitException`.
class _FlakyService extends EngineService {
  @override
  Future<void> start(ServiceContext context) async {
    throw StateError('this demo service always fails to start');
  }

  @override
  Future<void> stop() async {}
}

const List<String> _colorTags = ['green', 'blue', 'violet', 'red', 'gold'];
const Map<String, Color> _palette = {
  'green': Color(0xFF66BB6A),
  'blue': Color(0xFF29B6F6),
  'violet': Color(0xFFAB47BC),
  'red': Color(0xFFFF7043),
  'gold': Color(0xFFFFCA28),
};

// -----------------------------------------------------------------------------
// Builders, panels and controls
// -----------------------------------------------------------------------------

extension _CoreDemos on _CoreRenderingScreenState {
  Entity _spawnText(
    String text,
    Offset position, {
    double fontSize = 13,
    Color color = Colors.white,
    int layer = 12,
    List<Component> extra = const [],
  }) {
    return _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(position)),
      RenderableComponent(
        renderable: TextRenderable(
          text: text,
          textStyle: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          layer: layer,
        ),
      ),
      ...extra,
    ]);
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  void _buildLifecycle() {
    for (int i = 0; i < 6; i++) {
      final color = HSLColor.fromAHSL(1.0, i * 60.0, 0.7, 0.55).toColor();
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 5,
            getBoundsCallback: () =>
                Rect.fromCircle(center: Offset.zero, radius: 50),
            onRender: (canvas, _) {
              canvas.drawCircle(
                Offset.zero,
                14,
                Paint()
                  ..color = color.withValues(alpha: 0.28)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
              );
              canvas.drawCircle(Offset.zero, 10, Paint()..color = color);
              canvas.drawCircle(
                Offset.zero,
                10,
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.5)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5,
              );
            },
          ),
        ),
        _OrbitComponent(radius: 140, speed: 0.55, phase: i * math.pi / 3),
      ]);
    }

    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 10,
          getBoundsCallback: () =>
              Rect.fromCircle(center: Offset.zero, radius: 80),
          onRender: (canvas, _) {
            canvas.drawCircle(
              Offset.zero,
              72,
              Paint()
                ..color = const Color(0xFF0D1F33).withValues(alpha: 0.9)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
            );
            canvas.drawCircle(
              Offset.zero,
              64,
              Paint()..color = const Color(0xFF0D1F33),
            );
            canvas.drawCircle(
              Offset.zero,
              64,
              Paint()
                ..color = _stateColor(_engine.state).withValues(alpha: 0.7)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            );
          },
        ),
      ),
      _PulseComponent(minScale: 0.96, maxScale: 1.04, speed: 1.4),
    ], name: 'engine-hub');

    _spawnText('ENGINE', const Offset(0, -10), fontSize: 18);

    _statusMessage = 'Pause, resume, stop or start the shared engine';
  }

  static Color _stateColor(EngineState state) => switch (state) {
    EngineState.running => const Color(0xFF66BB6A),
    EngineState.paused => const Color(0xFFFFCA28),
    EngineState.initialized => const Color(0xFF29B6F6),
    EngineState.failed => const Color(0xFFFF5252),
    EngineState.disposing || EngineState.disposed => const Color(0xFF78909C),
    _ => const Color(0xFFB0BEC5),
  };

  void _pause() {
    _engine.pause();
    _refresh(() => _statusMessage = 'Paused: updates stop, drawing goes on');
  }

  void _resume() {
    _engine.resume();
    _refresh(() => _statusMessage = 'Resumed');
  }

  void _stop() {
    _engine.stop();
    _refresh(
      () => _statusMessage = 'Stopped: back to initialized — start() again',
    );
  }

  void _start() {
    _engine.start();
    _refresh(() => _statusMessage = 'Started');
  }

  void _logSandbox(String line) {
    _sandboxLog.add(line);
    if (_sandboxLog.length > 12) _sandboxLog.removeAt(0);
    if (mounted) _refresh(() {});
  }

  /// Makes a second, throwaway engine and walks it through its whole life
  /// — the shared engine is never initialized or disposed.
  ///
  /// Its audio is silent and its physics pure Dart: the native audio
  /// plugin belongs to the shared engine, and disposing a second real
  /// `AudioEngine` would shut it down for every demo.
  Future<void> _runSandbox({required bool failing}) async {
    if (_sandboxBusy) return;
    _sandboxBusy = true;
    _sandboxLog.clear();
    final probe = Engine(
      config: EngineConfig(
        // ignore: invalid_use_of_visible_for_testing_member
        createAudio: () => AudioEngine.withBackend(SilentAudioBackend()),
        createPhysics: PhysicsEngine.pureDart,
        deferAudioUntilInput: false,
        services: [if (failing) _FlakyService()],
      ),
    );
    void onState() => _logSandbox('  state → ${probe.state.name}');
    _logSandbox(
      'Engine(${failing ? 'services: [FlakyService()]' : ''})'
      ' → ${probe.state.name}',
    );
    probe.stateListenable.addListener(onState);

    Future<void> beat() =>
        Future<void>.delayed(const Duration(milliseconds: 350));

    try {
      _logSandbox('await initialize()');
      await probe.initialize();
      await beat();
      _logSandbox('start()');
      probe.start();
      await beat();
      _logSandbox('pause()');
      probe.pause();
      await beat();
      _logSandbox('resume()');
      probe.resume();
      await beat();
      _logSandbox('stop()');
      probe.stop();
      await beat();
    } on EngineInitException catch (e) {
      _logSandbox('EngineInitException: stage "${e.stage}"');
      _logSandbox('  cause: ${e.cause}');
      _logSandbox('  lastError is it: ${identical(probe.lastError, e)}');
      await beat();
    } finally {
      _logSandbox('await dispose()');
      await probe.dispose();
      probe.stateListenable.removeListener(onState);
    }
    try {
      probe.world;
    } on EngineNotReadyError catch (e) {
      _logSandbox('probe.world → EngineNotReadyError (${e.state.name})');
    }
    _sandboxBusy = false;
    if (mounted) _refresh(() {});
  }

  // -------------------------------------------------------------------------
  // Time scale
  // -------------------------------------------------------------------------

  void _buildTimeScale() {
    final speeds = [0.4, 0.8, 1.4, 2.2];
    final radii = [60.0, 110.0, 165.0, 220.0];
    final colors = [
      const Color(0xFF42A5F5),
      const Color(0xFF66BB6A),
      const Color(0xFFFFCA28),
      const Color(0xFFFF7043),
    ];

    for (int i = 0; i < 4; i++) {
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          syncTransform: false,
          renderable: CustomRenderable(
            layer: 2,
            getBoundsCallback: () =>
                Rect.fromCircle(center: Offset.zero, radius: radii[i] + 2),
            onRender: (canvas, _) {
              canvas.drawCircle(
                Offset.zero,
                radii[i],
                Paint()
                  ..color = colors[i].withValues(alpha: 0.1)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1,
              );
            },
          ),
        ),
      ]);

      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 8,
            getBoundsCallback: () =>
                Rect.fromCircle(center: Offset.zero, radius: 22),
            onRender: (canvas, _) {
              canvas.drawCircle(
                Offset.zero,
                16,
                Paint()
                  ..color = colors[i].withValues(alpha: 0.25)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
              );
              canvas.drawCircle(Offset.zero, 11, Paint()..color = colors[i]);
              canvas.drawCircle(
                Offset.zero,
                11,
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.5)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5,
              );
            },
          ),
        ),
        _OrbitComponent(
          radius: radii[i],
          speed: speeds[i],
          phase: i * math.pi / 2,
        ),
      ], name: 'timescale-ball-$i');
    }

    _statusMessage = 'Adjust the time scale slider below';
  }

  void _setTimeScale(double v) {
    _engine.time.timeScale = v;
    _refresh(() => _statusMessage = 'timeScale → ${v.toStringAsFixed(2)}x');
  }

  // -------------------------------------------------------------------------
  // ECS — tags, targets, ids
  // -------------------------------------------------------------------------

  void _buildEcs() {
    _destroyed = 0;
    _world.addSystem(_SeekSystem()..priority = 70);

    final seek = _seek = _SeekComponent(const EntityTarget.tag('green'));
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 9,
          onRender: (canvas, _) {
            final to = seek.lineTo;
            if (to != null) {
              canvas.drawLine(
                Offset.zero,
                to,
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.35)
                  ..strokeWidth = 1.5,
              );
            }
            canvas.drawCircle(Offset.zero, 12, Paint()..color = Colors.white);
            canvas.drawCircle(
              Offset.zero,
              12,
              Paint()
                ..color = const Color(0xFF66BB6A)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            );
          },
        ),
      ),
      seek,
      TagComponent.of(['seeker']),
    ], name: 'Seeker');

    _spawnEcsBatch(16);
    _statusMessage = 'The seeker hunts #${seek.target.value} — then the next';
  }

  void _spawnEcsBatch(int count) {
    final rng = math.Random();
    for (int i = 0; i < count; i++) {
      final tag = _colorTags[rng.nextInt(_colorTags.length)];
      final color = _palette[tag]!;
      final radius = 60.0 + rng.nextDouble() * 170;
      final speed = (0.3 + rng.nextDouble() * 0.9) * (rng.nextBool() ? 1 : -1);
      final phase = rng.nextDouble() * math.pi * 2;

      final entity = _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 6,
            getBoundsCallback: () =>
                Rect.fromCircle(center: Offset.zero, radius: 18),
            onRender: (canvas, _) {
              canvas.drawCircle(
                Offset.zero,
                10,
                Paint()
                  ..color = color.withValues(alpha: 0.22)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
              );
              canvas.drawCircle(Offset.zero, 7, Paint()..color = color);
            },
          ),
        ),
        _OrbitComponent(radius: radius, speed: speed, phase: phase),
        TagComponent.of(['orbiter', tag]),
      ]);
      _lastId = entity.id;
    }
    if (mounted) {
      _refresh(() => _statusMessage = 'Spawned $count — last id $_lastId');
    }
  }

  void _destroyTagged(String tag) {
    final doomed = _world.allTagged(tag);
    for (final e in [...doomed]) {
      _world.destroyEntity(e);
    }
    _destroyed += doomed.length;
    _refresh(() => _statusMessage = 'Destroyed ${doomed.length} #$tag');
  }

  void _cycleSeekTarget() {
    final seek = _seek;
    if (seek == null) return;
    final i = _colorTags.indexOf(seek.target.value);
    final next = _colorTags[(i + 1) % _colorTags.length];
    seek.target = EntityTarget.tag(next);
    _refresh(() => _statusMessage = 'Seeker target → ${seek.target.label}');
  }

  String get _tagCounts => [
    for (final tag in _colorTags) '$tag ${_world.allTagged(tag).length}',
  ].join(' ');

  // -------------------------------------------------------------------------
  // Subsystems
  // -------------------------------------------------------------------------

  void _buildSubsystems() {
    const nodes = [
      ('Rendering', Color(0xFF2A9D8F)),
      ('Physics', Color(0xFFF4A261)),
      ('Input', Color(0xFFE76F51)),
      ('Audio', Color(0xFF90BE6D)),
      ('Assets', Color(0xFFC77DFF)),
      ('Cache', Color(0xFF4DB6AC)),
      ('Cameras', Color(0xFF29B6F6)),
      ('World', Color(0xFFFFCA28)),
    ];

    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 10,
          getBoundsCallback: () =>
              Rect.fromCircle(center: Offset.zero, radius: 60),
          onRender: (canvas, _) {
            canvas.drawCircle(
              Offset.zero,
              52,
              Paint()..color = const Color(0xFF0D1F33),
            );
            canvas.drawCircle(
              Offset.zero,
              52,
              Paint()
                ..color = const Color(0xFFAB47BC).withValues(alpha: 0.6)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            );
          },
        ),
      ),
      _PulseComponent(minScale: 0.97, maxScale: 1.03, speed: 1.2),
    ]);

    _spawnText('ENGINE', const Offset(0, -6));

    for (var i = 0; i < nodes.length; i++) {
      final (name, color) = nodes[i];
      final phase = i * 2 * math.pi / nodes.length;
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 7,
            getBoundsCallback: () =>
                Rect.fromCircle(center: Offset.zero, radius: 36),
            onRender: (canvas, _) {
              canvas.drawCircle(
                Offset.zero,
                28,
                Paint()
                  ..color = color.withValues(alpha: 0.22)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
              );
              canvas.drawCircle(Offset.zero, 22, Paint()..color = color);
              canvas.drawCircle(
                Offset.zero,
                22,
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.4)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2,
              );
            },
          ),
        ),
        _OrbitComponent(radius: 170, speed: 0.4, phase: phase),
      ], name: 'node-${name.toLowerCase()}');

      _spawnText(
        name,
        Offset.zero,
        fontSize: 9,
        color: Colors.white,
        layer: 9,
        extra: [_OrbitComponent(radius: 170, speed: 0.4, phase: phase)],
      );
    }

    // A plugin: updated every frame by the engine, drawing over the world.
    final plugin = _plugin = _HudPlugin();
    unawaited(_engine.plugins.register(plugin));

    _statusMessage = 'Each node is a subsystem: engine.subsystem<T>()';
  }

  // -------------------------------------------------------------------------
  // Game loop
  // -------------------------------------------------------------------------

  void _buildGameLoop() {
    final lanes = _lanes = _LaneSystem()..priority = 85;
    _world.addSystem(lanes);
    _rateFixed = 0;
    _rateFrames = 0;
    _rateSince = Duration.zero;
    _fixedRate = 0;
    _frameRate = 0;

    final rows = [
      (_LaneMode.fixed, -90.0, const Color(0xFFFF7043), 'update() only'),
      (
        _LaneMode.interpolated,
        0.0,
        const Color(0xFFFFCA28),
        'update() + capturePrevious()',
      ),
      (_LaneMode.frame, 90.0, const Color(0xFF66BB6A), 'FrameSystem.frame()'),
    ];
    for (final (mode, y, color, label) in rows) {
      // The track.
      _world.createEntityWithComponents([
        TransformComponent(position: Vector3(-_LaneSystem.reach, y, 0)),
        RenderableComponent(
          renderable: LineRenderable(
            endPoint: const Offset(_LaneSystem.reach * 2, 0),
            color: color.withValues(alpha: 0.15),
            width: 2,
            layer: 1,
          ),
        ),
      ]);
      // The ball.
      _world.createEntityWithComponents([
        TransformComponent(position: Vector3(0, y, 0)),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: 14,
            fillColor: color,
            strokeColor: Colors.white.withValues(alpha: 0.7),
            strokeWidth: 2,
            layer: 7,
          ),
        ),
        _LaneComponent(mode, y),
      ]);
      _spawnText(
        label,
        Offset(0, y - 30),
        fontSize: 11,
        color: color,
        layer: 9,
      );
    }

    _statusMessage = 'Fixed step vs per-frame — live numbers top-left';
  }

  String get _coreStatsLine {
    final t = _engine.time;
    var line =
        'state ${_engine.state.name}'
        '  fps ${_engine.gameLoop.currentFPS}'
        '  dt ${t.deltaTime.toStringAsFixed(4)}'
        '  total ${t.totalTime.toStringAsFixed(1)} s'
        '  scale ${t.timeScale.toStringAsFixed(2)}x'
        '  entities ${_world.entities.length}';
    if (_demo == _Demo.timeScale) {
      line +=
          '  real dt ${t.unscaledDeltaTime.toStringAsFixed(4)}'
          '  real total ${t.unscaledTotalTime.toStringAsFixed(1)} s';
    }
    if (_demo == _Demo.ecs) {
      line +=
          '  orbiters ${_world.allTagged('orbiter').length}'
          '  last id $_lastId'
          '  destroyed ${_destroyed + (_seek?.caught ?? 0)}'
          '  · $_tagCounts';
    }
    return line;
  }

  Widget? _buildOverlay() {
    final panel = switch (_demo) {
      _Demo.lifecycle => _lifecyclePanel(),
      _Demo.gameLoop => _loopPanel(),
      _ => null,
    };
    if (panel == null) return null;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 36, 10, 10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xCC060D18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _demo.accentColor.withValues(alpha: 0.4),
              ),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontFamily: 'monospace',
                height: 1.4,
              ),
              child: panel,
            ),
          ),
        ),
      ),
    );
  }

  Widget _lifecyclePanel() {
    final state = _engine.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('shared engine — EngineState'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final s in EngineState.values)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: s == state
                      ? _stateColor(s).withValues(alpha: 0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: s == state ? _stateColor(s) : Colors.white12,
                  ),
                ),
                child: Text(
                  s.name,
                  style: TextStyle(
                    color: s == state ? Colors.white : Colors.white30,
                    fontSize: 9.5,
                  ),
                ),
              ),
          ],
        ),
        if (_transitions.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('stateListenable:'),
          for (final t in _transitions) Text('  $t'),
        ],
        if (_sandboxLog.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'throwaway Engine()${_sandboxBusy ? ' …' : ''}',
            style: const TextStyle(color: Color(0xFF29B6F6)),
          ),
          for (final line in _sandboxLog) Text(line),
        ],
      ],
    );
  }

  Widget _loopPanel() {
    final stats = _engine.performanceStats;
    final lanes = _lanes;
    final fixedDt = _engine.gameLoop.fixedDeltaTime;
    final tasks =
        (stats['systemTimesMs'] as Map?)?.cast<String, double>() ??
        const <String, double>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'fixed step  ${(fixedDt * 1000).toStringAsFixed(2)} ms'
          ' (${(1 / fixedDt).toStringAsFixed(0)} Hz)',
        ),
        Text('update()/s  ${_fixedRate.toStringAsFixed(1)}'),
        Text('frame()/s   ${_frameRate.toStringAsFixed(1)}'),
        Text('alpha       ${(lanes?.lastAlpha ?? 0).toStringAsFixed(2)}'),
        const SizedBox(height: 4),
        const Text(
          'engine.performanceStats',
          style: TextStyle(color: Color(0xFFFF7043)),
        ),
        Text('frame       ${stats['frame']}'),
        Text(
          'lastUpdate  '
          '${((stats['lastUpdateMs'] as num?) ?? 0).toStringAsFixed(3)} ms',
        ),
        Text(
          'budgetLeft  '
          '${((stats['budgetRemainingMs'] as num?) ?? 0).toStringAsFixed(2)} ms'
          '${stats['isOverBudget'] == true ? '  OVER' : ''}',
        ),
        for (final entry in tasks.entries)
          Text(
            '  ${entry.key.padRight(10)} ${entry.value.toStringAsFixed(3)} ms',
          ),
      ],
    );
  }

  Widget _buildLifecycleControls() {
    final state = _engine.state;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton(
          'Pause',
          const Color(0xFFFFCA28),
          state == EngineState.running ? _pause : null,
        ),
        _actionButton(
          'Resume',
          const Color(0xFF66BB6A),
          state == EngineState.paused ? _resume : null,
        ),
        _actionButton(
          'Stop',
          const Color(0xFFFF5252),
          state == EngineState.running || state == EngineState.paused
              ? _stop
              : null,
        ),
        _actionButton(
          'Start',
          const Color(0xFF66BB6A),
          state == EngineState.initialized ? _start : null,
        ),
        const SizedBox(width: 6),
        const Text(
          'throwaway Engine():',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        _actionButton(
          'Full lifecycle',
          const Color(0xFF29B6F6),
          _sandboxBusy ? null : () => _runSandbox(failing: false),
        ),
        _actionButton(
          'Failing initialize()',
          const Color(0xFFFF5252),
          _sandboxBusy ? null : () => _runSandbox(failing: true),
        ),
      ],
    );
  }

  Widget _buildTimeScaleControls() {
    final scale = _engine.time.timeScale;
    return Row(
      children: [
        const Text(
          'timeScale',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Expanded(
          child: Slider(
            value: scale.clamp(0.0, 3.0),
            min: 0,
            max: 3,
            divisions: 30,
            activeColor: _demo.accentColor,
            onChanged: _setTimeScale,
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(
            '${scale.toStringAsFixed(2)}x',
            style: TextStyle(
              color: _demo.accentColor,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        _actionButton('0x', _demo.accentColor, () => _setTimeScale(0.0)),
        const SizedBox(width: 4),
        _actionButton('1x', _demo.accentColor, () => _setTimeScale(1.0)),
        const SizedBox(width: 4),
        _actionButton('2x', _demo.accentColor, () => _setTimeScale(2.0)),
      ],
    );
  }

  Widget _buildEcsControls() {
    const green = Color(0xFF66BB6A);
    final seekLabel = _seek?.target.label ?? '-';
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton('+8', green, () => _spawnEcsBatch(8)),
        _actionButton('+32', green, () => _spawnEcsBatch(32)),
        _actionButton(
          'Destroy #blue',
          const Color(0xFFFF5252),
          () => _destroyTagged('blue'),
        ),
        _actionButton(
          'Destroy #orbiter',
          const Color(0xFFFF5252),
          () => _destroyTagged('orbiter'),
        ),
        _actionButton('Seeker → $seekLabel', green, _cycleSeekTarget),
      ],
    );
  }

  Widget _buildSubsystemsControls() {
    final items = [
      ('RenderingEngine', _engine.subsystem<RenderingEngine>() != null),
      ('PhysicsEngine', _engine.subsystem<PhysicsEngine>() != null),
      ('InputService', _engine.subsystem<InputService>() != null),
      ('AudioEngine', _engine.subsystem<AudioEngine>() != null),
      ('AssetManager', _engine.subsystem<AssetManager>() != null),
      ('CacheManager', _engine.subsystem<CacheManager>() != null),
      ('CameraSystem', _engine.subsystem<CameraSystem>() != null),
      ('World', _engine.subsystem<World>() != null),
      (
        'plugins: ${_engine.plugins.all.length}',
        _engine.plugins.all.isNotEmpty,
      ),
      ('services: ${_engine.services.all.length}', true),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final (name, active) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFAB47BC).withValues(alpha: 0.15)
                  : const Color(0xFF111C2A),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: active
                    ? const Color(0xFFAB47BC).withValues(alpha: 0.5)
                    : const Color(0xFF1A2535),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 11,
                  color: active ? const Color(0xFFAB47BC) : Colors.white30,
                ),
                const SizedBox(width: 5),
                Text(
                  name,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white30,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGameLoopControls() {
    return Row(
      children: [
        const Flexible(
          child: Text(
            'GameWidget ticks the loop: fixed steps, then the frame phase  *  '
            'try timeScale 0.25 in Time Scale',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        _actionButton(
          'Reset',
          _demo.accentColor,
          () => _buildDemo(_Demo.gameLoop),
        ),
      ],
    );
  }
}

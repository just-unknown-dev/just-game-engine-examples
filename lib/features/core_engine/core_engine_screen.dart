import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  lifecycle,
  timeScale,
  ecs,
  subsystems,
  gameLoop;

  String get label => switch (this) {
    lifecycle => 'Lifecycle',
    timeScale => 'Time Scale',
    ecs => 'ECS',
    subsystems => 'Subsystems',
    gameLoop => 'Game Loop',
  };

  IconData get icon => switch (this) {
    lifecycle => Icons.play_circle_outline,
    timeScale => Icons.speed,
    ecs => Icons.grid_on,
    subsystems => Icons.device_hub,
    gameLoop => Icons.refresh,
  };

  Color get accentColor => switch (this) {
    lifecycle => const Color(0xFF29B6F6),
    timeScale => const Color(0xFFFFCA28),
    ecs => const Color(0xFF66BB6A),
    subsystems => const Color(0xFFAB47BC),
    gameLoop => const Color(0xFFFF7043),
  };

  String get description => switch (this) {
    lifecycle =>
      'Engine transitions through uninitialized -> initialized -> running -> paused -> stopped. '
          'Use the buttons to drive each state transition explicitly.',
    timeScale =>
      'Engine.time.timeScale scales deltaTime for all systems. '
          '0 = frozen, 1 = realtime, 2 = double speed. Useful for bullet-time or pause menus.',
    ecs =>
      'Entity-Component-System architecture: entities are IDs, components carry data, '
          'systems iterate archetypes. Spawn/destroy entities at runtime without GC spikes.',
    subsystems =>
      'Engine bundles RenderingEngine, PhysicsEngine, InputManager, AudioEngine, '
          'AssetManager as optional subsystems - each queryable via engine.getSystem<T>().',
    gameLoop =>
      'The game loop drives world.update(dt) then rendering each frame via a Flutter Ticker. '
          'Frame count, total time, fps and deltaTime are all tracked by TimeManager.',
  };

  String get codeSnippet => switch (this) {
    lifecycle =>
      'final engine = Engine();\n'
          'await engine.initialize();\n\n'
          'engine.start();   // -> EngineState.running\n'
          'engine.pause();   // -> EngineState.paused\n'
          'engine.resume();  // -> EngineState.running\n'
          'engine.stop();    // -> EngineState.stopped',
    timeScale =>
      '// Slow-motion (50 %):\n'
          'engine.time.timeScale = 0.5;\n\n'
          '// Bullet-time:\n'
          'engine.time.timeScale = 0.1;\n\n'
          '// Realtime:\n'
          'engine.time.timeScale = 1.0;\n\n'
          '// Freeze (keep rendering, stop logic):\n'
          'engine.time.timeScale = 0.0;',
    ecs =>
      'final world = engine.world;\n'
          'final entity = world.createEntityWithComponents([\n'
          '  TransformComponent(position: Offset(100, 100)),\n'
          '  RenderableComponent(renderable: CircleRenderable(radius: 20)),\n'
          ']);\n\n'
          '// Remove later:\n'
          'world.destroyEntity(entity.id);',
    subsystems =>
      '// Check if a subsystem is active:\n'
          'final rendering = engine.getSystem<RenderingEngine>();\n'
          'final physics   = engine.getSystem<PhysicsEngine>();\n\n'
          '// Access subsystem directly:\n'
          'engine.rendering.camera.zoom = 1.5;\n'
          "engine.audio.play('bgm');",
    gameLoop =>
      '// TimeManager exposes:\n'
          'engine.time.deltaTime;   // scaled dt in seconds\n'
          'engine.time.totalTime;   // total scaled time\n'
          'engine.time.fps;         // frames per second\n'
          'engine.time.frameCount;  // total frames since start\n'
          'engine.time.timeScale;   // current multiplier',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS helpers
// ─────────────────────────────────────────────────────────────────────────────

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

class _PulseComponent extends Component {
  _PulseComponent({
    required this.minScale,
    required this.maxScale,
    required this.speed,
    this.phase = 0,
  });

  final double minScale;
  final double maxScale;
  final double speed;
  final double phase;
  double time = 0;
}

class _SpawnTagComponent extends Component {
  _SpawnTagComponent({required this.spawnedAt});
  final double spawnedAt;
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
      t.position = Offset(
        math.cos(o.angle) * o.radius,
        math.sin(o.angle) * o.radius,
      );
    });
  }
}

class _PulseSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _PulseComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final p = entity.getComponent<_PulseComponent>()!;
      p.time += dt;
      final wave = (math.sin(p.phase + p.time * p.speed) + 1) / 2;
      t.scale = p.minScale + (p.maxScale - p.minScale) * wave;
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class CoreEngineScreen extends StatefulWidget {
  const CoreEngineScreen({super.key});

  @override
  State<CoreEngineScreen> createState() => _CoreEngineScreenState();
}

class _CoreEngineScreenState extends State<CoreEngineScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;

  _Demo _demo = _Demo.lifecycle;
  String _statusMessage = '';
  bool _initialized = false;

  int _ecsBatchSize = 12;

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureInitialized();
      _buildDemo(_demo);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.stop();
    _world.destroyAllEntities();
    _world.clearSystems();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    if (_engine.state == EngineState.running) {
      _world.update(dt * _engine.time.timeScale);
    }

    if (mounted) setState(() {});
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final ok = await _engine.initialize();
    _initialized = ok;
    if (ok) _engine.start();
    if (mounted) {
      setState(
        () => _statusMessage = ok ? 'Engine running' : 'Initialization failed',
      );
    }
  }

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _ecsBatchSize = 12;

    _world.destroyAllEntities();
    _world.clearSystems();
    _engine.rendering.camera.reset();

    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));
    _world.addSystem(_OrbitSystem()..priority = 80);
    _world.addSystem(_PulseSystem()..priority = 75);

    _spawnGrid();

    switch (demo) {
      case _Demo.lifecycle:
        _buildLifecycle();
      case _Demo.timeScale:
        _buildTimeScale();
      case _Demo.ecs:
        _buildEcs();
      case _Demo.subsystems:
        _buildSubsystems();
      case _Demo.gameLoop:
        _buildGameLoop();
    }

    if (mounted) setState(() {});
  }

  void _spawnGrid() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          getBoundsCallback: () => const Rect.fromLTWH(-900, -600, 1800, 1200),
          onRender: (canvas, _) {
            final gridPaint = Paint()
              ..color = const Color(0xFF1A2535)
              ..strokeWidth = 1.0;
            for (double x = -900; x <= 900; x += 80) {
              canvas.drawLine(Offset(x, -600), Offset(x, 600), gridPaint);
            }
            for (double y = -600; y <= 600; y += 80) {
              canvas.drawLine(Offset(-900, y), Offset(900, y), gridPaint);
            }
            final crossPaint = Paint()
              ..color = const Color(0xFF2A3F55)
              ..strokeWidth = 2.0;
            canvas.drawLine(
              const Offset(-30, 0),
              const Offset(30, 0),
              crossPaint,
            );
            canvas.drawLine(
              const Offset(0, -30),
              const Offset(0, 30),
              crossPaint,
            );
          },
        ),
      ),
    ]);
  }

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
                ..color = const Color(0xFF29B6F6).withValues(alpha: 0.6)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            );
          },
        ),
      ),
      _PulseComponent(minScale: 0.96, maxScale: 1.04, speed: 1.4),
    ], name: 'engine-hub');

    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -10)),
      RenderableComponent(
        syncTransform: true,
        renderable: TextRenderable(
          text: 'ENGINE',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
          layer: 12,
        ),
      ),
    ]);

    _statusMessage = 'Use the buttons to drive state transitions';
  }

  void _buildTimeScale() {
    _engine.time.timeScale = 1.0;

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
        TransformComponent(position: Offset.zero),
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

  void _buildEcs() {
    _spawnEcsBatch();
    _statusMessage = 'Spawn and destroy entity batches';
  }

  void _spawnEcsBatch() {
    final rng = math.Random();
    final colors = [
      const Color(0xFF66BB6A),
      const Color(0xFF29B6F6),
      const Color(0xFFAB47BC),
      const Color(0xFFFF7043),
      const Color(0xFFFFCA28),
    ];

    for (int i = 0; i < _ecsBatchSize; i++) {
      final color = colors[rng.nextInt(colors.length)];
      final radius = 50.0 + rng.nextDouble() * 180;
      final speed = (0.3 + rng.nextDouble() * 1.2) * (rng.nextBool() ? 1 : -1);
      final phase = rng.nextDouble() * math.pi * 2;

      _world.createEntityWithComponents([
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
        _SpawnTagComponent(spawnedAt: _engine.time.totalTime),
      ]);
    }
  }

  void _destroyAllEcsEntities() {
    final toRemove = _world.entities
        .where((e) => e.hasComponent<_SpawnTagComponent>())
        .toList();
    for (final e in toRemove) {
      _world.destroyEntity(e);
    }
  }

  void _buildSubsystems() {
    const nodes = [
      ('Rendering', Color(0xFF2A9D8F), 0.0),
      ('Physics', Color(0xFFF4A261), 1.047),
      ('Input', Color(0xFFE76F51), 2.094),
      ('Audio', Color(0xFF90BE6D), 3.142),
      ('AssetMgr', Color(0xFFC77DFF), 4.189),
      ('TimeManager', Color(0xFF29B6F6), 5.236),
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

    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -6)),
      RenderableComponent(
        syncTransform: true,
        renderable: TextRenderable(
          text: 'ENGINE',
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
          layer: 12,
        ),
      ),
    ]);

    for (final (name, color, phase) in nodes) {
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
        _OrbitComponent(radius: 160, speed: 0.55, phase: phase),
      ], name: 'node-${name.toLowerCase()}');

      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          syncTransform: true,
          renderable: TextRenderable(
            text: name,
            textStyle: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            layer: 9,
          ),
        ),
        _OrbitComponent(radius: 160, speed: 0.55, phase: phase),
      ]);
    }

    _statusMessage = 'Each node is a subsystem registered in Engine';
  }

  void _buildGameLoop() {
    for (int i = 0; i < 5; i++) {
      final color = HSLColor.fromAHSL(
        1.0,
        200.0 + i * 28,
        0.75,
        0.55,
      ).toColor();
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 4,
            getBoundsCallback: () =>
                Rect.fromCircle(center: Offset.zero, radius: 60.0 + i * 40),
            onRender: (canvas, _) {
              canvas.drawCircle(
                Offset.zero,
                50.0 + i * 40,
                Paint()
                  ..color = color.withValues(alpha: 0.08)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1,
              );
            },
          ),
        ),
        _PulseComponent(
          minScale: 0.97,
          maxScale: 1.03,
          speed: 0.6 + i * 0.2,
          phase: i * 0.6,
        ),
      ]);

      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 7,
            getBoundsCallback: () =>
                Rect.fromCircle(center: Offset.zero, radius: 10),
            onRender: (canvas, _) {
              canvas.drawCircle(Offset.zero, 5, Paint()..color = color);
            },
          ),
        ),
        _OrbitComponent(
          radius: 50.0 + i * 40,
          speed: 1.0 + i * 0.4,
          phase: i * math.pi * 0.4,
        ),
      ]);
    }

    _statusMessage = 'Frame metrics are live in the header';
  }

  Future<void> _initialize() async {
    await _ensureInitialized();
    setState(() => _statusMessage = 'Initialized');
  }

  void _start() {
    _engine.start();
    setState(() => _statusMessage = 'Engine started');
  }

  void _pause() {
    _engine.pause();
    setState(() => _statusMessage = 'Engine paused');
  }

  void _resume() {
    _engine.resume();
    setState(() => _statusMessage = 'Engine resumed');
  }

  void _stop() {
    _engine.stop();
    setState(() => _statusMessage = 'Engine stopped');
  }

  void _setTimeScale(double v) {
    _engine.time.timeScale = v;
    setState(() => _statusMessage = 'Time scale -> ${v.toStringAsFixed(2)}x');
  }

  String get _statsLine {
    final t = _engine.time;
    return 'state ${_engine.state.name}'
        '  fps ${t.fps.toStringAsFixed(1)}'
        '  dt ${t.deltaTime.toStringAsFixed(4)}'
        '  total ${t.totalTime.toStringAsFixed(2)} s'
        '  frame ${t.frameCount}'
        '  scale ${t.timeScale.toStringAsFixed(2)}x'
        '  entities ${_world.entities.length}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildCanvas()),
        _buildDemoSelector(),
        _buildControlPanel(),
        _buildCodeCard(),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF060D18),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_demo.icon, color: _demo.accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                _demo.label,
                style: TextStyle(
                  color: _demo.accentColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Text(
                'Engine  *  World  *  TimeManager',
                style: TextStyle(color: Color(0xFF29B6F6), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _demo.description,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            _statsLine,
            style: TextStyle(
              color: _demo.accentColor.withValues(alpha: 0.85),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return GameCameraControls(
      camera: _engine.rendering.camera,
      enablePan: true,
      enablePinch: true,
      showZoomLevel: true,
      child: GameWidget(engine: _engine, showFPS: true, showDebug: false),
    );
  }

  Widget _buildDemoSelector() {
    return Container(
      color: const Color(0xFF060D18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF121E2E)),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              itemCount: _Demo.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final d = _Demo.values[i];
                final active = d == _demo;
                return FilterChip(
                  avatar: Icon(
                    d.icon,
                    size: 13,
                    color: active ? d.accentColor : Colors.white38,
                  ),
                  label: Text(
                    d.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: active ? Colors.white : Colors.white54,
                    ),
                  ),
                  selected: active,
                  showCheckmark: false,
                  selectedColor: d.accentColor.withValues(alpha: 0.18),
                  backgroundColor: const Color(0xFF0E1A2A),
                  side: BorderSide(
                    color: active
                        ? d.accentColor.withValues(alpha: 0.7)
                        : const Color(0xFF1E2E40),
                  ),
                  onSelected: (_) => _buildDemo(d),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0xFF060D18),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: _buildDemoControls(),
    );
  }

  Widget _buildDemoControls() {
    switch (_demo) {
      case _Demo.lifecycle:
        return _buildLifecycleControls();
      case _Demo.timeScale:
        return _buildTimeScaleControls();
      case _Demo.ecs:
        return _buildEcsControls();
      case _Demo.subsystems:
        return _buildSubsystemsControls();
      case _Demo.gameLoop:
        return _buildGameLoopControls();
    }
  }

  Widget _buildLifecycleControls() {
    final state = _engine.state;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _actionButton(
          'Initialize',
          const Color(0xFF29B6F6),
          state == EngineState.uninitialized ? _initialize : null,
        ),
        _actionButton(
          'Start',
          const Color(0xFF66BB6A),
          state == EngineState.initialized ? _start : null,
        ),
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
        const SizedBox(width: 4),
        Text(
          '-> ${state.name}',
          style: TextStyle(
            color: _demo.accentColor,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
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
    final liveCount = _world.entities
        .where((e) => e.hasComponent<_SpawnTagComponent>())
        .length;
    return Row(
      children: [
        const Text(
          'Batch:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 6),
        _actionButton('+8', const Color(0xFF66BB6A), () {
          _ecsBatchSize = 8;
          _spawnEcsBatch();
        }),
        const SizedBox(width: 4),
        _actionButton('+16', const Color(0xFF66BB6A), () {
          _ecsBatchSize = 16;
          _spawnEcsBatch();
        }),
        const SizedBox(width: 4),
        _actionButton('+32', const Color(0xFF66BB6A), () {
          _ecsBatchSize = 32;
          _spawnEcsBatch();
        }),
        const SizedBox(width: 8),
        _actionButton(
          'Destroy All',
          const Color(0xFFFF5252),
          liveCount > 0 ? _destroyAllEcsEntities : null,
        ),
        const SizedBox(width: 12),
        Text(
          'live: $liveCount entities',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildSubsystemsControls() {
    final items = [
      ('Rendering', _engine.getSystem<RenderingEngine>() != null),
      ('Physics', _engine.getSystem<PhysicsEngine>() != null),
      ('Input', _engine.getSystem<InputManager>() != null),
      ('Audio', _engine.getSystem<AudioEngine>() != null),
      ('Assets', _engine.getSystem<AssetManager>() != null),
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Ticker-driven loop  *  world.update(dt) each frame  *  stats update live in the header',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF111C2A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: onTap != null
                ? color.withValues(alpha: 0.55)
                : const Color(0xFF1A2535),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap != null ? Colors.white : Colors.white30,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCodeCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF090F1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _demo.accentColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(_demo.icon, size: 13, color: _demo.accentColor),
                const SizedBox(width: 6),
                Text(
                  _demo.label,
                  style: TextStyle(
                    color: _demo.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'just_game_engine  Engine API',
                  style: TextStyle(color: Colors.white24, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              width: double.infinity,
              child: SingleChildScrollView(
                child: Text(
                  _demo.codeSnippet,
                  style: const TextStyle(
                    color: Color(0xFFB0C8E0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

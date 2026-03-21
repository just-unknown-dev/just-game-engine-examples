import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

class CoreEngineScreen extends StatefulWidget {
  const CoreEngineScreen({super.key});

  @override
  State<CoreEngineScreen> createState() => _CoreEngineScreenState();
}

class _CoreEngineScreenState extends State<CoreEngineScreen> {
  late final Engine _engine;
  late final World _world;
  final GlobalKey _gameWidgetKey = GlobalKey();

  Size _viewportSize = Size.zero;

  String _status = 'Preparing core showcase...';

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndSetup();
    });
  }

  Future<void> _initializeAndSetup() async {
    if (_engine.state == EngineState.uninitialized) {
      final ok = await _engine.initialize();
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _status = 'Engine initialization failed';
        });
        return;
      }
    }

    _setupCoreShowcase();
    _engine.start();

    if (!mounted) return;
    setState(() {
      _status = 'Core systems running';
    });
  }

  @override
  void dispose() {
    _engine.stop();
    super.dispose();
  }

  Size _readViewportSize() {
    final renderObject = _gameWidgetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return MediaQuery.sizeOf(context);
  }

  void _clearWorldSystemsAndEntities() {
    final existingSystems = List<System>.from(_world.systems);
    for (final system in existingSystems) {
      _world.removeSystem(system);
    }

    _world.destroyAllEntities();
  }

  void _setupCoreShowcase() {
    _viewportSize = _readViewportSize();
    if (_viewportSize != Size.zero) {
      _engine.rendering.camera.viewportSize = _viewportSize;
    }
    _engine.rendering.camera.position = Offset.zero;
    _engine.rendering.camera.rotation = 0;
    _engine.rendering.camera.zoom = 1;

    _clearWorldSystemsAndEntities();

    _world.addSystem(_CoreOrbitSystem()..priority = 90);
    _world.addSystem(_CorePulseSystem()..priority = 85);
    _world.addSystem(_CoreEngineStatsSystem(_engine)..priority = 75);
    _world.addSystem(_CameraAwareRenderSystem(_engine.rendering.camera));

    _createBackdrop();
    _createCoreHub();
    _createSubsystemNodes();
    _createStatusTexts();
  }

  void _createBackdrop() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -40,
          onRender: (canvas, size) {
            final gridPaint = Paint()
              ..color = const Color(0xFF1A2E40).withValues(alpha: 0.35)
              ..strokeWidth = 1;

            for (double x = -900; x <= 900; x += 70) {
              canvas.drawLine(Offset(x, -700), Offset(x, 700), gridPaint);
            }
            for (double y = -700; y <= 700; y += 70) {
              canvas.drawLine(Offset(-900, y), Offset(900, y), gridPaint);
            }

            final ringPaint = Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0xFF7FE3FF).withValues(alpha: 0.18)
              ..strokeWidth = 2;

            canvas.drawCircle(Offset.zero, 110, ringPaint);
            canvas.drawCircle(Offset.zero, 210, ringPaint);
            canvas.drawCircle(Offset.zero, 320, ringPaint);
          },
        ),
      ),
    ], name: 'core-backdrop');
  }

  void _createCoreHub() {
    _world.createEntityWithComponents([
      TransformComponent(position: Offset.zero, scale: 1),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: 62,
          fillColor: const Color(0xFF1D3557).withValues(alpha: 0.88),
          strokeColor: const Color(0xFF7FE3FF),
          strokeWidth: 4,
          layer: 10,
        ),
      ),
      _CorePulseComponent(minScale: 0.92, maxScale: 1.08, speed: 1.9),
    ], name: 'core-hub');

    _spawnText(
      'ENGINE',
      const Offset(0, -8),
      const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
      layer: 20,
    );

    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, 18)),
      _EngineStatsTextComponent(kind: _StatsKind.state),
      RenderableComponent(
        syncTransform: true,
        renderable: TextRenderable(
          text: '',
          textStyle: const TextStyle(
            color: Color(0xFF9ED5FF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          layer: 20,
        ),
      ),
    ], name: 'engine-state-text');
  }

  void _createSubsystemNodes() {
    final nodes =
        <
          ({
            String name,
            Color color,
            double radius,
            double speed,
            double phase,
          })
        >[
          (
            name: 'Rendering',
            color: const Color(0xFF2A9D8F),
            radius: 170,
            speed: 0.62,
            phase: 0,
          ),
          (
            name: 'Physics',
            color: const Color(0xFFF4A261),
            radius: 170,
            speed: 0.62,
            phase: math.pi / 3,
          ),
          (
            name: 'Input',
            color: const Color(0xFFE76F51),
            radius: 170,
            speed: 0.62,
            phase: 2 * math.pi / 3,
          ),
          (
            name: 'Audio',
            color: const Color(0xFF90BE6D),
            radius: 170,
            speed: 0.62,
            phase: math.pi,
          ),
          (
            name: 'Animation',
            color: const Color(0xFF577590),
            radius: 170,
            speed: 0.62,
            phase: 4 * math.pi / 3,
          ),
          (
            name: 'Assets',
            color: const Color(0xFFC77DFF),
            radius: 170,
            speed: 0.62,
            phase: 5 * math.pi / 3,
          ),
        ];

    for (final node in nodes) {
      _world.createEntityWithComponents([
        TransformComponent(position: Offset.zero),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: 28,
            fillColor: node.color.withValues(alpha: 0.9),
            strokeColor: Colors.white.withValues(alpha: 0.7),
            strokeWidth: 2,
            layer: 9,
          ),
        ),
        _CoreOrbitComponent(
          radius: node.radius,
          speed: node.speed,
          phase: node.phase,
        ),
      ], name: 'node-${node.name.toLowerCase()}');

      _world.createEntityWithComponents([
        TransformComponent(position: Offset.zero),
        _FollowEntityNameComponent(
          targetName: 'node-${node.name.toLowerCase()}',
        ),
        RenderableComponent(
          syncTransform: true,
          renderable: TextRenderable(
            text: node.name,
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            layer: 21,
          ),
        ),
      ], name: 'label-${node.name.toLowerCase()}');
    }
  }

  void _createStatusTexts() {
    _world.createEntityWithComponents([
      _EngineStatsTextComponent(kind: _StatsKind.time),
      TransformComponent(position: const Offset(0, -200)),
      RenderableComponent(
        syncTransform: true,
        renderable: TextRenderable(
          text: '',
          textStyle: const TextStyle(
            color: Color(0xFF9DD9D2),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          layer: 31,
        ),
      ),
    ], name: 'time-stats-text');

    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -100)),
      _EngineStatsTextComponent(kind: _StatsKind.systems),
      RenderableComponent(
        syncTransform: true,
        renderable: TextRenderable(
          text: '',
          textStyle: const TextStyle(color: Color(0xFFADC4D4), fontSize: 12),
          layer: 31,
        ),
      ),
    ], name: 'systems-stats-text');
  }

  void _spawnText(
    String text,
    Offset position,
    TextStyle style, {
    required int layer,
  }) {
    _world.createEntityWithComponents([
      TransformComponent(position: position),
      RenderableComponent(
        renderable: TextRenderable(text: text, textStyle: style, layer: layer),
      ),
    ]);
  }

  void _setTimeScale(double value) {
    _engine.time.timeScale = value;
    setState(() {
      _status = 'Time scale set to ${value.toStringAsFixed(2)}x';
    });
  }

  Future<void> _initializeIfNeeded() async {
    if (_engine.state == EngineState.uninitialized) {
      final ok = await _engine.initialize();
      setState(() {
        _status = ok ? 'Engine initialized' : 'Initialization failed';
      });
    }
  }

  void _startEngine() {
    _engine.start();
    setState(() {
      _status = 'Engine running';
    });
  }

  void _pauseEngine() {
    _engine.pause();
    setState(() {
      _status = 'Engine paused';
    });
  }

  void _resumeEngine() {
    _engine.resume();
    setState(() {
      _status = 'Engine resumed';
    });
  }

  void _stopEngine() {
    _engine.stop();
    setState(() {
      _status = 'Engine stopped';
    });
  }

  @override
  Widget build(BuildContext context) {
    final rendering = _engine.getSystem<RenderingEngine>() != null;
    final physics = _engine.getSystem<PhysicsEngine>() != null;
    final input = _engine.getSystem<InputManager>() != null;
    final audio = _engine.getSystem<AudioEngine>() != null;
    final assets = _engine.getSystem<AssetManager>() != null;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: const Color(0xFF101925),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Core Engine Control Center',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'State: ${_engine.state.name}   |   Status: $_status',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _initializeIfNeeded,
                    child: const Text('Initialize'),
                  ),
                  FilledButton(
                    onPressed: _startEngine,
                    child: const Text('Start'),
                  ),
                  FilledButton(
                    onPressed: _pauseEngine,
                    child: const Text('Pause'),
                  ),
                  FilledButton(
                    onPressed: _resumeEngine,
                    child: const Text('Resume'),
                  ),
                  FilledButton(
                    onPressed: _stopEngine,
                    child: const Text('Stop'),
                  ),
                  FilledButton.icon(
                    onPressed: _setupCoreShowcase,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Scene'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Time Scale',
                    style: TextStyle(color: Colors.white),
                  ),
                  Expanded(
                    child: Slider(
                      value: _engine.time.timeScale.clamp(0, 2),
                      min: 0,
                      max: 2,
                      divisions: 20,
                      label: _engine.time.timeScale.toStringAsFixed(2),
                      onChanged: _setTimeScale,
                    ),
                  ),
                  Text(
                    '${_engine.time.timeScale.toStringAsFixed(2)}x',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Subsystems: Rendering ${rendering ? 'OK' : 'NA'} | Physics ${physics ? 'OK' : 'NA'} | Input ${input ? 'OK' : 'NA'} | Audio ${audio ? 'OK' : 'NA'} | Assets ${assets ? 'OK' : 'NA'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: CameraZoomControls(
            camera: _engine.rendering.camera,
            child: GameWidget(
              key: _gameWidgetKey,
              engine: _engine,
              showFPS: true,
              showDebug: true,
            ),
          ),
        ),
      ],
    );
  }
}

enum _StatsKind { state, time, systems }

class _CoreOrbitComponent extends Component {
  _CoreOrbitComponent({
    required this.radius,
    required this.speed,
    required this.phase,
  }) : angle = phase;

  final double radius;
  final double speed;
  final double phase;
  double angle;
}

class _CorePulseComponent extends Component {
  _CorePulseComponent({
    required this.minScale,
    required this.maxScale,
    required this.speed,
  });

  final double minScale;
  final double maxScale;
  final double speed;
  double time = 0;
}

class _FollowEntityNameComponent extends Component {
  _FollowEntityNameComponent({required this.targetName});
  final String targetName;
}

class _EngineStatsTextComponent extends Component {
  _EngineStatsTextComponent({required this.kind});
  final _StatsKind kind;
}

class _CoreOrbitSystem extends System {
  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    _CoreOrbitComponent,
  ];

  @override
  void update(double dt) {
    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final orbit = entity.getComponent<_CoreOrbitComponent>()!;

      orbit.angle += orbit.speed * dt;
      transform.position = Offset(
        math.cos(orbit.angle) * orbit.radius,
        math.sin(orbit.angle) * orbit.radius,
      );
    });
  }
}

class _CorePulseSystem extends System {
  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    _CorePulseComponent,
  ];

  @override
  void update(double dt) {
    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final pulse = entity.getComponent<_CorePulseComponent>()!;

      pulse.time += dt;
      final wave = (math.sin(pulse.time * pulse.speed) + 1) / 2;
      transform.scale =
          pulse.minScale + (pulse.maxScale - pulse.minScale) * wave;
    });
  }
}

class _CoreEngineStatsSystem extends System {
  _CoreEngineStatsSystem(this.engine);

  final Engine engine;

  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    RenderableComponent,
    _EngineStatsTextComponent,
  ];

  @override
  void update(double dt) {
    final totalEntities = world.entities.length;
    final totalSystems = world.systems.length;

    forEach((entity) {
      final statsKind = entity.getComponent<_EngineStatsTextComponent>()!.kind;
      final renderComp = entity.getComponent<RenderableComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;
      final text = renderComp.renderable as TextRenderable;

      switch (statsKind) {
        case _StatsKind.state:
          text.text = engine.state.name.toUpperCase();
          break;
        case _StatsKind.time:
          text.text =
              'Time ${engine.time.totalTime.toStringAsFixed(2)}s | dt ${engine.time.deltaTime.toStringAsFixed(4)} | fps ${engine.time.fps.toStringAsFixed(1)} | frame ${engine.time.frameCount}';
          break;
        case _StatsKind.systems:
          text.text =
              'World entities $totalEntities | World systems $totalSystems';
          break;
      }

      final follow = entity.getComponent<_FollowEntityNameComponent>();
      if (follow != null) {
        final target = world.findEntityByName(follow.targetName);
        if (target != null) {
          final targetTransform = target.getComponent<TransformComponent>();
          if (targetTransform != null) {
            transform.position = targetTransform.position + const Offset(0, 40);
          }
        }
      }
    });
  }
}

class _CameraAwareRenderSystem extends System {
  _CameraAwareRenderSystem(this.camera);

  final Camera camera;

  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    RenderableComponent,
  ];

  @override
  void render(Canvas canvas, Size size) {
    camera.viewportSize = size;
    canvas.save();
    camera.applyTransform(canvas, size);

    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final renderComp = entity.getComponent<RenderableComponent>()!;

      if (renderComp.syncTransform) {
        renderComp.renderable.position = transform.position;
        renderComp.renderable.rotation = transform.rotation;
        renderComp.renderable.scale = transform.scale;
      }

      if (renderComp.renderable.visible) {
        renderComp.renderable.render(canvas, size);
      }
    });

    canvas.restore();
  }
}

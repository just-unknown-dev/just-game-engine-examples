import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine_editor/just_game_engine_editor.dart';

class _DriftComponent extends Component {
  _DriftComponent({
    required this.origin,
    required this.radius,
    required this.speed,
    this.phase = 0,
  }) : angle = phase;

  final Offset origin;
  final double radius;
  final double speed;
  final double phase;
  double angle;
}

class _DriftSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _DriftComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final d = entity.getComponent<_DriftComponent>()!;
      d.angle += d.speed * dt;
      t.position = Vector3.fromOffset(
        Offset(
          d.origin.dx + math.cos(d.angle) * d.radius,
          d.origin.dy + math.sin(d.angle) * d.radius,
        ),
      );
      t.rotation += 0.25 * dt;
    });
  }
}

class EditorOverlayScreen extends StatefulWidget {
  const EditorOverlayScreen({super.key});

  @override
  State<EditorOverlayScreen> createState() => _EditorOverlayScreenState();
}

class _EditorOverlayScreenState extends State<EditorOverlayScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;
  JustGameEditorPlugin? _plugin;
  bool _pluginInitInFlight = true;
  String _status = 'Preparing runtime editor plugin...';

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    _initializeEngine();
  }

  Future<void> _initializeEngine() async {
    // Initialize the engine first
    await _engine.initialize();
    
    // Configure systems (before starting)
    _configureWorldSystems();
    _spawnBackdrop();
    
    // Register the editor plugin after initialization
    _initPlugin();
  }

  Future<void> _initPlugin() async {
    final plugin = await JustGameEditorPlugin.register(engine: _engine);
    if (!mounted) return;

    setState(() {
      _plugin = plugin;
      _pluginInitInFlight = false;
      if (plugin == null) {
        _status =
            'Plugin disabled in release mode. Run debug/profile for overlay.';
      } else {
        _status = 'New blank scene. Use editor to create entities.';
      }
    });

    if (plugin != null) {
      plugin.addListener(_onPluginChanged);
    }
  }

  void _onPluginChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _plugin?.removeListener(_onPluginChanged);
    _plugin?.dispose();
    _ticker.dispose();
    _world.destroyAllEntities();
    _world.clearSystems();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1_000_000.0;
    _lastTick = elapsed;
    _world.update(dt);
    if (mounted) setState(() {});
  }

  void _configureWorldSystems() {
    _world.clearSystems();
    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));
    _world.addSystem(MovementSystem());
    _world.addSystem(_DriftSystem()..priority = 80);
  }

  void _spawnBackdrop() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          getBoundsCallback: () => const Rect.fromLTWH(-1000, -700, 2000, 1400),
          onRender: (canvas, _) {
            final gridPaint = Paint()
              ..color = const Color(0xFF1A2535)
              ..strokeWidth = 1;
            for (double x = -1000; x <= 1000; x += 80) {
              canvas.drawLine(Offset(x, -700), Offset(x, 700), gridPaint);
            }
            for (double y = -700; y <= 700; y += 80) {
              canvas.drawLine(Offset(-1000, y), Offset(1000, y), gridPaint);
            }
            canvas.drawCircle(
              Offset.zero,
              220,
              Paint()
                ..color = const Color(0xFF143B52).withValues(alpha: 0.12)
                ..style = PaintingStyle.fill,
            );
          },
        ),
      ),
    ]);
  }

  String get _statsLine {
    final camera = _engine.rendering.camera;
    final p = camera.position;
    final selectedId = _plugin?.sceneState.selectedEntity?.id;
    return 'cam (${p.dx.toStringAsFixed(0)}, ${p.dy.toStringAsFixed(0)})'
        ' zoom ${camera.zoom.toStringAsFixed(2)}'
        ' selected ${selectedId ?? '-'}';
  }

  @override
  Widget build(BuildContext context) {
    final plugin = _plugin;
    final isPluginAvailable = plugin != null;
    final isVisible = plugin?.isVisible ?? false;

    return Column(
      children: [
        _buildHeader(isPluginAvailable, isVisible),
        Expanded(child: _buildCanvas(plugin)),
      ],
    );
  }

  Widget _buildHeader(bool isPluginAvailable, bool isVisible) {
    return Container(
      color: const Color(0xFF060D18),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 18,
                color: Color(0xFF4DD0E1),
              ),
              const SizedBox(width: 8),
              const Text(
                'Just Game Engine Editor Overlay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPluginAvailable
                      ? const Color(0xFF102637)
                      : const Color(0xFF3A1E1E),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isPluginAvailable
                        ? const Color(0xFF4DD0E1)
                        : const Color(0xFFFF7043),
                  ),
                ),
                child: Text(
                  _pluginInitInFlight
                      ? 'INITIALIZING'
                      : (isVisible ? 'EDITOR OPEN' : 'EDITOR CLOSED'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Runtime level editor overlay on top of GameWidget with scene tree, inspector, gizmos, and save pipeline.',
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            _statsLine,
            style: const TextStyle(
              color: Color(0xFF4DD0E1),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _status,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvas(JustGameEditorPlugin? plugin) {
    if (!kDebugMode) {
      return const Center(
        child: Text(
          'Editor overlay is debug-only. Run in debug to interact with the plugin.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return GameEditorAdapter(
      engine: _engine,
      plugin: plugin,
      showFPS: true,
      showDebug: false,
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/widgets.dart';

import '../../core/engine/demo_engine.dart';
import '../../core/engine/silent_audio_backend.dart';

part 'core_demos.dart';
part 'rendering_demos.dart';

// -----------------------------------------------------------------------------
// Demo modes
// -----------------------------------------------------------------------------

/// The two halves of the screen, each with its own row of chips.
enum _Group {
  core(
    'CORE',
    'Engine  *  EngineState  *  World  *  TimeManager',
    'Engine API',
  ),
  rendering(
    'RENDERING',
    'RenderSystem  *  LayerComponent  *  RenderingEngine.stats',
    'Rendering API',
  );

  const _Group(this.label, this.headline, this.apiName);

  final String label;

  /// The classes the group is about, in the header.
  final String headline;

  /// What the code card shows the API of.
  final String apiName;
}

enum _Demo {
  // Core
  lifecycle(
    _Group.core,
    'Lifecycle',
    Icons.play_circle_outline,
    Color(0xFF29B6F6),
  ),
  timeScale(_Group.core, 'Time Scale', Icons.speed, Color(0xFFFFCA28)),
  ecs(_Group.core, 'ECS', Icons.grid_on, Color(0xFF66BB6A)),
  subsystems(_Group.core, 'Subsystems', Icons.device_hub, Color(0xFFAB47BC)),
  gameLoop(_Group.core, 'Game Loop', Icons.refresh, Color(0xFFFF7043)),

  // Rendering
  primitives(_Group.rendering, 'Primitives', Icons.category, Color(0xFF29B6F6)),
  layers(_Group.rendering, 'Layers & Z-Order', Icons.layers, Color(0xFFFFCA28)),
  particles(_Group.rendering, 'Particles', Icons.blur_on, Color(0xFFFF7043)),
  hierarchy(
    _Group.rendering,
    'Hierarchy',
    Icons.account_tree,
    Color(0xFFAB47BC),
  ),
  custom(_Group.rendering, 'Custom Draw', Icons.draw, Color(0xFF66BB6A)),
  culling(
    _Group.rendering,
    'Culling & Stats',
    Icons.filter_center_focus,
    Color(0xFF26C6DA),
  );

  const _Demo(this.group, this.label, this.icon, this.accentColor);

  final _Group group;
  final String label;
  final IconData icon;
  final Color accentColor;

  String get description => switch (group) {
    _Group.core => _coreDescriptions[this]!,
    _Group.rendering => _renderingDescriptions[this]!,
  };

  String get codeSnippet => switch (group) {
    _Group.core => _coreSnippets[this]!,
    _Group.rendering => _renderingSnippets[this]!,
  };
}

// -----------------------------------------------------------------------------
// Shared ECS helper
// -----------------------------------------------------------------------------

/// Breathes an entity's scale between [minScale] and [maxScale].
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
      final s = p.minScale + (p.maxScale - p.minScale) * wave;
      t.scale.setValues(s, s, 1.0);
    });
  }
}

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

/// The engine itself — lifecycle, time, ECS, subsystems, the game loop —
/// and how it draws: primitives, layers, particles, the hierarchy, custom
/// drawing and culling. The demos live in `core_demos.dart` and
/// `rendering_demos.dart`.
class CoreRenderingScreen extends StatefulWidget {
  const CoreRenderingScreen({super.key});

  @override
  State<CoreRenderingScreen> createState() => _CoreRenderingScreenState();
}

class _CoreRenderingScreenState extends State<CoreRenderingScreen>
    with SingleTickerProviderStateMixin {
  /// The app's shared, already initialized and running engine — never
  /// `Engine()`.
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;

  /// Refreshes the live stats only; the engine runs itself.
  late final Ticker _ticker;
  Duration _lastRefresh = Duration.zero;

  _Demo _demo = _Demo.lifecycle;
  String _statusMessage = '';

  // ── Core ────────────────────────────────────────────────────────────────

  // Lifecycle: the shared engine's transitions, heard on stateListenable.
  final List<String> _transitions = [];
  EngineState _lastState = EngineState.running;

  // Lifecycle: the throwaway engine's story.
  final List<String> _sandboxLog = [];
  bool _sandboxBusy = false;

  // ECS.
  int _lastId = -1;
  int _destroyed = 0;
  _SeekComponent? _seek;

  // Subsystems.
  _HudPlugin? _plugin;

  // Game loop.
  _LaneSystem? _lanes;
  Duration _rateSince = Duration.zero;
  int _rateFixed = 0;
  int _rateFrames = 0;
  double _fixedRate = 0;
  double _frameRate = 0;

  // ── Rendering ───────────────────────────────────────────────────────────

  // Layers: the components re-layered by the buttons.
  final List<LayerComponent> _frontLayers = [];
  final List<LayerComponent> _zLayers = [];

  // Hierarchy: the three roots.
  final List<Entity> _roots = [];

  // Culling switches.
  bool _cullOffscreen = true;
  bool _batchShapes = false;

  int _burstCount = 0;

  @override
  void initState() {
    super.initState();
    _lastState = _engine.state;
    _engine.stateListenable.addListener(_onEngineState);
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buildDemo(_demo);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.stateListenable.removeListener(_onEngineState);
    _removePlugin();
    // Clean world, time scale 1, and running again if a demo paused or
    // stopped it.
    DemoEngine.reset(_engine);
    super.dispose();
  }

  /// `setState` for the demo code in the part files (extensions may not
  /// call the protected member themselves).
  void _refresh(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _onEngineState() {
    final now = _engine.state;
    if (now == _lastState) return;
    _transitions.add('${_lastState.name} → ${now.name}');
    if (_transitions.length > 6) _transitions.removeAt(0);
    _lastState = now;
    if (mounted) setState(() {});
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastRefresh < const Duration(milliseconds: 100)) return;
    _lastRefresh = elapsed;
    final lanes = _lanes;
    if (lanes != null && elapsed - _rateSince >= const Duration(seconds: 1)) {
      final seconds = (elapsed - _rateSince).inMicroseconds / 1e6;
      _fixedRate = (lanes.fixedSteps - _rateFixed) / seconds;
      _frameRate = (lanes.frames - _rateFrames) / seconds;
      _rateFixed = lanes.fixedSteps;
      _rateFrames = lanes.frames;
      _rateSince = elapsed;
    }
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------------
  // Demo construction
  // -------------------------------------------------------------------------

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _seek = null;
    _lanes = null;
    _removePlugin();
    _frontLayers.clear();
    _zLayers.clear();
    _roots.clear();

    // A clean world with the engine's standard RenderSystem (wired to
    // engine.rendering's stats); resumes or restarts the engine if the
    // lifecycle demo left it paused or stopped, and puts the time scale
    // back to 1.
    DemoEngine.reset(_engine, include: {DefaultSystem.rendering});

    switch (demo.group) {
      case _Group.core:
        _world
          ..addSystem(_OrbitSystem()..priority = 80)
          ..addSystem(_PulseSystem()..priority = 75);
      case _Group.rendering:
        _world
          ..addSystem(_SpinSystem()..priority = 85)
          ..addSystem(_FloatSystem()..priority = 82)
          ..addSystem(_PulseSystem()..priority = 80)
          // Above SystemPriorities.hierarchy (50): the hierarchy places the
          // children after this moves them.
          ..addSystem(_OrbitChildSystem()..priority = 75);
    }

    if (demo != _Demo.culling) _spawnGrid();

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
      case _Demo.primitives:
        _buildPrimitives();
      case _Demo.layers:
        _buildLayers();
      case _Demo.particles:
        _buildParticles();
      case _Demo.hierarchy:
        _buildHierarchy();
      case _Demo.custom:
        _buildCustom();
      case _Demo.culling:
        _buildCulling();
    }

    if (mounted) setState(() {});
  }

  void _removePlugin() {
    if (_plugin == null) return;
    _plugin = null;
    _engine.plugins.unregister(_HudPlugin.pluginId);
  }

  // -------------------------------------------------------------------------
  // Shared background grid
  // -------------------------------------------------------------------------

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
    ], name: 'Grid');
  }

  String get _statsLine => switch (_demo.group) {
    _Group.core => _coreStatsLine,
    _Group.rendering => _renderingStatsLine,
  };

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

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
              Flexible(
                child: Text(
                  _demo.group.headline,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF29B6F6),
                    fontSize: 10,
                  ),
                ),
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
      camera: _engine.cameraSystem.mainCamera,
      enablePan: true,
      enablePinch: true,
      showZoomLevel: true,
      child: GameWidget(
        engine: _engine,
        showFPS: true,
        showDebug: true,
        // A Flutter HUD above the game, below the FPS counter.
        overlay: _buildOverlay(),
      ),
    );
  }

  /// One row of chips per group, each labelled, so every demo is in view.
  Widget _buildDemoSelector() {
    return Container(
      color: const Color(0xFF060D18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF121E2E)),
          const SizedBox(height: 4),
          for (final group in _Group.values) _groupRow(group),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _groupRow(_Group group) {
    final demos = _Demo.values.where((d) => d.group == group).toList();
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                group.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: _demo.group == group ? Colors.white70 : Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 12, top: 3, bottom: 3),
              itemCount: demos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _demoChip(demos[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _demoChip(_Demo d) {
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
      case _Demo.primitives:
      case _Demo.custom:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Drag to pan  *  Scroll / pinch to zoom  *  Animated by ECS systems',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        );
      case _Demo.layers:
        return _buildLayersControls();
      case _Demo.particles:
        return _buildParticleControls();
      case _Demo.hierarchy:
        return _buildHierarchyControls();
      case _Demo.culling:
        return _buildCullingControls();
    }
  }

  Widget _actionButton(
    String label,
    Color color,
    VoidCallback? onTap, {
    bool selected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xFF111C2A)
              : color.withValues(alpha: selected ? 0.3 : 0.15),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: onTap != null
                ? color.withValues(alpha: selected ? 0.9 : 0.55)
                : const Color(0xFF1A2535),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap != null ? Colors.white : Colors.white30,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
                Text(
                  'just_game_engine 2.x  ${_demo.group.apiName}',
                  style: const TextStyle(color: Colors.white24, fontSize: 9),
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

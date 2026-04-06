import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Effect model
// ─────────────────────────────────────────────────────────────────────────────

enum _EffectType {
  vignette,
  bloom,
  scanlines,
  chromaticAberration,
  colorGrade;

  String get label => switch (this) {
    vignette => 'Vignette',
    bloom => 'Bloom',
    scanlines => 'Scanlines',
    chromaticAberration => 'Chromatic',
    colorGrade => 'Color Grade',
  };

  IconData get icon => switch (this) {
    vignette => Icons.vignette,
    bloom => Icons.flare,
    scanlines => Icons.format_list_bulleted,
    chromaticAberration => Icons.blur_on,
    colorGrade => Icons.palette,
  };

  Color get accentColor => switch (this) {
    vignette => const Color(0xFF9C27B0),
    bloom => const Color(0xFFFFEB3B),
    scanlines => const Color(0xFF4CAF50),
    chromaticAberration => const Color(0xFF00BCD4),
    colorGrade => const Color(0xFFFF5722),
  };

  int get passOrder => switch (this) {
    bloom => 0,
    chromaticAberration => 1,
    vignette => 2,
    scanlines => 3,
    colorGrade => 4,
  };

  String get codeSnippet => switch (this) {
    vignette =>
      'ShaderComponent(\n'
          '  program: vignetteProgram,\n'
          '  isPostProcess: true,\n'
          '  passOrder: $passOrder,\n'
          '  setUniforms: (shader, w, h, t) {\n'
          '    shader.setFloat(0, w); // uResolution.x\n'
          '    shader.setFloat(1, h); // uResolution.y\n'
          '  },\n'
          ')',
    bloom =>
      'ShaderComponent(\n'
          '  program: bloomProgram,\n'
          '  isPostProcess: true,\n'
          '  passOrder: $passOrder, // innermost\n'
          '  setUniforms: (shader, w, h, t) {\n'
          '    shader.setFloat(0, w);\n'
          '    shader.setFloat(1, h);\n'
          '    shader.setFloat(2, t); // uTime (animated)\n'
          '  },\n'
          ')',
    scanlines =>
      'ShaderComponent(\n'
          '  program: scanlinesProgram,\n'
          '  isPostProcess: true,\n'
          '  passOrder: $passOrder,\n'
          '  setUniforms: (shader, w, h, t) {\n'
          '    shader.setFloat(0, t); // uTime (scrolling)\n'
          '  },\n'
          ')',
    chromaticAberration =>
      'ShaderComponent(\n'
          '  program: chromaticProgram,\n'
          '  isPostProcess: true,\n'
          '  passOrder: $passOrder,\n'
          '  setUniforms: (shader, w, h, t) {\n'
          '    shader.setFloat(0, w);\n'
          '    shader.setFloat(1, h);\n'
          '    shader.setFloat(2, 0.004); // aberration strength\n'
          '  },\n'
          ')',
    colorGrade =>
      'ShaderComponent(\n'
          '  program: colorGradeProgram,\n'
          '  isPostProcess: true,\n'
          '  passOrder: $passOrder, // outermost\n'
          '  setUniforms: (shader, w, h, t) {\n'
          '    shader.setFloat(0, 0.12); // tint intensity\n'
          '  },\n'
          ')',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Scene ECS components
// ─────────────────────────────────────────────────────────────────────────────

class _PulseComponent extends Component {
  final double minScale;
  final double maxScale;
  final double speed;
  final double phase;
  double time = 0;

  _PulseComponent({
    required this.minScale,
    required this.maxScale,
    required this.speed,
    this.phase = 0,
  });
}

class _OrbitComponent extends Component {
  final Offset center;
  final double radius;
  final double speed;
  double angle;

  _OrbitComponent({
    required this.center,
    required this.radius,
    required this.speed,
    double startAngle = 0,
  }) : angle = startAngle;
}

class _DriftComponent extends Component {
  final Offset origin;
  final double rangeX;
  final double rangeY;
  final double speed;
  final double phaseX;
  final double phaseY;
  double time = 0;

  _DriftComponent({
    required this.origin,
    required this.rangeX,
    required this.rangeY,
    required this.speed,
    required this.phaseX,
    required this.phaseY,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Scene ECS systems
// ─────────────────────────────────────────────────────────────────────────────

class _PulseSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _PulseComponent];

  @override
  void update(double deltaTime) {
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final p = entity.getComponent<_PulseComponent>()!;
      p.time += deltaTime;
      final t = entity.getComponent<TransformComponent>()!;
      t.scale =
          p.minScale +
          (p.maxScale - p.minScale) *
              (0.5 + 0.5 * math.sin(p.time * p.speed + p.phase));
    }
  }
}

class _OrbitSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _OrbitComponent];

  @override
  void update(double deltaTime) {
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final o = entity.getComponent<_OrbitComponent>()!;
      o.angle += deltaTime * o.speed;
      final t = entity.getComponent<TransformComponent>()!;
      t.position = Offset(
        o.center.dx + math.cos(o.angle) * o.radius,
        o.center.dy + math.sin(o.angle) * o.radius,
      );
    }
  }
}

class _DriftSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _DriftComponent];

  @override
  void update(double deltaTime) {
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final d = entity.getComponent<_DriftComponent>()!;
      d.time += deltaTime;
      final t = entity.getComponent<TransformComponent>()!;
      t.position = Offset(
        d.origin.dx + math.sin(d.time * d.speed + d.phaseX) * d.rangeX,
        d.origin.dy + math.cos(d.time * d.speed * 0.7 + d.phaseY) * d.rangeY,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simulated post-process overlay painter
// Mirrors what ShaderComponent + PostProcessPass does via canvas.saveLayer.
// ─────────────────────────────────────────────────────────────────────────────

class _EffectOverlayPainter extends CustomPainter {
  final Set<_EffectType> activeEffects;
  final double time;

  const _EffectOverlayPainter({
    required this.activeEffects,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Passes applied innermost → outermost (ascending passOrder).
    final sorted = activeEffects.toList()
      ..sort((a, b) => a.passOrder.compareTo(b.passOrder));

    for (final effect in sorted) {
      switch (effect) {
        case _EffectType.bloom:
          final p = Paint()
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
            ..color = const Color(0xFF5FD1FF).withValues(alpha: 0.13)
            ..blendMode = BlendMode.plus;
          canvas.drawRect(rect, p);

        case _EffectType.chromaticAberration:
          final cx = size.width / 2;
          final cy = size.height / 2;
          final rPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFFFF0000).withValues(alpha: 0.09);
          final bPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFF0000FF).withValues(alpha: 0.09);
          for (
            double r = 80;
            r <= math.min(size.width, size.height) * 0.72;
            r += 56
          ) {
            canvas.drawCircle(Offset(cx - 2.5, cy), r, rPaint);
            canvas.drawCircle(Offset(cx + 2.5, cy), r, bPaint);
          }

        case _EffectType.vignette:
          final vp = Paint()
            ..shader = RadialGradient(
              center: Alignment.center,
              radius: 0.72,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              stops: const [0.5, 1.0],
            ).createShader(rect);
          canvas.drawRect(rect, vp);

        case _EffectType.scanlines:
          final lp = Paint()
            ..color = Colors.black.withValues(alpha: 0.20)
            ..strokeWidth = 1.0;
          final offset = (time * 12) % 4;
          for (double y = offset; y < size.height; y += 4) {
            canvas.drawLine(Offset(0, y), Offset(size.width, y), lp);
          }

        case _EffectType.colorGrade:
          final tp = Paint()
            ..color = const Color(0xFFFF9800).withValues(alpha: 0.11)
            ..blendMode = BlendMode.overlay;
          canvas.drawRect(rect, tp);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EffectOverlayPainter old) =>
      old.activeEffects != activeEffects || old.time != time;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class PostProcessingScreen extends StatefulWidget {
  const PostProcessingScreen({super.key});

  @override
  State<PostProcessingScreen> createState() => _PostProcessingScreenState();
}

class _PostProcessingScreenState extends State<PostProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;
  double _elapsed = 0;

  Set<_EffectType> _activeEffects = {_EffectType.bloom, _EffectType.vignette};
  _EffectType _selected = _EffectType.bloom;

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildScene());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world.clearSystems();
    _world.destroyAllEntities();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1_000_000.0;
    _lastTick = elapsed;
    _elapsed += dt;
    _world.update(dt);
    if (mounted) setState(() {});
  }

  // ── Scene setup ───────────────────────────────────────────────────────────

  void _buildScene() {
    _world.clearSystems();
    _world.destroyAllEntities();
    _engine.rendering.camera
      ..setPosition(Offset.zero)
      ..setZoom(1.0)
      ..smoothing = false;
    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));
    _world.addSystem(_PulseSystem()..priority = 75);
    _world.addSystem(_OrbitSystem()..priority = 70);
    _world.addSystem(_DriftSystem()..priority = 65);

    _spawnStarfield();
    _spawnRings();
    _spawnNebula();
    _spawnOrbitingPlanets();
    _spawnSparkles();
  }

  void _spawnStarfield() {
    final rng = math.Random(42);
    for (int i = 0; i < 64; i++) {
      final x = (rng.nextDouble() - 0.5) * 900;
      final y = (rng.nextDouble() - 0.5) * 700;
      final r = 1.0 + rng.nextDouble() * 2.2;
      _world.createEntityWithComponents([
        TransformComponent(position: Offset(x, y)),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: r,
            fillColor: Colors.white.withValues(
              alpha: 0.38 + rng.nextDouble() * 0.45,
            ),
            layer: -10,
          ),
        ),
        _PulseComponent(
          minScale: 0.55,
          maxScale: 1.5,
          speed: 0.7 + rng.nextDouble() * 1.8,
          phase: rng.nextDouble() * math.pi * 2,
        ),
      ]);
    }
  }

  void _spawnRings() {
    for (int i = 0; i < 4; i++) {
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: 80.0 + i * 70,
            fillColor: Colors.transparent,
            strokeColor: const Color(
              0xFF5FD1FF,
            ).withValues(alpha: 0.07 + i * 0.02),
            strokeWidth: 1.5,
            layer: -5,
          ),
        ),
        _PulseComponent(
          minScale: 0.97,
          maxScale: 1.03,
          speed: 0.35 + i * 0.12,
          phase: i * 0.6,
        ),
      ]);
    }
  }

  void _spawnNebula() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          position: Offset.zero,
          layer: -8,
          onRender: (canvas, size) {
            const clouds = [
              (Offset(-90, 50), 150.0, Color(0x157FE3FF)),
              (Offset(110, -70), 120.0, Color(0x13CE93D8)),
              (Offset(20, 130), 100.0, Color(0x10F4D35E)),
            ];
            for (final (offset, radius, color) in clouds) {
              canvas.drawCircle(
                offset,
                radius,
                Paint()
                  ..color = color
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55),
              );
            }
          },
        ),
      ),
    ]);
  }

  void _spawnOrbitingPlanets() {
    const planets = [
      (Color(0xFF7FE3FF), Color(0x662266AA), 18.0, 140.0, 0.50, 0.0),
      (Color(0xFFFF7043), Color(0x667A2210), 14.0, 205.0, -0.34, 1.57),
      (Color(0xFFF4D35E), Color(0x667A5E10), 10.0, 265.0, 0.58, 3.14),
      (Color(0xFFCE93D8), Color(0x664A1A6E), 8.0, 315.0, -0.44, 4.71),
    ];

    for (final (fill, glow, r, orbit, speed, phase) in planets) {
      // Glow halo
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 4,
            onRender: (canvas, _) {
              canvas.drawCircle(
                Offset.zero,
                r * 2.5,
                Paint()
                  ..color = glow
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
              );
            },
          ),
        ),
        _OrbitComponent(
          center: Offset.zero,
          radius: orbit,
          speed: speed,
          startAngle: phase,
        ),
      ]);
      // Planet
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: r,
            fillColor: fill,
            strokeColor: Colors.white.withValues(alpha: 0.45),
            strokeWidth: 1.5,
            layer: 5,
          ),
        ),
        _OrbitComponent(
          center: Offset.zero,
          radius: orbit,
          speed: speed,
          startAngle: phase,
        ),
      ]);
    }
  }

  void _spawnSparkles() {
    final rng = math.Random(99);
    for (int i = 0; i < 14; i++) {
      final origin = Offset(
        (rng.nextDouble() - 0.5) * 520,
        (rng.nextDouble() - 0.5) * 420,
      );
      _world.createEntityWithComponents([
        TransformComponent(position: origin),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: 3,
            fillColor: const Color(0xFFFFF176),
            strokeColor: const Color(0xFFFFEB3B).withValues(alpha: 0.55),
            strokeWidth: 2,
            layer: 7,
          ),
        ),
        _DriftComponent(
          origin: origin,
          rangeX: 20,
          rangeY: 15,
          speed: 0.45 + rng.nextDouble() * 0.6,
          phaseX: rng.nextDouble() * math.pi * 2,
          phaseY: rng.nextDouble() * math.pi * 2,
        ),
        _PulseComponent(
          minScale: 0.4,
          maxScale: 1.7,
          speed: 1.3 + rng.nextDouble() * 1.2,
          phase: rng.nextDouble() * math.pi * 2,
        ),
      ]);
    }
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  void _toggleEffect(_EffectType effect) {
    setState(() {
      _selected = effect;
      if (_activeEffects.contains(effect)) {
        _activeEffects = Set.of(_activeEffects)..remove(effect);
      } else {
        _activeEffects = Set.of(_activeEffects)..add(effect);
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildCanvas()),
        _buildEffectPanel(),
      ],
    );
  }

  Widget _buildHeader() {
    final passes =
        _EffectType.values.where((e) => _activeEffects.contains(e)).toList()
          ..sort((a, b) => a.passOrder.compareTo(b.passOrder));

    return Container(
      color: const Color(0xFF0A1220),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Post-Process Shader API',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'ShaderComponent  ·  PostProcessSystem  ·  PostProcessPass',
            style: TextStyle(color: Color(0xFF5FD1FF), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Entities: ${_world.entities.length}   |   '
            'Systems: ${_world.systems.length}   |   '
            'Active passes: ${_activeEffects.length}   |   '
            'Zoom: ${_engine.rendering.camera.zoom.toStringAsFixed(2)}x',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Pass chain: ${_activeEffects.isEmpty ? 'none' : ''}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (passes.isNotEmpty) ...[
                for (int i = 0; i < passes.length; i++) ...[
                  Text(
                    passes[i].label,
                    style: TextStyle(
                      color: passes[i].accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (i < passes.length - 1)
                    const Text(
                      ' → ',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return CameraZoomControls(
      camera: _engine.rendering.camera,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(engine: _engine, showFPS: true, showDebug: false),

          // Simulated post-process overlays rendered as a chained Canvas pass —
          // mirrors what ShaderComponent(isPostProcess: true) + PostProcessPass
          // + PostProcessSystem would do when real GLSL shaders are bundled.
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _EffectOverlayPainter(
                  activeEffects: _activeEffects,
                  time: _elapsed,
                ),
              ),
            ),
          ),

          // Pass-chain indicator
          if (_activeEffects.isNotEmpty)
            Positioned(
              top: 8,
              left: 10,
              child: _PassChainBadge(
                activeEffects: _activeEffects,
                selected: _selected,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEffectPanel() {
    return Container(
      color: const Color(0xFF0A1220),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF1A2535)),
          // Toggle chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _EffectType.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final effect = _EffectType.values[i];
                final active = _activeEffects.contains(effect);
                return FilterChip(
                  avatar: Icon(
                    effect.icon,
                    size: 14,
                    color: active ? effect.accentColor : Colors.white38,
                  ),
                  label: Text(
                    effect.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? Colors.white : Colors.white54,
                    ),
                  ),
                  selected: active,
                  showCheckmark: true,
                  checkmarkColor: effect.accentColor,
                  selectedColor: effect.accentColor.withValues(alpha: 0.18),
                  backgroundColor: const Color(0xFF141E2D),
                  side: BorderSide(
                    color: active
                        ? effect.accentColor.withValues(alpha: 0.65)
                        : const Color(0xFF263040),
                  ),
                  onSelected: (_) => _toggleEffect(effect),
                );
              },
            ),
          ),
          // Code card
          _buildCodeCard(),
          const SizedBox(height: 10),
        ],
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
          color: const Color(0xFF0D1825),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selected.accentColor.withValues(alpha: 0.40),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(_selected.icon, size: 13, color: _selected.accentColor),
                const SizedBox(width: 6),
                Text(
                  '${_selected.label}  ·  passOrder: ${_selected.passOrder}',
                  style: TextStyle(
                    color: _selected.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'ECS entity → PostProcessSystem → PostProcessPass',
                  style: TextStyle(color: Colors.white24, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: SingleChildScrollView(
                child: Text(
                  _selected.codeSnippet,
                  style: const TextStyle(
                    color: Color(0xFFB0C8E0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pass-chain badge
// ─────────────────────────────────────────────────────────────────────────────

class _PassChainBadge extends StatelessWidget {
  final Set<_EffectType> activeEffects;
  final _EffectType selected;

  const _PassChainBadge({required this.activeEffects, required this.selected});

  @override
  Widget build(BuildContext context) {
    final sorted = activeEffects.toList()
      ..sort((a, b) => a.passOrder.compareTo(b.passOrder));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: selected.accentColor.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: selected.accentColor),
          const SizedBox(width: 5),
          for (int i = 0; i < sorted.length; i++) ...[
            Text(
              sorted[i].label,
              style: TextStyle(
                color: sorted[i].accentColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (i < sorted.length - 1)
              const Text(
                ' → ',
                style: TextStyle(color: Colors.white30, fontSize: 10),
              ),
          ],
          if (sorted.isEmpty)
            const Text(
              'No active passes',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
        ],
      ),
    );
  }
}

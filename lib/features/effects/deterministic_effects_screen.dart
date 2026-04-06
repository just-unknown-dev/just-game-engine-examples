import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  move,
  scale,
  rotate,
  fade,
  colorTint,
  shake,
  path,
  sequence,
  parallel,
  repeat,
  composite;

  String get label => switch (this) {
    move => 'MoveEffect',
    scale => 'ScaleEffect',
    rotate => 'RotateEffect',
    fade => 'FadeEffect',
    colorTint => 'ColorTint',
    shake => 'ShakeEffect',
    path => 'PathEffect',
    sequence => 'Sequence',
    parallel => 'Parallel',
    repeat => 'RepeatEffect',
    composite => 'Composite',
  };

  IconData get icon => switch (this) {
    move => Icons.open_with,
    scale => Icons.zoom_out_map,
    rotate => Icons.rotate_right,
    fade => Icons.opacity,
    colorTint => Icons.color_lens,
    shake => Icons.vibration,
    path => Icons.route,
    sequence => Icons.playlist_play,
    parallel => Icons.call_split,
    repeat => Icons.repeat,
    composite => Icons.layers,
  };

  Color get accentColor => switch (this) {
    move => const Color(0xFF29B6F6),
    scale => const Color(0xFF66BB6A),
    rotate => const Color(0xFFFFCA28),
    fade => const Color(0xFF78909C),
    colorTint => const Color(0xFFEC407A),
    shake => const Color(0xFFFF5252),
    path => const Color(0xFFAB47BC),
    sequence => const Color(0xFF26A69A),
    parallel => const Color(0xFFFF7043),
    repeat => const Color(0xFF42A5F5),
    composite => const Color(0xFFA5D6A7),
  };

  String get description => switch (this) {
    move =>
      'MoveEffect translates an entity\'s position from a start to a target '
          'over a given tick count using any EasingType. Applies an additive '
          'delta each tick — multiple concurrent MoveEffects stack correctly.',
    scale =>
      'ScaleEffect animates TransformComponent.scale from its captured start '
          'to the target value. Additive deltas let two ScaleEffects run '
          'simultaneously without conflict.',
    rotate =>
      'RotateEffect animates TransformComponent.rotation (radians). Positive '
          'values rotate clockwise in Flutter\'s coordinate system. Supports '
          'looping for continuous spin.',
    fade =>
      'FadeEffect drives Renderable.opacity on the entity\'s RenderableComponent '
          'from a start alpha to the target. Clamped to [0, 1] after each tick. '
          'Additive — two fades stack their opacity deltas.',
    colorTint =>
      'ColorTintEffect lerps Renderable.tint from a start Color to the target. '
          'Uses absolute interpolation (last writer wins) rather than additive '
          'deltas. Ideal for hit-flash and palette transitions.',
    shake =>
      'ShakeEffect applies a deterministic sin/cos oscillation to position, '
          'decaying linearly to zero at durationTicks. Every peer with the same '
          'parameters produces bit-identical shake — safe for multiplayer.',
    path =>
      'PathEffect moves an entity along a list of waypoints (linear) or a '
          'cubic Bézier spline (4 control points). relativeToStart offsets all '
          'waypoints from the entity\'s position at t=0.',
    sequence =>
      'SequenceEffect chains child effects one after another. Total duration '
          'equals the sum of child durations. Each child\'s baseline is captured '
          'fresh at the start of its slice.',
    parallel =>
      'ParallelEffect runs all children simultaneously. Total duration equals '
          'the longest child. Shorter children finish early and stop contributing '
          'while the wrapper continues.',
    repeat =>
      'RepeatEffect wraps any effect and runs it N times (0 = infinite). '
          'Child baselines are re-captured at the start of each iteration. '
          'Infinite repeats set loop: true on the inner EffectPlayer entry.',
    composite =>
      'Full composite: a RepeatEffect wrapping a SequenceEffect that itself '
          'nests a MoveEffect → ShakeEffect → ParallelEffect(Fade+ColorTint). '
          'Demonstrates the full compositional power of the system.',
  };

  String get codeSnippet => switch (this) {
    move =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: MoveEffect(\n'
          '    to: Offset(200, 0),\n'
          '    easing: EasingType.easeOutCubic,\n'
          '    durationTicks: 60,\n'
          '  ),\n'
          ');',
    scale =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: ScaleEffect(\n'
          '    from: 1.0,\n'
          '    to: 2.0,\n'
          '    easing: EasingType.easeOutElastic,\n'
          '    durationTicks: 45,\n'
          '  ),\n'
          ');',
    rotate =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: RotateEffect(\n'
          '    to: 2 * math.pi,\n'
          '    easing: EasingType.easeInOutCubic,\n'
          '    durationTicks: 90,\n'
          '    loop: true,\n'
          '  ),\n'
          ');',
    fade =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: FadeEffect(\n'
          '    from: 1.0,\n'
          '    to: 0.0,\n'
          '    easing: EasingType.easeInQuad,\n'
          '    durationTicks: 60,\n'
          '  ),\n'
          ');',
    colorTint =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: ColorTintEffect(\n'
          '    from: Colors.white,\n'
          '    to: Colors.red,\n'
          '    easing: EasingType.easeOutQuad,\n'
          '    durationTicks: 30,\n'
          '  ),\n'
          ');',
    shake =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: ShakeEffect(\n'
          '    amplitude: 12.0,\n'
          '    frequency: 4.0,\n'
          '    durationTicks: 30,\n'
          '  ),\n'
          ');',
    path =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: PathEffect(\n'
          '    waypoints: [\n'
          '      Offset(0, 0), Offset(50, -80),\n'
          '      Offset(150, -80), Offset(200, 0),\n'
          '    ],\n'
          '    cubicBezier: true,\n'
          '    durationTicks: 90,\n'
          '  ),\n'
          ');',
    sequence =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: SequenceEffect([\n'
          '    MoveEffect(to: Offset(160, 0), durationTicks: 30),\n'
          '    ShakeEffect(amplitude: 8, durationTicks: 20),\n'
          '    FadeEffect(to: 0.0, durationTicks: 30),\n'
          '  ]),\n'
          ');',
    parallel =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: ParallelEffect([\n'
          '    MoveEffect(to: Offset(140, -80), durationTicks: 60),\n'
          '    ScaleEffect(to: 1.8, durationTicks: 40),\n'
          '    FadeEffect(to: 0.0, durationTicks: 60),\n'
          '  ]),\n'
          ');',
    repeat =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: RepeatEffect(\n'
          '    times: 4,\n'
          '    child: SequenceEffect([\n'
          '      MoveEffect(to: Offset(0, -30), durationTicks: 20),\n'
          '      MoveEffect(to: Offset(0, 0),  durationTicks: 20),\n'
          '    ]),\n'
          '  ),\n'
          ');',
    composite =>
      'effectSystem.scheduleEffect(\n'
          '  entity: entity,\n'
          '  effect: RepeatEffect(\n'
          '    times: 3,\n'
          '    child: SequenceEffect([\n'
          '      MoveEffect(to: Offset(120, -60), durationTicks: 25),\n'
          '      ShakeEffect(amplitude: 6, durationTicks: 15),\n'
          '      ParallelEffect([\n'
          '        FadeEffect(to: 0.3, durationTicks: 20),\n'
          '        ColorTintEffect(\n'
          '          to: Colors.orange, durationTicks: 20),\n'
          '      ]),\n'
          '      MoveEffect(to: Offset.zero, durationTicks: 20),\n'
          '    ]),\n'
          '  ),\n'
          ');',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class DeterministicEffectsScreen extends StatefulWidget {
  const DeterministicEffectsScreen({super.key});

  @override
  State<DeterministicEffectsScreen> createState() =>
      _DeterministicEffectsScreenState();
}

class _DeterministicEffectsScreenState extends State<DeterministicEffectsScreen>
    with SingleTickerProviderStateMixin {
  // ── Engine ────────────────────────────────────────────────────────────────
  late final Engine _engine;
  late final World _world;
  late final EffectSystemECS _effectSystem;
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;

  // ── State ─────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.move;
  String _statusMessage = '';

  // Entity handles for each demo slot
  final List<Entity> _demoEntities = [];

  // ── Easing picker state ───────────────────────────────────────────────────
  EasingType _selectedEasing = EasingType.easeOutCubic;
  static const _easings = [
    EasingType.linear,
    EasingType.easeInQuad,
    EasingType.easeOutQuad,
    EasingType.easeInOutQuad,
    EasingType.easeInCubic,
    EasingType.easeOutCubic,
    EasingType.easeInOutCubic,
    EasingType.easeInSine,
    EasingType.easeOutSine,
    EasingType.easeInOutSine,
    EasingType.easeInElastic,
    EasingType.easeOutElastic,
    EasingType.easeInBounce,
    EasingType.easeOutBounce,
  ];

  // ── Speed slider ──────────────────────────────────────────────────────────
  double _speedScale = 1.0; // multiplier on durationTicks (inverse)

  int get _durationTicks => (60 / _speedScale).round().clamp(10, 300);

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;

    _effectSystem = EffectSystemECS();
    _world.addSystem(_effectSystem);

    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildDemo(_demo));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world.destroyAllEntities();
    _world.clearSystems();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tick
  // ─────────────────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────────────
  // Demo construction
  // ─────────────────────────────────────────────────────────────────────────

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _demoEntities.clear();

    _world.destroyAllEntities();
    _world.clearSystems();

    // Re-add systems after clearSystems
    _world.addSystem(_effectSystem);
    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));

    _engine.rendering.camera.reset();

    _spawnGrid();

    switch (demo) {
      case _Demo.move:
        _buildMove();
      case _Demo.scale:
        _buildScale();
      case _Demo.rotate:
        _buildRotate();
      case _Demo.fade:
        _buildFade();
      case _Demo.colorTint:
        _buildColorTint();
      case _Demo.shake:
        _buildShake();
      case _Demo.path:
        _buildPath();
      case _Demo.sequence:
        _buildSequence();
      case _Demo.parallel:
        _buildParallel();
      case _Demo.repeat:
        _buildRepeat();
      case _Demo.composite:
        _buildComposite();
    }

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared: background grid
  // ─────────────────────────────────────────────────────────────────────────

  void _spawnGrid() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          getBoundsCallback: () =>
              const Rect.fromLTWH(-2000, -2000, 4000, 4000),
          onRender: (canvas, _) {
            final gridPaint = Paint()
              ..color = const Color(0xFF1E2D3E)
              ..strokeWidth = 0.5;
            const step = 40.0;
            const extent = 500.0;
            for (double x = -extent; x <= extent; x += step) {
              canvas.drawLine(Offset(x, -extent), Offset(x, extent), gridPaint);
            }
            for (double y = -extent; y <= extent; y += step) {
              canvas.drawLine(Offset(-extent, y), Offset(extent, y), gridPaint);
            }
            // Axis lines
            final axisPaint = Paint()
              ..color = const Color(0xFF2A3F54)
              ..strokeWidth = 1.0;
            canvas.drawLine(
              const Offset(-extent, 0),
              const Offset(extent, 0),
              axisPaint,
            );
            canvas.drawLine(
              const Offset(0, -extent),
              const Offset(0, extent),
              axisPaint,
            );
          },
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Entity factory helpers
  // ─────────────────────────────────────────────────────────────────────────

  Entity _spawnBall({
    Offset position = Offset.zero,
    Color color = const Color(0xFF29B6F6),
    double radius = 20,
    String? name,
  }) {
    final e = _world.createEntity(name: name ?? 'ball');
    e.addComponent(TransformComponent(position: position));
    e.addComponent(
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 10,
          getBoundsCallback: () => Rect.fromCenter(
            center: Offset.zero,
            width: radius * 4,
            height: radius * 4,
          ),
          onRender: (canvas, _) {
            // Glow
            canvas.drawCircle(
              Offset.zero,
              radius + 4,
              Paint()
                ..color = color.withAlpha(60)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
            );
            // Body
            canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
            // Ring
            canvas.drawCircle(
              Offset.zero,
              radius,
              Paint()
                ..color = Colors.white.withAlpha(60)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
          },
        ),
      ),
    );
    _demoEntities.add(e);
    return e;
  }

  Entity _spawnBox({
    Offset position = Offset.zero,
    Color color = const Color(0xFF66BB6A),
    double size = 36,
    String? name,
  }) {
    final e = _world.createEntity(name: name ?? 'box');
    e.addComponent(TransformComponent(position: position));
    e.addComponent(
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 10,
          getBoundsCallback: () => Rect.fromCenter(
            center: Offset.zero,
            width: size * 3,
            height: size * 3,
          ),
          onRender: (canvas, _) {
            final half = size / 2;
            final rect = Rect.fromCenter(
              center: Offset.zero,
              width: size,
              height: size,
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(6)),
              Paint()..color = color,
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(6)),
              Paint()
                ..color = Colors.white.withAlpha(50)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
            // Inner square decoration
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: half, height: half),
                const Radius.circular(3),
              ),
              Paint()..color = Colors.white.withAlpha(80),
            );
          },
        ),
      ),
    );
    _demoEntities.add(e);
    return e;
  }

  Entity _spawnStar({
    Offset position = Offset.zero,
    Color color = const Color(0xFFFFCA28),
    double radius = 24,
    String? name,
  }) {
    final e = _world.createEntity(name: name ?? 'star');
    e.addComponent(TransformComponent(position: position));
    e.addComponent(
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 10,
          getBoundsCallback: () => Rect.fromCenter(
            center: Offset.zero,
            width: radius * 4,
            height: radius * 4,
          ),
          onRender: (canvas, _) {
            final path = Path();
            const points = 5;
            final inner = radius * 0.45;
            for (int i = 0; i < points * 2; i++) {
              final r = i.isEven ? radius : inner;
              final angle = (i * math.pi / points) - math.pi / 2;
              final pt = Offset(math.cos(angle) * r, math.sin(angle) * r);
              if (i == 0) {
                path.moveTo(pt.dx, pt.dy);
              } else {
                path.lineTo(pt.dx, pt.dy);
              }
            }
            path.close();
            canvas.drawPath(path, Paint()..color = color);
            canvas.drawPath(
              path,
              Paint()
                ..color = Colors.white.withAlpha(50)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          },
        ),
      ),
    );
    _demoEntities.add(e);
    return e;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Individual demo builders
  // ─────────────────────────────────────────────────────────────────────────

  void _buildMove() {
    _spawnBall(position: const Offset(-160, 0), color: _Demo.move.accentColor);
    _statusMessage = 'Tap "Play" to run MoveEffect';
  }

  void _buildScale() {
    _spawnBox(color: _Demo.scale.accentColor);
    _statusMessage = 'Tap "Play" to run ScaleEffect';
  }

  void _buildRotate() {
    _spawnStar(color: _Demo.rotate.accentColor);
    _statusMessage = 'Tap "Play" to run RotateEffect';
  }

  void _buildFade() {
    _spawnBall(color: _Demo.fade.accentColor);
    _statusMessage = 'Tap "Play" to fade out, "Reset" to restore';
  }

  void _buildColorTint() {
    _spawnBox(color: Colors.white70);
    _statusMessage = 'Tap "Play" to color-tint, "Reset" to clear';
  }

  void _buildShake() {
    _spawnBall(color: _Demo.shake.accentColor);
    _spawnBox(
      position: const Offset(-120, 0),
      color: _Demo.shake.accentColor.withAlpha(180),
    );
    _spawnStar(
      position: const Offset(120, 0),
      color: _Demo.shake.accentColor.withAlpha(200),
    );
    _statusMessage = 'Tap "Light", "Medium", or "Heavy" to shake';
  }

  void _buildPath() {
    _spawnBall(position: const Offset(-100, 30), color: _Demo.path.accentColor);
    _statusMessage = 'Tap "Linear" for 3-waypoint or "Bezier" for cubic spline';
  }

  void _buildSequence() {
    // Show three ghost positions to hint at the sequence steps
    _spawnBall(
      position: const Offset(-120, 0),
      color: _Demo.sequence.accentColor,
    );
    _statusMessage = 'Tap "Play" — Move → Shake → Fade in sequence';
  }

  void _buildParallel() {
    _spawnBall(color: _Demo.parallel.accentColor);
    _statusMessage = 'Tap "Play" — Move + Scale + Fade simultaneously';
  }

  void _buildRepeat() {
    _spawnBox(color: _Demo.repeat.accentColor);
    _statusMessage = 'Tap "×3 Bounce" for finite or "∞ Float" for infinite';
  }

  void _buildComposite() {
    _spawnStar(color: _Demo.composite.accentColor);
    _statusMessage = 'Tap "Play" — Repeat(Sequence(Move→Shake→Parallel))';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Effect triggers
  // ─────────────────────────────────────────────────────────────────────────

  void _resetEntity() {
    if (_demoEntities.isEmpty) return;
    for (final e in _demoEntities) {
      final t = e.getComponent<TransformComponent>();
      if (t != null) {
        t.position = Offset.zero;
        t.scale = 1.0;
        t.rotation = 0.0;
      }
      final r = e.getComponent<RenderableComponent>();
      if (r != null) {
        r.renderable.opacity = 1.0;
        r.renderable.tint = null;
      }
      final ec = e.getComponent<EffectComponent>();
      ec?.player.cancelAll();
    }
    // Rebuild entity positions per demo
    switch (_demo) {
      case _Demo.move:
        _demoEntities.first.getComponent<TransformComponent>()!.position =
            const Offset(-160, 0);
      case _Demo.path:
        _demoEntities.first.getComponent<TransformComponent>()!.position =
            const Offset(-100, 30);
      case _Demo.sequence:
        _demoEntities.first.getComponent<TransformComponent>()!.position =
            const Offset(-120, 0);
      default:
        break;
    }
    setState(() => _statusMessage = 'Reset');
  }

  void _playMove() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<TransformComponent>()?.position = const Offset(-160, 0);
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: MoveEffect(
        from: const Offset(-160, 0),
        to: const Offset(160, 0),
        easing: _selectedEasing,
        durationTicks: _durationTicks,
      ),
    );
    setState(() => _statusMessage = 'MoveEffect playing…');
  }

  void _playScale() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    final t = e.getComponent<TransformComponent>();
    if (t != null) {
      t.scale = 1.0;
    }
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: ScaleEffect(
        from: 1.0,
        to: 2.2,
        easing: _selectedEasing,
        durationTicks: _durationTicks,
      ),
    );
    setState(() => _statusMessage = 'ScaleEffect playing…');
  }

  void _playRotate() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<EffectComponent>()?.player.cancelAll();
    e.getComponent<TransformComponent>()?.rotation = 0.0;
    _effectSystem.scheduleEffect(
      entity: e,
      effect: RotateEffect(
        from: 0,
        to: 2 * math.pi,
        easing: _selectedEasing,
        durationTicks: _durationTicks,
        loop: false,
      ),
    );
    setState(() => _statusMessage = 'RotateEffect playing one full spin…');
  }

  void _playRotateLoop() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<EffectComponent>()?.player.cancelAll();
    e.getComponent<TransformComponent>()?.rotation = 0.0;
    _effectSystem.scheduleEffect(
      entity: e,
      effect: RotateEffect(
        from: 0,
        to: 2 * math.pi,
        easing: EasingType.linear,
        durationTicks: _durationTicks,
        loop: true,
      ),
    );
    setState(() => _statusMessage = 'RotateEffect looping…');
  }

  void _playFadeOut() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<RenderableComponent>()?.renderable.opacity = 1.0;
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: FadeEffect(
        from: 1.0,
        to: 0.0,
        easing: _selectedEasing,
        durationTicks: _durationTicks,
      ),
    );
    setState(() => _statusMessage = 'FadeEffect: fade out');
  }

  void _playFadeIn() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<RenderableComponent>()?.renderable.opacity = 0.0;
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: FadeEffect(
        from: 0.0,
        to: 1.0,
        easing: _selectedEasing,
        durationTicks: _durationTicks,
      ),
    );
    setState(() => _statusMessage = 'FadeEffect: fade in');
  }

  void _playColorTint(Color targetColor, String label) {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<RenderableComponent>()?.renderable.tint = Colors.white;
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: ColorTintEffect(
        from: Colors.white,
        to: targetColor,
        easing: _selectedEasing,
        durationTicks: _durationTicks,
      ),
    );
    setState(() => _statusMessage = 'ColorTintEffect → $label');
  }

  void _playShake(double amplitude, String label) {
    for (final e in _demoEntities) {
      e.getComponent<EffectComponent>()?.player.cancelAll();
      _effectSystem.scheduleEffect(
        entity: e,
        effect: ShakeEffect(
          amplitude: amplitude,
          frequency: 4.0,
          durationTicks: _durationTicks ~/ 2,
        ),
      );
    }
    setState(() => _statusMessage = 'ShakeEffect — $label');
  }

  void _playPathLinear() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<TransformComponent>()?.position = const Offset(-100, 30);
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: PathEffect(
        waypoints: const [
          Offset(-100, 30),
          Offset(-30, -80),
          Offset(60, 60),
          Offset(140, -30),
        ],
        cubicBezier: false,
        relativeToStart: false,
        easing: _selectedEasing,
        durationTicks: _durationTicks + 30,
      ),
    );
    setState(() => _statusMessage = 'PathEffect: linear 4-waypoints');
  }

  void _playPathBezier() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<TransformComponent>()?.position = const Offset(-100, 30);
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: PathEffect(
        waypoints: const [
          Offset(0, 0),
          Offset(60, -120),
          Offset(160, -120),
          Offset(220, 0),
        ],
        cubicBezier: true,
        relativeToStart: true,
        easing: _selectedEasing,
        durationTicks: _durationTicks + 30,
      ),
    );
    setState(() => _statusMessage = 'PathEffect: cubic Bézier arc');
  }

  void _playSequence() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<TransformComponent>()?.position = const Offset(-120, 0);
    e.getComponent<RenderableComponent>()?.renderable.opacity = 1.0;
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: SequenceEffect(
        children: [
          MoveEffect(
            from: const Offset(-120, 0),
            to: const Offset(100, 0),
            easing: _selectedEasing,
            durationTicks: _durationTicks,
          ),
          ShakeEffect(
            amplitude: 10,
            frequency: 4,
            durationTicks: _durationTicks ~/ 3,
          ),
          FadeEffect(
            from: 1.0,
            to: 0.0,
            easing: EasingType.easeInQuad,
            durationTicks: _durationTicks ~/ 2,
          ),
        ],
      ),
    );
    setState(() => _statusMessage = 'SequenceEffect: Move → Shake → Fade');
  }

  void _playParallel() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<TransformComponent>()?.position = Offset.zero;
    e.getComponent<TransformComponent>()?.scale = 1.0;
    e.getComponent<RenderableComponent>()?.renderable.opacity = 1.0;
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: ParallelEffect(
        children: [
          MoveEffect(
            from: Offset.zero,
            to: const Offset(140, -80),
            easing: _selectedEasing,
            durationTicks: _durationTicks,
          ),
          ScaleEffect(
            from: 1.0,
            to: 1.8,
            easing: EasingType.easeOutElastic,
            durationTicks: (_durationTicks * 0.7).round(),
          ),
          FadeEffect(
            from: 1.0,
            to: 0.0,
            easing: EasingType.easeInQuad,
            durationTicks: _durationTicks,
          ),
        ],
      ),
    );
    setState(
      () =>
          _statusMessage = 'ParallelEffect: Move + Scale + Fade simultaneously',
    );
  }

  void _playRepeatBounce() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<TransformComponent>()?.position = Offset.zero;
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: RepeatEffect(
        times: 4,
        child: SequenceEffect(
          children: [
            MoveEffect(
              from: Offset.zero,
              to: const Offset(0, -50),
              easing: EasingType.easeOutQuad,
              durationTicks: _durationTicks ~/ 3,
            ),
            MoveEffect(
              from: const Offset(0, -50),
              to: Offset.zero,
              easing: EasingType.easeInBounce,
              durationTicks: _durationTicks ~/ 3,
            ),
          ],
        ),
      ),
    );
    setState(() => _statusMessage = 'RepeatEffect ×4 — bounce');
  }

  void _playRepeatInfinite() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<TransformComponent>()?.position = Offset.zero;
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: RepeatEffect(
        times: 0, // infinite
        child: SequenceEffect(
          children: [
            MoveEffect(
              from: Offset.zero,
              to: const Offset(0, -20),
              easing: EasingType.easeOutSine,
              durationTicks: 40,
            ),
            MoveEffect(
              from: const Offset(0, -20),
              to: Offset.zero,
              easing: EasingType.easeInSine,
              durationTicks: 40,
            ),
          ],
        ),
      ),
    );
    setState(() => _statusMessage = 'RepeatEffect ∞ — idle float');
  }

  void _playComposite() {
    if (_demoEntities.isEmpty) return;
    final e = _demoEntities.first;
    e.getComponent<TransformComponent>()?.position = Offset.zero;
    e.getComponent<TransformComponent>()?.scale = 1.0;
    e.getComponent<RenderableComponent>()?.renderable.opacity = 1.0;
    e.getComponent<RenderableComponent>()?.renderable.tint = null;
    e.getComponent<EffectComponent>()?.player.cancelAll();
    _effectSystem.scheduleEffect(
      entity: e,
      effect: RepeatEffect(
        times: 3,
        child: SequenceEffect(
          children: [
            MoveEffect(
              from: Offset.zero,
              to: const Offset(100, -60),
              easing: EasingType.easeOutCubic,
              durationTicks: 25,
            ),
            ShakeEffect(amplitude: 6, frequency: 4, durationTicks: 15),
            ParallelEffect(
              children: [
                FadeEffect(
                  from: 1.0,
                  to: 0.35,
                  easing: EasingType.easeInQuad,
                  durationTicks: 20,
                ),
                ColorTintEffect(
                  from: Colors.white,
                  to: const Color(0xFFFF7043),
                  easing: EasingType.linear,
                  durationTicks: 20,
                ),
              ],
            ),
            MoveEffect(
              from: const Offset(100, -60),
              to: Offset.zero,
              easing: EasingType.easeInOutCubic,
              durationTicks: 20,
            ),
          ],
        ),
      ),
    );
    setState(
      () => _statusMessage =
          'Composite: Repeat(Sequence(Move→Shake→Parallel(Fade+Tint)))',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Live stats
  // ─────────────────────────────────────────────────────────────────────────

  String get _statsLine {
    if (_demoEntities.isEmpty) return 'tick ${_effectSystem.currentTick}';
    final e = _demoEntities.first;
    final t = e.getComponent<TransformComponent>();
    final r = e.getComponent<RenderableComponent>();
    final ec = e.getComponent<EffectComponent>();
    final pos = t?.position ?? Offset.zero;
    return 'tick ${_effectSystem.currentTick}'
        '  pos (${pos.dx.toStringAsFixed(0)}, ${pos.dy.toStringAsFixed(0)})'
        '  scale ${(t?.scale ?? 1).toStringAsFixed(2)}'
        '  rot ${((t?.rotation ?? 0) * 180 / math.pi).toStringAsFixed(1)}°'
        '  α ${(r?.renderable.opacity ?? 1).toStringAsFixed(2)}'
        '  active ${ec?.player.activeCount ?? 0}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _demo.accentColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _demo.accentColor.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_demo.icon, size: 12, color: _demo.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      _demo.label,
                      style: TextStyle(
                        color: _demo.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _statsLine,
                style: const TextStyle(
                  color: Color(0xFF607D8B),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _demo.description,
            style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _demo.accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return GameWidget(engine: _engine, showFPS: true, showDebug: false);
  }

  Widget _buildDemoSelector() {
    return Container(
      color: const Color(0xFF060D18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF1A2A3A)),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: _Demo.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final d = _Demo.values[i];
                final selected = d == _demo;
                return GestureDetector(
                  onTap: () => _buildDemo(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? d.accentColor.withAlpha(40)
                          : const Color(0xFF0A1520),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected
                            ? d.accentColor.withAlpha(160)
                            : const Color(0xFF1A2A3A),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          d.icon,
                          size: 12,
                          color: selected
                              ? d.accentColor
                              : const Color(0xFF4A6070),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          d.label,
                          style: TextStyle(
                            color: selected
                                ? d.accentColor
                                : const Color(0xFF4A6070),
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1A2A3A)),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0xFF060D18),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEasingAndSpeedRow(),
          const SizedBox(height: 4),
          _buildDemoControls(),
        ],
      ),
    );
  }

  Widget _buildEasingAndSpeedRow() {
    return Row(
      children: [
        const Text(
          'Easing:',
          style: TextStyle(color: Color(0xFF607D8B), fontSize: 11),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: DropdownButton<EasingType>(
            value: _selectedEasing,
            dropdownColor: const Color(0xFF0D1B2A),
            style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11),
            underline: Container(height: 1, color: const Color(0xFF1A2A3A)),
            isDense: true,
            items: _easings
                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedEasing = v);
            },
          ),
        ),
        const SizedBox(width: 16),
        const Text(
          'Speed:',
          style: TextStyle(color: Color(0xFF607D8B), fontSize: 11),
        ),
        SizedBox(
          width: 100,
          child: Slider(
            value: _speedScale,
            min: 0.25,
            max: 3.0,
            divisions: 11,
            activeColor: _demo.accentColor,
            inactiveColor: const Color(0xFF1A2A3A),
            onChanged: (v) => setState(() => _speedScale = v),
          ),
        ),
        Text(
          '${_speedScale.toStringAsFixed(2)}×',
          style: const TextStyle(
            color: Color(0xFF607D8B),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildDemoControls() {
    return switch (_demo) {
      _Demo.move => _buildMoveControls(),
      _Demo.scale => _buildScaleControls(),
      _Demo.rotate => _buildRotateControls(),
      _Demo.fade => _buildFadeControls(),
      _Demo.colorTint => _buildColorTintControls(),
      _Demo.shake => _buildShakeControls(),
      _Demo.path => _buildPathControls(),
      _Demo.sequence => _buildSequenceControls(),
      _Demo.parallel => _buildParallelControls(),
      _Demo.repeat => _buildRepeatControls(),
      _Demo.composite => _buildCompositeControls(),
    };
  }

  Widget _buildMoveControls() {
    return _controlRow([
      _actionButton('Play', _Demo.move.accentColor, _playMove),
      _actionButton('Reset', const Color(0xFF455A64), _resetEntity),
    ]);
  }

  Widget _buildScaleControls() {
    return _controlRow([
      _actionButton('Play', _Demo.scale.accentColor, _playScale),
      _actionButton('Reset', const Color(0xFF455A64), _resetEntity),
    ]);
  }

  Widget _buildRotateControls() {
    return _controlRow([
      _actionButton('One Spin', _Demo.rotate.accentColor, _playRotate),
      _actionButton(
        'Loop ∞',
        _Demo.rotate.accentColor.withAlpha(180),
        _playRotateLoop,
      ),
      _actionButton('Stop', const Color(0xFF455A64), _resetEntity),
    ]);
  }

  Widget _buildFadeControls() {
    return _controlRow([
      _actionButton('Fade Out', _Demo.fade.accentColor, _playFadeOut),
      _actionButton(
        'Fade In',
        _Demo.fade.accentColor.withAlpha(200),
        _playFadeIn,
      ),
      _actionButton('Reset', const Color(0xFF455A64), _resetEntity),
    ]);
  }

  Widget _buildColorTintControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _actionButton(
          'Red',
          const Color(0xFFEF5350),
          () => _playColorTint(const Color(0xFFEF5350), 'Red'),
        ),
        _actionButton(
          'Orange',
          const Color(0xFFFF7043),
          () => _playColorTint(const Color(0xFFFF7043), 'Orange'),
        ),
        _actionButton(
          'Cyan',
          const Color(0xFF26C6DA),
          () => _playColorTint(const Color(0xFF26C6DA), 'Cyan'),
        ),
        _actionButton(
          'Purple',
          const Color(0xFFAB47BC),
          () => _playColorTint(const Color(0xFFAB47BC), 'Purple'),
        ),
        _actionButton('Reset', const Color(0xFF455A64), _resetEntity),
      ],
    );
  }

  Widget _buildShakeControls() {
    return _controlRow([
      _actionButton(
        'Light (4)',
        const Color(0xFFFFD54F),
        () => _playShake(4, 'light'),
      ),
      _actionButton(
        'Medium (10)',
        const Color(0xFFFF8A65),
        () => _playShake(10, 'medium'),
      ),
      _actionButton(
        'Heavy (20)',
        const Color(0xFFEF5350),
        () => _playShake(20, 'heavy'),
      ),
    ]);
  }

  Widget _buildPathControls() {
    return _controlRow([
      _actionButton('Linear', _Demo.path.accentColor, _playPathLinear),
      _actionButton(
        'Bézier',
        _Demo.path.accentColor.withAlpha(200),
        _playPathBezier,
      ),
      _actionButton('Reset', const Color(0xFF455A64), _resetEntity),
    ]);
  }

  Widget _buildSequenceControls() {
    return _controlRow([
      _actionButton('Play', _Demo.sequence.accentColor, _playSequence),
      _actionButton('Reset', const Color(0xFF455A64), _resetEntity),
    ]);
  }

  Widget _buildParallelControls() {
    return _controlRow([
      _actionButton('Play', _Demo.parallel.accentColor, _playParallel),
      _actionButton('Reset', const Color(0xFF455A64), _resetEntity),
    ]);
  }

  Widget _buildRepeatControls() {
    return _controlRow([
      _actionButton('×4 Bounce', _Demo.repeat.accentColor, _playRepeatBounce),
      _actionButton(
        '∞ Float',
        _Demo.repeat.accentColor.withAlpha(180),
        _playRepeatInfinite,
      ),
      _actionButton('Stop', const Color(0xFF455A64), _resetEntity),
    ]);
  }

  Widget _buildCompositeControls() {
    return _controlRow([
      _actionButton('Play', _Demo.composite.accentColor, _playComposite),
      _actionButton('Reset', const Color(0xFF455A64), _resetEntity),
    ]);
  }

  Widget _controlRow(List<Widget> children) {
    return Row(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCodeCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF080F1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1A2A3A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _demo.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_demo.label} — code snippet',
                  style: const TextStyle(
                    color: Color(0xFF607D8B),
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: SingleChildScrollView(
                child: Text(
                  _demo.codeSnippet,
                  style: const TextStyle(
                    color: Color(0xFFCDD5E0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.55,
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

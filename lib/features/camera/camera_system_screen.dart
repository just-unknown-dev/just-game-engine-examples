import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  springFollow,
  lookahead,
  multiTarget,
  shake,
  path,
  room,
  cinematic,
  screenEffects,
  worldBounds;

  String get label => switch (this) {
    springFollow => 'Spring Follow',
    lookahead => 'Lookahead',
    multiTarget => 'Multi-Target',
    shake => 'Trauma Shake',
    path => 'Camera Path',
    room => 'Room Transition',
    cinematic => 'Cinematic',
    screenEffects => 'Screen Effects',
    worldBounds => 'World Bounds',
  };

  IconData get icon => switch (this) {
    springFollow => Icons.track_changes,
    lookahead => Icons.arrow_forward,
    multiTarget => Icons.filter_center_focus,
    shake => Icons.vibration,
    path => Icons.route,
    room => Icons.meeting_room,
    cinematic => Icons.movie,
    screenEffects => Icons.auto_awesome,
    worldBounds => Icons.crop_free,
  };

  Color get accentColor => switch (this) {
    springFollow => const Color(0xFF29B6F6),
    lookahead => const Color(0xFF66BB6A),
    multiTarget => const Color(0xFFAB47BC),
    shake => const Color(0xFFFF5252),
    path => const Color(0xFFFFCA28),
    room => const Color(0xFF26A69A),
    cinematic => const Color(0xFFFF7043),
    screenEffects => const Color(0xFFEC407A),
    worldBounds => const Color(0xFF78909C),
  };

  String get description => switch (this) {
    springFollow =>
      'Camera smoothly follows the target using a critically-damped spring. '
          'Dead-zone prevents micro-jitter when the target barely moves.',
    lookahead =>
      'Camera anticipates movement by offsetting toward the velocity vector. '
          'Scales with speed — stationary target snaps back to center.',
    multiTarget =>
      'Camera frames all targets simultaneously by expanding to their bounding '
          'box and auto-adjusting zoom to keep every target visible.',
    shake =>
      'Trauma-based camera shake via deterministic noise. Additive trauma in '
          '[0,1] produces positional and rotational offsets that decay over time.',
    path =>
      'Camera follows a scripted keyframe path with per-segment easing. '
          'PathBehavior bypasses spring for exact authored motion.',
    room =>
      'Room-to-room transitions with smooth lerp. RoomBehavior also clamps '
          'camera movement to the active room\'s world-space bounds.',
    cinematic =>
      'Full CinematicBehavior: keyframe sequence with per-keyframe callbacks, '
          'easing, and an onComplete handler.',
    screenEffects =>
      'CameraEffectManager overlays: ScreenFadeEffect (flash, fade-in, fade-out) '
          'and LetterboxEffect (animated cinematic bars).',
    worldBounds =>
      'Camera.worldBounds clamps the viewport so the camera never shows outside '
          'the defined world rectangle, even at any zoom level.',
  };

  String get codeSnippet => switch (this) {
    springFollow =>
      'final follow = SpringFollowBehavior(\n'
          '  target: playerPos,\n'
          '  deadZoneWidth: 30,\n'
          '  deadZoneHeight: 20,\n'
          ');\n'
          'cameraSystem.addBehavior(follow);\n\n'
          '// Each frame:\n'
          'follow.updateTarget(player.position);',
    lookahead =>
      'final la = LookaheadBehavior(\n'
          '  targetPosition: playerPos,\n'
          '  targetVelocity: playerVel,\n'
          '  lookaheadDistance: 120.0,\n'
          '  maxSpeed: 300.0,\n'
          ');\n'
          'cameraSystem.addBehavior(la);\n\n'
          '// Each frame:\n'
          'la.updateTarget(player.position, player.velocity);',
    multiTarget =>
      'final mt = MultiTargetBehavior(\n'
          '  targets: [p1.position, p2.position, p3.position],\n'
          '  padding: 100.0,\n'
          '  minZoom: 0.3,\n'
          '  maxZoom: 2.0,\n'
          ');\n'
          'cameraSystem.addBehavior(mt);\n\n'
          '// Mutate targets directly:\n'
          'mt.targets[0] = p1.position;',
    shake =>
      '// Quick shake:\n'
          'camera.addTrauma(0.6);\n\n'
          '// Or map intensity→duration:\n'
          'camera.shake(\n'
          '  intensity: 15.0,   // px at full trauma\n'
          '  duration:  0.4,    // seconds to zero\n'
          ');\n\n'
          '// Tune the shake envelope:\n'
          'camera.maxShakeOffset = 20.0;\n'
          'camera.maxShakeAngle  = 0.05; // radians\n'
          'camera.traumaDecayRate = 1.0;',
    path =>
      'cameraSystem.addBehavior(PathBehavior(\n'
          '  loop: false,\n'
          '  path: CameraPath([\n'
          '    CameraKeyframe(position: Offset.zero,   time: 0),\n'
          '    CameraKeyframe(position: Offset(400,0), zoom: 1.5, time: 2.0,\n'
          '                   easing: Curves.easeInOut),\n'
          '    CameraKeyframe(position: Offset(400,300), zoom: 1.0, time: 4.0,\n'
          '                   easing: Curves.easeIn),\n'
          '  ]),\n'
          '  onComplete: () => switchToFollowMode(),\n'
          '));',
    room =>
      'final rooms = RoomBehavior()\n'
          '  ..addRoom(CameraRoom(id: \'area_a\',\n'
          '             bounds: Rect.fromLTWH(0, 0, 800, 600)))\n'
          '  ..addRoom(CameraRoom(id: \'area_b\',\n'
          '             bounds: Rect.fromLTWH(900, 0, 800, 600)));\n'
          'cameraSystem.addBehavior(rooms);\n'
          'rooms.activateRoom(\'area_a\');\n\n'
          '// Transition:\n'
          'rooms.activateRoom(\'area_b\', transitionDuration: 0.8);',
    cinematic =>
      'cameraSystem.addBehavior(CinematicBehavior(\n'
          '  onComplete: resumeGame,\n'
          '  sequence: CinematicSequence([\n'
          '    CinematicKeyframe(time: 0,   position: Offset.zero),\n'
          '    CinematicKeyframe(time: 2.0, position: Offset(200, 0),\n'
          '        zoom: 1.8, easing: Curves.easeIn,\n'
          '        onArrive: () => showSubtitle(\'Point of interest\')),\n'
          '    CinematicKeyframe(time: 4.5, position: Offset.zero,\n'
          '        zoom: 1.0, easing: Curves.easeOut),\n'
          '  ]),\n'
          '));',
    screenEffects =>
      '// Flash on hit:\n'
          'camera.effectManager.addEffect(\n'
          '  ScreenFadeEffect()\n'
          '    ..flash(Colors.white, holdDuration: 0.08, fadeDuration: 0.3),\n'
          ');\n\n'
          '// Cinematic bars:\n'
          'final lb = LetterboxEffect(barHeightFraction: 0.1);\n'
          'camera.effectManager.addEffect(lb);\n'
          'lb.show(0.4);   // animate in\n'
          'lb.hide(0.4);   // animate out',
    worldBounds =>
      '// Lock camera inside a 2000×2000 world:\n'
          'camera.worldBounds = Rect.fromLTWH(0, 0, 2000, 2000);\n\n'
          '// Remove bounds:\n'
          'camera.worldBounds = null;\n\n'
          '// Zoom-to-point stays within bounds too:\n'
          'camera.zoomToPoint(\n'
          '  worldPoint,\n'
          '  targetZoom: 2.0,\n'
          '  smooth: true,\n'
          ');',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS Components & Systems used across demos
// ─────────────────────────────────────────────────────────────────────────────

class _MoveComponent extends Component {
  Offset position;
  Offset velocity;
  _MoveComponent({required this.position, required this.velocity});
}

class _OrbitTagComponent extends Component {
  final Offset center;
  final double radius;
  final double speed;
  double angle;
  _OrbitTagComponent({
    required this.center,
    required this.radius,
    required this.speed,
    this.angle = 0,
  });
}

class _MoveSystem extends System {
  final Rect? bounds;
  _MoveSystem({this.bounds});

  @override
  List<Type> get requiredComponents => [TransformComponent, _MoveComponent];

  @override
  void update(double dt) {
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final m = entity.getComponent<_MoveComponent>()!;
      m.position += m.velocity * dt;
      if (bounds != null) {
        // Bounce off bounds
        if (m.position.dx < bounds!.left || m.position.dx > bounds!.right) {
          m.velocity = Offset(-m.velocity.dx, m.velocity.dy);
          m.position = Offset(
            m.position.dx.clamp(bounds!.left, bounds!.right),
            m.position.dy,
          );
        }
        if (m.position.dy < bounds!.top || m.position.dy > bounds!.bottom) {
          m.velocity = Offset(m.velocity.dx, -m.velocity.dy);
          m.position = Offset(
            m.position.dx,
            m.position.dy.clamp(bounds!.top, bounds!.bottom),
          );
        }
      }
      entity.getComponent<TransformComponent>()!.position = m.position;
    }
  }
}

class _OrbitSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _OrbitTagComponent];

  @override
  void update(double dt) {
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final o = entity.getComponent<_OrbitTagComponent>()!;
      o.angle += o.speed * dt;
      entity.getComponent<TransformComponent>()!.position = Offset(
        o.center.dx + math.cos(o.angle) * o.radius,
        o.center.dy + math.sin(o.angle) * o.radius,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class CameraSystemScreen extends StatefulWidget {
  const CameraSystemScreen({super.key});

  @override
  State<CameraSystemScreen> createState() => _CameraSystemScreenState();
}

class _CameraSystemScreenState extends State<CameraSystemScreen>
    with SingleTickerProviderStateMixin {
  // ── Engine ───────────────────────────────────────────────────────────────
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;
  double _elapsed = 0;

  // ── State ────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.springFollow;
  String _statusMessage = '';

  // ── Per-demo live handles ─────────────────────────────────────────────────
  SpringFollowBehavior? _followBehavior;
  LookaheadBehavior? _lookaheadBehavior;
  MultiTargetBehavior? _multiTargetBehavior;
  RoomBehavior? _roomBehavior;
  LetterboxEffect? _letterboxEffect;
  bool _letterboxVisible = false;
  bool _cinematicRunning = false;

  // Entity references for demo updates
  final List<_MoveComponent> _movers = [];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildDemo(_demo));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.cameraSystem.clearBehaviors();
    _engine.rendering.camera.effectManager.clearEffects();
    _engine.rendering.camera.worldBounds = null;
    _engine.rendering.camera.reset();
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
    _elapsed += dt;

    // Drive ECS + camera per frame
    _world.update(dt);
    _engine.cameraSystem.update(dt);

    // Update live behavior handles that need per-frame data
    _tickDemoLogic(dt);

    if (mounted) setState(() {});
  }

  void _tickDemoLogic(double dt) {
    switch (_demo) {
      case _Demo.springFollow:
        if (_followBehavior != null && _movers.isNotEmpty) {
          _followBehavior!.updateTarget(_movers.first.position);
        }
      case _Demo.lookahead:
        if (_lookaheadBehavior != null && _movers.isNotEmpty) {
          _lookaheadBehavior!.updateTarget(
            _movers.first.position,
            _movers.first.velocity,
          );
        }
      case _Demo.multiTarget:
        if (_multiTargetBehavior != null && _movers.length >= 3) {
          for (int i = 0; i < _movers.length; i++) {
            _multiTargetBehavior!.targets[i] = _movers[i].position;
          }
        }
      default:
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo construction
  // ─────────────────────────────────────────────────────────────────────────

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _movers.clear();
    _followBehavior = null;
    _lookaheadBehavior = null;
    _multiTargetBehavior = null;
    _roomBehavior = null;
    _letterboxEffect = null;
    _letterboxVisible = false;
    _cinematicRunning = false;
    _statusMessage = '';

    _world.destroyAllEntities();
    _world.clearSystems();
    _engine.cameraSystem.clearBehaviors();
    _engine.rendering.camera.effectManager.clearEffects();
    _engine.rendering.camera.worldBounds = null;
    _engine.rendering.camera.reset();

    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));
    _world.addSystem(_OrbitSystem()..priority = 75);

    _spawnWorldGrid();

    switch (demo) {
      case _Demo.springFollow:
        _buildSpringFollow();
      case _Demo.lookahead:
        _buildLookahead();
      case _Demo.multiTarget:
        _buildMultiTarget();
      case _Demo.shake:
        _buildShake();
      case _Demo.path:
        _buildPath();
      case _Demo.room:
        _buildRoom();
      case _Demo.cinematic:
        _buildCinematic();
      case _Demo.screenEffects:
        _buildScreenEffects();
      case _Demo.worldBounds:
        _buildWorldBounds();
    }

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared world: background grid + landmark objects
  // ─────────────────────────────────────────────────────────────────────────

  void _spawnWorldGrid() {
    // Background grid lines
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
            // Origin cross
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

    // Landmark objects scattered around the world for visual reference
    final rng = math.Random(1337);
    const landmarks = [
      (Offset(-320, -200), Color(0xFF37474F), Color(0xFF546E7A)),
      (Offset(280, -180), Color(0xFF1A237E), Color(0xFF3949AB)),
      (Offset(-250, 220), Color(0xFF1B5E20), Color(0xFF2E7D32)),
      (Offset(310, 240), Color(0xFF4A148C), Color(0xFF7B1FA2)),
      (Offset(0, -280), Color(0xFF37474F), Color(0xFF455A64)),
      (Offset(-400, 50), Color(0xFF0D47A1), Color(0xFF1565C0)),
      (Offset(420, 60), Color(0xFF880E4F), Color(0xFFAD1457)),
    ];
    for (final (pos, dark, light) in landmarks) {
      final sides = 5 + rng.nextInt(4);
      final size = 28.0 + rng.nextDouble() * 24;
      _world.createEntityWithComponents([
        TransformComponent(position: pos),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: -5,
            getBoundsCallback: () =>
                Rect.fromCenter(center: pos, width: size * 3, height: size * 3),
            onRender: (canvas, _) {
              final path = Path();
              for (int i = 0; i < sides; i++) {
                final a = (i / sides) * math.pi * 2 - math.pi / 2;
                final p = Offset(math.cos(a) * size, math.sin(a) * size);
                if (i == 0)
                  path.moveTo(p.dx, p.dy);
                else
                  path.lineTo(p.dx, p.dy);
              }
              path.close();
              canvas.drawPath(path, Paint()..color = dark);
              canvas.drawPath(
                path,
                Paint()
                  ..color = light.withValues(alpha: 0.7)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2,
              );
              // Glow
              canvas.drawCircle(
                Offset.zero,
                size * 0.4,
                Paint()
                  ..color = light.withValues(alpha: 0.3)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
              );
            },
          ),
        ),
      ]);
    }
  }

  Renderable _makePlayerRenderable(Color color, {double radius = 18}) {
    return CustomRenderable(
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
          radius * 1.6,
          Paint()
            ..color = color.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
        // Body
        canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
        // Ring
        canvas.drawCircle(
          Offset.zero,
          radius,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        // Center dot
        canvas.drawCircle(
          Offset.zero,
          radius * 0.25,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Spring Follow
  // ─────────────────────────────────────────────────────────────────────────

  void _buildSpringFollow() {
    final mover = _MoveComponent(
      position: const Offset(0, 0),
      velocity: const Offset(180, 120),
    );
    _movers.add(mover);

    _world.addSystem(
      _MoveSystem(bounds: const Rect.fromLTWH(-380, -260, 760, 520)),
    );

    final player = _world.createEntity(name: 'player');
    player.addComponent(TransformComponent());
    player.addComponent(mover);
    player.addComponent(
      RenderableComponent(
        renderable: _makePlayerRenderable(const Color(0xFF29B6F6)),
      ),
    );

    _followBehavior = SpringFollowBehavior(
      target: mover.position,
      deadZoneWidth: 30,
      deadZoneHeight: 20,
    );
    _engine.cameraSystem.addBehavior(_followBehavior!);
    _statusMessage = 'Camera spring-follows the blue ball';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lookahead
  // ─────────────────────────────────────────────────────────────────────────

  void _buildLookahead() {
    final mover = _MoveComponent(
      position: const Offset(0, 0),
      velocity: const Offset(200, 90),
    );
    _movers.add(mover);

    _world.addSystem(
      _MoveSystem(bounds: const Rect.fromLTWH(-380, -260, 760, 520)),
    );

    final player = _world.createEntity(name: 'player');
    player.addComponent(TransformComponent());
    player.addComponent(mover);
    player.addComponent(
      RenderableComponent(
        renderable: _makePlayerRenderable(const Color(0xFF66BB6A)),
      ),
    );

    _lookaheadBehavior = LookaheadBehavior(
      targetPosition: mover.position,
      targetVelocity: mover.velocity,
      lookaheadDistance: 120,
      maxSpeed: 300,
    );
    _engine.cameraSystem.addBehavior(_lookaheadBehavior!);
    _statusMessage = 'Camera looks ahead in the direction of travel';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Multi-Target
  // ─────────────────────────────────────────────────────────────────────────

  void _buildMultiTarget() {
    final bounds = const Rect.fromLTWH(-400, -280, 800, 560);
    final rng = math.Random(42);
    final colors = [
      const Color(0xFF29B6F6),
      const Color(0xFFAB47BC),
      const Color(0xFFFF7043),
    ];

    _world.addSystem(_MoveSystem(bounds: bounds));

    final targets = <Offset>[];
    for (int i = 0; i < 3; i++) {
      final speed = 100.0 + rng.nextDouble() * 140;
      final angle = rng.nextDouble() * math.pi * 2;
      final mover = _MoveComponent(
        position: Offset(
          (rng.nextDouble() - 0.5) * 300,
          (rng.nextDouble() - 0.5) * 200,
        ),
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
      );
      _movers.add(mover);
      targets.add(mover.position);

      final entity = _world.createEntity();
      entity.addComponent(TransformComponent(position: mover.position));
      entity.addComponent(mover);
      entity.addComponent(
        RenderableComponent(renderable: _makePlayerRenderable(colors[i])),
      );
    }

    _multiTargetBehavior = MultiTargetBehavior(
      targets: targets,
      padding: 100,
      minZoom: 0.35,
      maxZoom: 2.0,
    );
    _engine.cameraSystem.addBehavior(_multiTargetBehavior!);
    _statusMessage = 'Camera frames all three targets simultaneously';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Trauma Shake
  // ─────────────────────────────────────────────────────────────────────────

  void _buildShake() {
    // Orbiting objects to make shake visible
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: _makePlayerRenderable(
            [
              const Color(0xFFFF5252),
              const Color(0xFFFFCA28),
              const Color(0xFF69F0AE),
              const Color(0xFF40C4FF),
            ][i],
            radius: 14,
          ),
        ),
        _OrbitTagComponent(
          center: Offset.zero,
          radius: 120,
          speed: 0.7,
          angle: angle,
        ),
      ]);
    }
    _statusMessage = 'Tap buttons to add trauma (shake)';
  }

  void _triggerShake(double trauma) {
    _engine.rendering.camera.addTrauma(trauma);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Camera Path
  // ─────────────────────────────────────────────────────────────────────────

  void _buildPath() {
    // Static objects to fly past
    final positions = [
      const Offset(-350, 0),
      const Offset(-150, -120),
      const Offset(0, 80),
      const Offset(200, -60),
      const Offset(380, 40),
    ];
    final colors = [
      const Color(0xFFFFCA28),
      const Color(0xFF29B6F6),
      const Color(0xFF66BB6A),
      const Color(0xFFAB47BC),
      const Color(0xFFFF7043),
    ];
    for (int i = 0; i < positions.length; i++) {
      _world.createEntityWithComponents([
        TransformComponent(position: positions[i]),
        RenderableComponent(
          renderable: _makePlayerRenderable(colors[i], radius: 20),
        ),
      ]);
    }
    _statusMessage = 'Tap Play to start the path flythrough';
  }

  void _playPath() {
    _engine.cameraSystem.clearBehaviors();
    _engine.rendering.camera.reset();
    _engine.cameraSystem.addBehavior(
      PathBehavior(
        path: CameraPath([
          CameraKeyframe(position: const Offset(-350, 0), zoom: 1.8, time: 0),
          CameraKeyframe(
            position: const Offset(-150, -120),
            zoom: 1.5,
            time: 1.8,
            easing: Curves.easeInOut,
          ),
          CameraKeyframe(
            position: const Offset(0, 80),
            zoom: 1.0,
            time: 3.0,
            easing: Curves.easeIn,
          ),
          CameraKeyframe(
            position: const Offset(200, -60),
            zoom: 1.6,
            time: 4.5,
            easing: Curves.easeInOut,
          ),
          CameraKeyframe(
            position: const Offset(380, 40),
            zoom: 2.0,
            time: 6.0,
            easing: Curves.easeOut,
          ),
          CameraKeyframe(
            position: Offset.zero,
            zoom: 1.0,
            time: 8.0,
            easing: Curves.easeInOut,
          ),
        ]),
        onComplete: () {
          if (mounted) setState(() => _statusMessage = 'Path complete');
        },
      ),
    );
    setState(() => _statusMessage = 'Playing path…');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Room Transition
  // ─────────────────────────────────────────────────────────────────────────

  void _buildRoom() {
    // Room A — left
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -10,
          getBoundsCallback: () => const Rect.fromLTWH(-800, -350, 760, 700),
          onRender: (canvas, _) {
            canvas.drawRect(
              const Rect.fromLTWH(-800, -350, 760, 700),
              Paint()
                ..color = const Color(0xFF0A1A10)
                ..style = PaintingStyle.fill,
            );
            canvas.drawRect(
              const Rect.fromLTWH(-800, -350, 760, 700),
              Paint()
                ..color = const Color(0xFF1B5E20)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            );
            // Room A label
            const tp = TextSpan(
              text: 'Room A',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            );
            final painter = TextPainter(
              text: tp,
              textDirection: TextDirection.ltr,
            )..layout();
            painter.paint(canvas, const Offset(-420, -14));
          },
        ),
      ),
    ]);

    // Room B — right
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -10,
          getBoundsCallback: () => const Rect.fromLTWH(40, -350, 760, 700),
          onRender: (canvas, _) {
            canvas.drawRect(
              const Rect.fromLTWH(40, -350, 760, 700),
              Paint()
                ..color = const Color(0xFF0A0F1A)
                ..style = PaintingStyle.fill,
            );
            canvas.drawRect(
              const Rect.fromLTWH(40, -350, 760, 700),
              Paint()
                ..color = const Color(0xFF1565C0)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            );
            const tp = TextSpan(
              text: 'Room B',
              style: TextStyle(
                color: Color(0xFF42A5F5),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            );
            final painter = TextPainter(
              text: tp,
              textDirection: TextDirection.ltr,
            )..layout();
            painter.paint(canvas, const Offset(260, -14));
          },
        ),
      ),
    ]);

    // Players in each room
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(-420, 0)),
      RenderableComponent(
        renderable: _makePlayerRenderable(const Color(0xFF66BB6A)),
      ),
    ]);
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(420, 0)),
      RenderableComponent(
        renderable: _makePlayerRenderable(const Color(0xFF42A5F5)),
      ),
    ]);

    _roomBehavior = RoomBehavior()
      ..addRoom(
        const CameraRoom(id: 'a', bounds: Rect.fromLTWH(-800, -350, 760, 700)),
      )
      ..addRoom(
        const CameraRoom(id: 'b', bounds: Rect.fromLTWH(40, -350, 760, 700)),
      );
    _engine.cameraSystem.addBehavior(_roomBehavior!);
    _roomBehavior!.activateRoom('a');
    _statusMessage = 'Tap a room button to transition';
  }

  void _activateRoom(String id) {
    _roomBehavior?.activateRoom(id, transitionDuration: 0.65);
    setState(
      () => _statusMessage = 'Transitioning to Room ${id.toUpperCase()}…',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cinematic
  // ─────────────────────────────────────────────────────────────────────────

  void _buildCinematic() {
    // Points of interest
    const pois = [
      (Offset(-350, -150), Color(0xFFFFCA28), 'POI 1'),
      (Offset(-50, 180), Color(0xFF29B6F6), 'POI 2'),
      (Offset(300, -80), Color(0xFFAB47BC), 'POI 3'),
    ];
    for (final (pos, color, label) in pois) {
      _world.createEntityWithComponents([
        TransformComponent(position: pos),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 5,
            getBoundsCallback: () =>
                Rect.fromCenter(center: pos, width: 120, height: 80),
            onRender: (canvas, _) {
              canvas.drawCircle(
                Offset.zero,
                30,
                Paint()
                  ..color = color.withValues(alpha: 0.3)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
              );
              canvas.drawCircle(Offset.zero, 22, Paint()..color = color);
              canvas.drawCircle(
                Offset.zero,
                22,
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.5)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2,
              );
              final tp = TextPainter(
                text: TextSpan(
                  text: label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout();
              tp.paint(canvas, Offset(-tp.width / 2, 28));
            },
          ),
        ),
      ]);
    }
    _statusMessage = 'Tap Play to run the cinematic sequence';
  }

  void _playCinematic() {
    if (_cinematicRunning) return;
    _engine.cameraSystem.clearBehaviors();
    _engine.rendering.camera.reset();
    _cinematicRunning = true;

    // Add letterbox for cinematic feel
    final lb = LetterboxEffect(barHeightFraction: 0.12);
    _engine.rendering.camera.effectManager.clearEffects();
    _engine.rendering.camera.effectManager.addEffect(lb);
    lb.show(0.4);

    _engine.cameraSystem.addBehavior(
      CinematicBehavior(
        sequence: CinematicSequence([
          CinematicKeyframe(
            time: 0,
            position: Offset.zero,
            zoom: 0.8,
            easing: Curves.easeOut,
            onArrive: () => _setStatus('Cinematic started…'),
          ),
          CinematicKeyframe(
            time: 2.0,
            position: const Offset(-350, -150),
            zoom: 1.8,
            easing: Curves.easeInOut,
            onArrive: () => _setStatus('Arriving at POI 1'),
          ),
          CinematicKeyframe(
            time: 4.0,
            position: const Offset(-50, 180),
            zoom: 1.6,
            easing: Curves.easeInOut,
            onArrive: () => _setStatus('Arriving at POI 2'),
          ),
          CinematicKeyframe(
            time: 6.0,
            position: const Offset(300, -80),
            zoom: 2.0,
            easing: Curves.easeIn,
            onArrive: () => _setStatus('Arriving at POI 3'),
          ),
          CinematicKeyframe(
            time: 8.5,
            position: Offset.zero,
            zoom: 1.0,
            easing: Curves.easeOut,
            onArrive: () => _setStatus('Returning to origin…'),
          ),
        ]),
        onComplete: () {
          lb.hide(0.4);
          _cinematicRunning = false;
          _setStatus('Cinematic complete');
        },
      ),
    );
  }

  void _setStatus(String s) {
    if (mounted) setState(() => _statusMessage = s);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Screen Effects
  // ─────────────────────────────────────────────────────────────────────────

  void _buildScreenEffects() {
    // Orbiting decorations
    for (int i = 0; i < 5; i++) {
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: _makePlayerRenderable(
            HSLColor.fromAHSL(1.0, i * 72.0, 0.7, 0.6).toColor(),
            radius: 16,
          ),
        ),
        _OrbitTagComponent(
          center: Offset.zero,
          radius: 100 + i * 30.0,
          speed: 0.5 + i * 0.15,
          angle: i * math.pi * 2 / 5,
        ),
      ]);
    }

    _letterboxEffect = LetterboxEffect(barHeightFraction: 0.1);
    _engine.rendering.camera.effectManager.addEffect(_letterboxEffect!);
    _statusMessage = 'Use buttons to trigger effects';
  }

  void _doFlash(Color color) {
    _engine.rendering.camera.effectManager.addEffect(
      ScreenFadeEffect()..flash(color, holdDuration: 0.08, fadeDuration: 0.35),
    );
  }

  void _toggleLetterbox() {
    if (_letterboxEffect == null) return;
    _letterboxVisible = !_letterboxVisible;
    if (_letterboxVisible) {
      _letterboxEffect!.show(0.4);
    } else {
      _letterboxEffect!.hide(0.4);
    }
    setState(() {});
  }

  void _doFadeIn() {
    _engine.rendering.camera.effectManager.addEffect(
      ScreenFadeEffect(color: Colors.black)..fadeIn(0.5),
    );
  }

  void _doFadeOut() {
    _engine.rendering.camera.effectManager.addEffect(
      ScreenFadeEffect(color: Colors.black)..fadeOut(0.5),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // World Bounds
  // ─────────────────────────────────────────────────────────────────────────

  static const _kWorldBounds = Rect.fromLTWH(-420, -280, 840, 560);

  void _buildWorldBounds() {
    _engine.rendering.camera.worldBounds = _kWorldBounds;
    _engine.rendering.camera.position = const Offset(-200, -100);

    // World boundary visual
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -8,
          getBoundsCallback: () => _kWorldBounds.inflate(10),
          onRender: (canvas, _) {
            canvas.drawRect(
              _kWorldBounds,
              Paint()
                ..color = const Color(0xFF78909C).withValues(alpha: 0.12)
                ..style = PaintingStyle.fill,
            );
            canvas.drawRect(
              _kWorldBounds,
              Paint()
                ..color = const Color(0xFF78909C).withValues(alpha: 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
            // Corner labels
            const labelStyle = TextStyle(
              color: Color(0xFF78909C),
              fontSize: 10,
            );
            final corners = [
              (_kWorldBounds.topLeft + const Offset(4, 4), '←  top-left'),
              (_kWorldBounds.topRight + const Offset(-80, 4), 'top-right  →'),
              (
                _kWorldBounds.bottomLeft + const Offset(4, -14),
                '←  bottom-left',
              ),
              (
                _kWorldBounds.bottomRight + const Offset(-92, -14),
                'bottom-right  →',
              ),
            ];
            for (final (pos, text) in corners) {
              final tp = TextPainter(
                text: TextSpan(text: text, style: labelStyle),
                textDirection: TextDirection.ltr,
              )..layout();
              tp.paint(canvas, pos);
            }
          },
        ),
      ),
    ]);

    // Mover that bounces inside bounds
    final mover = _MoveComponent(
      position: const Offset(-200, -100),
      velocity: const Offset(160, 110),
    );
    _movers.add(mover);
    _world.addSystem(_MoveSystem(bounds: _kWorldBounds));

    _world.createEntityWithComponents([
      TransformComponent(position: mover.position),
      mover,
      RenderableComponent(
        renderable: _makePlayerRenderable(const Color(0xFF78909C)),
      ),
    ]);

    final follow = SpringFollowBehavior(target: mover.position);
    _movers; // tracked by _tickDemoLogic via springFollow path
    // Repurpose springFollow tick logic by adding a follow behavior directly
    _followBehavior = follow;
    _engine.cameraSystem.addBehavior(follow);

    _statusMessage = 'Camera is clamped to the grey world boundary';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Camera stats (live header line)
  // ─────────────────────────────────────────────────────────────────────────

  String get _cameraStatsLine {
    final cam = _engine.rendering.camera;
    final pos = cam.position;
    return 'pos (${pos.dx.toStringAsFixed(0)}, ${pos.dy.toStringAsFixed(0)})'
        '  zoom ${cam.zoom.toStringAsFixed(2)}'
        '  rot ${(cam.rotation * 180 / math.pi).toStringAsFixed(1)}°'
        '  trauma ${(cam.trauma * 100).toStringAsFixed(0)}%';
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
                'CameraSystem  ·  CameraBehavior  ·  CameraEffect',
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
            _cameraStatsLine,
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
      case _Demo.shake:
        return _buildShakeControls();
      case _Demo.path:
        return _buildPathControls();
      case _Demo.room:
        return _buildRoomControls();
      case _Demo.cinematic:
        return _buildCinematicControls();
      case _Demo.screenEffects:
        return _buildEffectsControls();
      case _Demo.worldBounds:
        return _buildBoundsControls();
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Drag to pan  ·  Scroll / pinch to zoom  ·  Camera updates automatically',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        );
    }
  }

  Widget _buildShakeControls() {
    return Row(
      children: [
        const Text(
          'Trauma:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 10),
        for (final (label, amount) in [
          ('Light (0.3)', 0.3),
          ('Medium (0.6)', 0.6),
          ('Heavy (1.0)', 1.0),
        ]) ...[
          _actionButton(
            label,
            const Color(0xFFFF5252),
            () => _triggerShake(amount),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _buildPathControls() {
    return Row(
      children: [
        _actionButton('▶ Play Path', const Color(0xFFFFCA28), _playPath),
        const SizedBox(width: 10),
        const Text(
          'Keyframe easing: Curves.easeInOut',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildRoomControls() {
    return Row(
      children: [
        const Text(
          'Transition to:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 10),
        _actionButton(
          'Room A',
          const Color(0xFF26A69A),
          () => _activateRoom('a'),
        ),
        const SizedBox(width: 6),
        _actionButton(
          'Room B',
          const Color(0xFF26A69A),
          () => _activateRoom('b'),
        ),
        const SizedBox(width: 12),
        const Text(
          'duration: 0.65 s',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCinematicControls() {
    return Row(
      children: [
        _actionButton(
          _cinematicRunning ? '⏳ Playing…' : '▶ Play Cinematic',
          const Color(0xFFFF7043),
          _cinematicRunning ? null : _playCinematic,
        ),
        const SizedBox(width: 12),
        const Text(
          'Letterbox + onArrive callbacks',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildEffectsControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _actionButton(
          'Flash White',
          const Color(0xFFEC407A),
          () => _doFlash(Colors.white),
        ),
        _actionButton(
          'Flash Red',
          const Color(0xFFEC407A),
          () => _doFlash(Colors.red),
        ),
        _actionButton('Fade In', const Color(0xFFEC407A), _doFadeIn),
        _actionButton('Fade Out', const Color(0xFFEC407A), _doFadeOut),
        _actionButton(
          _letterboxVisible ? 'Hide Letterbox' : 'Show Letterbox',
          const Color(0xFFEC407A),
          _toggleLetterbox,
        ),
      ],
    );
  }

  Widget _buildBoundsControls() {
    return Row(
      children: [
        const Text(
          'Bounds active:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Text(
          'Rect.fromLTWH(-420, -280, 840, 560)',
          style: const TextStyle(
            color: Color(0xFF78909C),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 12),
        _actionButton(
          'Reset Zoom',
          const Color(0xFF78909C),
          () => _engine.rendering.camera.setZoom(1.0),
        ),
      ],
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
                  'just_game_engine · CameraSystem API',
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

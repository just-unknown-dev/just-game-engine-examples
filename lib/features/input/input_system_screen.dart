import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:just_game_engine_examples/core/di/app_config.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

// ─── Shared state ─────────────────────────────────────────────────────────────

/// Holds a reference to the player entity's [JoystickInputComponent] so the
/// Flutter widget can push touch data into the ECS world every frame.
class _JoystickRef {
  JoystickInputComponent? component;
}

/// Lets the widget read live cooldown data from the player component.
class _PlayerRef {
  _PlayerComponent? component;
}

// ─── Screen widget ────────────────────────────────────────────────────────────

class InputSystemScreen extends StatefulWidget {
  const InputSystemScreen({super.key});

  @override
  State<InputSystemScreen> createState() => _InputSystemScreenState();
}

class _InputSystemScreenState extends State<InputSystemScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  final GlobalKey _gameWidgetKey = GlobalKey();

  Duration _lastTickTime = Duration.zero;
  Size _viewportSize = Size.zero;

  final _JoystickRef _joystickRef = _JoystickRef();
  final _PlayerRef _playerRef = _PlayerRef();
  bool _dashPressed = false;

  JoystickVariant _joystickVariant = JoystickVariant.floating;
  JoystickAxis _joystickAxis = JoystickAxis.both;

  bool isMobile = getIt<AppConfig>().isMobile;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildShowcase();
    });
  }

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    _engine.input.update();

    // Desktop: bridge Space key → shared dash flag
    if (!isMobile &&
        _engine.input.keyboard.isKeyPressed(LogicalKeyboardKey.space)) {
      _dashPressed = true;
    }

    _engine.world.update(dt);

    // Consume the one-shot dash flag after the world has seen it.
    _dashPressed = false;

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world.destroyAllEntities();
    super.dispose();
  }

  // ─── World setup ───────────────────────────────────────────────────────────

  Size _readViewportSize() {
    final ro = _gameWidgetKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) return ro.size;
    return MediaQuery.sizeOf(context);
  }

  void _clearWorld() {
    for (final s in List<System>.from(_world.systems)) {
      _world.removeSystem(s);
    }
    _world.destroyAllEntities();
  }

  void _rebuildShowcase() {
    _viewportSize = _readViewportSize();
    if (_viewportSize == Size.zero) return;

    _engine.rendering.camera
      ..viewportSize = _viewportSize
      ..position = Offset.zero
      ..rotation = 0
      ..zoom = 1;

    _clearWorld();
    _playerRef.component = null;
    _joystickRef.component = null;
    _dashPressed = false;

    _world.addSystem(
      _PlayerControllerSystem(
        input: _engine.input,
        joystickRef: _joystickRef,
        playerRef: _playerRef,
        isMobile: isMobile,
        getDashPressed: () => _dashPressed,
      )..priority = 90,
    );
    _world.addSystem(_DashTrailSystem()..priority = 80);
    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));

    _createBackdrop();
    _createBoundary();
    _createPlayer();
    _createSceneLabels();
    setState(() {});
  }

  void _createBackdrop() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          onRender: (canvas, size) {
            final paint = Paint()
              ..color = const Color(0xFF1A2040).withValues(alpha: 0.28)
              ..strokeWidth = 1;
            for (double x = -620; x <= 620; x += 60) {
              canvas.drawLine(Offset(x, -520), Offset(x, 520), paint);
            }
            for (double y = -520; y <= 520; y += 60) {
              canvas.drawLine(Offset(-620, y), Offset(620, y), paint);
            }
          },
        ),
      ),
    ], name: 'backdrop');
  }

  static const _halfW = 290.0;
  static const _halfH = 235.0;

  void _createBoundary() {
    const color = Color(0xFF3A5070);
    final corners = [
      const Offset(-_halfW, -_halfH),
      const Offset(_halfW, -_halfH),
      const Offset(_halfW, _halfH),
      const Offset(-_halfW, _halfH),
    ];

    for (int i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      _world.createEntityWithComponents([
        TransformComponent(position: a),
        RenderableComponent(
          renderable: LineRenderable(
            endPoint: b - a,
            color: color,
            width: 2,
            layer: 2,
          ),
        ),
      ], name: 'boundary_$i');
    }

    // Corner dots
    for (final c in corners) {
      _world.createEntityWithComponents([
        TransformComponent(position: c),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: 5,
            fillColor: const Color(0xFF5577AA),
            layer: 3,
          ),
        ),
      ]);
    }
  }

  void _createPlayer() {
    final joystick = JoystickInputComponent(
      layout: _joystickVariant == JoystickVariant.fixed
          ? JoystickInputLayout.fixed
          : JoystickInputLayout.floating,
      axis: switch (_joystickAxis) {
        JoystickAxis.horizontal => JoystickInputAxis.horizontal,
        JoystickAxis.vertical => JoystickInputAxis.vertical,
        JoystickAxis.both => JoystickInputAxis.both,
      },
      radius: 64,
    );
    _joystickRef.component = joystick;
    _world.createEntityWithComponents([
      TransformComponent(position: Offset.zero),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: 20.0,
          fillColor: const Color(0xFF7C4DFF),
          strokeColor: const Color(0xFFEA80FC),
          strokeWidth: 3,
          layer: 10,
        ),
      ),
      _PlayerComponent(speed: 220.0, dashSpeed: 700.0, dashCooldown: 1.5),
      joystick,
    ], name: 'player');
  }

  void _createSceneLabels() {
    final hint = isMobile
        ? 'Drag to move   •   Tap DASH to dash'
        : 'WASD / Arrows to move   •   Space to dash';

    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -_halfH - 30)),
      TextComponent(
        text: hint,
        textStyle: const TextStyle(
          color: Color(0xFFB0BEC5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        layer: 30,
      ),
    ], name: 'hint');
  }

  void _triggerMobileDash() {
    _dashPressed = true;
  }

  // ─── Dash cooldown fraction (0 = ready, 1 = just fired) ───────────────────

  double get _dashCooldownFraction {
    final c = _playerRef.component;
    if (c == null || c.dashCooldown <= 0) return 0.0;
    return (c.dashCooldownTimer / c.dashCooldown).clamp(0.0, 1.0);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Control panel ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xFF0E0C1F),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Input System Showcase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isMobile
                    ? 'Joystick controls movement   •   Dash button for dash'
                    : 'WASD / Arrow Keys to move   •   Space to dash',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (isMobile) ...[
                    const Text(
                      'Joystick',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<JoystickVariant>(
                      segments: const [
                        ButtonSegment(
                          value: JoystickVariant.floating,
                          label: Text('Floating'),
                          icon: Icon(Icons.open_with),
                        ),
                        ButtonSegment(
                          value: JoystickVariant.fixed,
                          label: Text('Fixed'),
                          icon: Icon(Icons.push_pin),
                        ),
                      ],
                      selected: {_joystickVariant},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _joystickVariant = selection.first;
                          _joystickRef.component
                            ?..layout =
                                _joystickVariant == JoystickVariant.fixed
                                ? JoystickInputLayout.fixed
                                : JoystickInputLayout.floating
                            ..reset();
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<JoystickAxis>(
                      segments: const [
                        ButtonSegment(
                          value: JoystickAxis.both,
                          label: Text('XY'),
                        ),
                        ButtonSegment(
                          value: JoystickAxis.horizontal,
                          label: Text('X'),
                        ),
                        ButtonSegment(
                          value: JoystickAxis.vertical,
                          label: Text('Y'),
                        ),
                      ],
                      selected: {_joystickAxis},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _joystickAxis = selection.first;
                          _joystickRef.component
                            ?..axis = switch (_joystickAxis) {
                              JoystickAxis.horizontal =>
                                JoystickInputAxis.horizontal,
                              JoystickAxis.vertical =>
                                JoystickInputAxis.vertical,
                              JoystickAxis.both => JoystickInputAxis.both,
                            }
                            ..reset();
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _rebuildShowcase,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── Viewport + overlays ───────────────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              // Game viewport
              Positioned.fill(
                child: !isMobile
                    ? CameraZoomControls(
                        camera: _engine.rendering.camera,
                        child: GameWidget(
                          key: _gameWidgetKey,
                          engine: _engine,
                          showFPS: true,
                          showDebug: false,
                        ),
                      )
                    : GameWidget(
                        key: _gameWidgetKey,
                        engine: _engine,
                        showFPS: true,
                        showDebug: false,
                      ),
              ),

              if (isMobile)
                Positioned.fill(
                  child: VirtualJoystick(
                    variant: _joystickVariant,
                    axis: _joystickAxis,
                    radius: 64,
                    showWhenInactive: _joystickVariant == JoystickVariant.fixed,
                    inactiveOpacity: _joystickVariant == JoystickVariant.fixed
                        ? 0.55
                        : 0,
                    onDirectionChanged: (direction) {
                      _joystickRef.component?.direction = direction;
                    },
                  ),
                ),

              // Mobile: dash button (bottom-right)
              if (isMobile)
                Positioned(
                  right: 28,
                  bottom: 36,
                  child: _DashButton(
                    cooldownFraction: _dashCooldownFraction,
                    onPressed: _triggerMobileDash,
                  ),
                ),

              // Desktop: WASD key indicator (bottom-left)
              if (!isMobile)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: _WASDHint(
                    input: _engine.input,
                    dashCooldownFraction: _dashCooldownFraction,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── ECS Components ───────────────────────────────────────────────────────────

class _PlayerComponent extends Component {
  _PlayerComponent({
    required this.speed,
    required this.dashSpeed,
    required this.dashCooldown,
  });

  final double speed;
  final double dashSpeed;
  final double dashCooldown;

  // Mutable runtime state
  Offset lastDirection = const Offset(1, 0);
  bool isDashing = false;
  double dashTimer = 0;
  double dashCooldownTimer = 0;

  static const double dashDuration = 0.18;
}

class _DashTrailComponent extends Component {
  _DashTrailComponent({required this.lifetime, required this.renderable});

  final double lifetime;
  final CircleRenderable renderable;
  double age = 0;
}

// ─── ECS Systems ──────────────────────────────────────────────────────────────

class _PlayerControllerSystem extends System {
  _PlayerControllerSystem({
    required this.input,
    required this.joystickRef,
    required this.playerRef,
    required this.isMobile,
    required this.getDashPressed,
  });

  final InputManager input;
  final _JoystickRef joystickRef;
  final _PlayerRef playerRef;
  final bool isMobile;
  final bool Function() getDashPressed;

  static const _playerRadius = 20.0;
  static const _halfW = 290.0;
  static const _halfH = 235.0;
  static const _trailInterval = 0.03;

  double _trailTimer = 0;
  final List<Offset> _pendingTrailSpawns = [];

  @override
  List<Type> get requiredComponents => [TransformComponent, _PlayerComponent];

  @override
  void update(double dt) {
    _pendingTrailSpawns.clear();

    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final player = entity.getComponent<_PlayerComponent>()!;

      // Expose to the widget for UI updates
      playerRef.component = player;

      // ── 1. Movement direction ──────────────────────────────────────────
      final joystick = entity.getComponent<JoystickInputComponent>();
      Offset dir = isMobile && joystick != null
          ? joystick.direction
          : Offset(input.keyboard.horizontal, input.keyboard.vertical);

      if (dir.distance > 1.0) dir = dir / dir.distance;
      if (dir.distance > 0.05) player.lastDirection = dir / dir.distance;

      // ── 2. Cooldown tick ──────────────────────────────────────────────
      if (player.dashCooldownTimer > 0) {
        player.dashCooldownTimer = (player.dashCooldownTimer - dt).clamp(
          0.0,
          player.dashCooldown,
        );
      }

      // ── 3. Trigger dash ───────────────────────────────────────────────
      if (getDashPressed() &&
          player.dashCooldownTimer <= 0 &&
          !player.isDashing) {
        player.isDashing = true;
        player.dashTimer = _PlayerComponent.dashDuration;
        player.dashCooldownTimer = player.dashCooldown;
        _trailTimer = 0;
      }

      // ── 4. Velocity ────────────────────────────────────────────────────
      final Offset velocity;
      if (player.isDashing) {
        player.dashTimer -= dt;
        if (player.dashTimer <= 0) player.isDashing = false;
        velocity = player.lastDirection * player.dashSpeed;

        _trailTimer -= dt;
        if (_trailTimer <= 0) {
          _trailTimer = _trailInterval;
          _pendingTrailSpawns.add(transform.position);
        }
      } else {
        velocity = dir * player.speed;
      }

      // ── 5. Move & clamp to boundary ───────────────────────────────────
      final next = transform.position + velocity * dt;
      transform.position = Offset(
        next.dx.clamp(-_halfW + _playerRadius, _halfW - _playerRadius),
        next.dy.clamp(-_halfH + _playerRadius, _halfH - _playerRadius),
      );
    });

    for (final position in _pendingTrailSpawns) {
      _spawnTrailGhost(position);
    }
  }

  void _spawnTrailGhost(Offset pos) {
    final ghost = CircleRenderable(
      radius: 18.0,
      fillColor: const Color(0xFFEA80FC).withValues(alpha: 0.5),
      layer: 9,
    );
    world.createEntityWithComponents([
      TransformComponent(position: pos),
      RenderableComponent(renderable: ghost),
      _DashTrailComponent(lifetime: 0.32, renderable: ghost),
    ]);
  }
}

class _DashTrailSystem extends System {
  @override
  List<Type> get requiredComponents => [_DashTrailComponent];

  @override
  void update(double dt) {
    final toDestroy = <Entity>[];
    forEach((entity) {
      final trail = entity.getComponent<_DashTrailComponent>()!;
      trail.age += dt;
      final frac = (trail.age / trail.lifetime).clamp(0.0, 1.0);
      trail.renderable.fillColor = const Color(
        0xFFEA80FC,
      ).withValues(alpha: (1.0 - frac) * 0.5);
      if (trail.age >= trail.lifetime) toDestroy.add(entity);
    });
    for (final e in toDestroy) {
      world.destroyEntity(e);
    }
  }
}

// ─── UI Widgets ───────────────────────────────────────────────────────────────

/// Circular dash button with cooldown arc for mobile.
class _DashButton extends StatelessWidget {
  const _DashButton({required this.cooldownFraction, required this.onPressed});

  final double cooldownFraction;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ready = cooldownFraction <= 0;
    return GestureDetector(
      onTap: ready ? onPressed : null,
      child: SizedBox(
        width: 76,
        height: 76,
        child: CustomPaint(
          painter: _DashButtonPainter(cooldownFraction: cooldownFraction),
          child: Center(
            child: Text(
              'DASH',
              style: TextStyle(
                color: ready ? Colors.white : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashButtonPainter extends CustomPainter {
  const _DashButtonPainter({required this.cooldownFraction});

  final double cooldownFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background fill
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.50),
    );

    // Cooldown arc (clockwise from top, shrinks to 0 when ready)
    if (cooldownFraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        -math.pi / 2,
        math.pi * 2 * cooldownFraction,
        false,
        Paint()
          ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.65)
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke,
      );
    }

    // Border
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = cooldownFraction <= 0
            ? const Color(0xFFEA80FC)
            : Colors.white24
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_DashButtonPainter old) =>
      cooldownFraction != old.cooldownFraction;
}

/// Desktop WASD + Space key visual indicator.
class _WASDHint extends StatelessWidget {
  const _WASDHint({required this.input, required this.dashCooldownFraction});

  final InputManager input;
  final double dashCooldownFraction;

  @override
  Widget build(BuildContext context) {
    final kb = input.keyboard;
    final w =
        kb.isKeyDown(LogicalKeyboardKey.keyW) ||
        kb.isKeyDown(LogicalKeyboardKey.arrowUp);
    final a =
        kb.isKeyDown(LogicalKeyboardKey.keyA) ||
        kb.isKeyDown(LogicalKeyboardKey.arrowLeft);
    final s =
        kb.isKeyDown(LogicalKeyboardKey.keyS) ||
        kb.isKeyDown(LogicalKeyboardKey.arrowDown);
    final d =
        kb.isKeyDown(LogicalKeyboardKey.keyD) ||
        kb.isKeyDown(LogicalKeyboardKey.arrowRight);
    final space = kb.isKeyDown(LogicalKeyboardKey.space);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _KeyCap(label: 'W', active: w),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _KeyCap(label: 'A', active: a),
            const SizedBox(width: 4),
            _KeyCap(label: 'S', active: s),
            const SizedBox(width: 4),
            _KeyCap(label: 'D', active: d),
          ],
        ),
        const SizedBox(height: 4),
        _SpaceCap(active: space, cooldownFraction: dashCooldownFraction),
      ],
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF7C4DFF).withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? const Color(0xFFEA80FC) : Colors.white24,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SpaceCap extends StatelessWidget {
  const _SpaceCap({required this.active, required this.cooldownFraction});

  final bool active;
  final double cooldownFraction;

  @override
  Widget build(BuildContext context) {
    final ready = cooldownFraction <= 0;
    return Container(
      width: 112,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF7C4DFF).withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active
              ? const Color(0xFFEA80FC)
              : ready
              ? Colors.white38
              : Colors.white12,
          width: 1.5,
        ),
      ),
      child: Text(
        ready
            ? 'SPACE — DASH'
            : 'DASH ${((1 - cooldownFraction) * 1.5).toStringAsFixed(1)}s',
        style: TextStyle(
          color: ready ? Colors.white70 : Colors.white24,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:just_game_engine_examples/core/di/app_config.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  movement,
  dash,
  joystick,
  keyboard,
  combined;

  String get label => switch (this) {
    movement => 'Movement',
    dash => 'Dash Ability',
    joystick => 'Virtual Joystick',
    keyboard => 'Keyboard State',
    combined => 'Combined',
  };

  IconData get icon => switch (this) {
    movement => Icons.directions_run,
    dash => Icons.flash_on,
    joystick => Icons.sports_esports,
    keyboard => Icons.keyboard,
    combined => Icons.gamepad,
  };

  Color get accentColor => switch (this) {
    movement => const Color(0xFF7C4DFF),
    dash => const Color(0xFFEA80FC),
    joystick => const Color(0xFF26C6DA),
    keyboard => const Color(0xFFFF7043),
    combined => const Color(0xFF29B6F6),
  };

  String get description => switch (this) {
    movement =>
      'Directional movement via keyboard (WASD / Arrows) or virtual joystick. '
          'InputManager normalises both sources into a single Offset direction vector.',
    dash =>
      'One-shot ability using isKeyPressed — fires exactly once per press even when '
          'held. Visual cooldown arc shows time remaining before the next dash.',
    joystick =>
      'VirtualJoystick widget bridges touch input into a JoystickInputComponent. '
          'Supports floating / fixed layout and horizontal, vertical, or both-axis constraints.',
    keyboard =>
      'Live keyboard state: isKeyDown tracks held keys, isKeyPressed fires once per '
          'press. Both are polled deterministically inside the game tick.',
    combined =>
      'All input channels at once: WASD / joystick movement, one-shot dash with '
          'cooldown, and boundary clamping — the full player-controller pattern.',
  };

  String get codeSnippet => switch (this) {
    movement =>
      '// Keyboard axis helpers (-1 / 0 / +1):\n'
          'final dir = Offset(\n'
          '  input.keyboard.horizontal,\n'
          '  input.keyboard.vertical,\n'
          ');\n'
          'if (dir.distance > 1.0) dir /= dir.distance;\n'
          'transform.position += dir * speed * dt;\n\n'
          '// Or normalised joystick direction:\n'
          'final dir = joystick.direction;',
    dash =>
      '// isKeyPressed = true for ONE tick only:\n'
          'if (input.keyboard.isKeyPressed(\n'
          '      LogicalKeyboardKey.space)\n'
          '    && cooldownTimer <= 0\n'
          '    && !isDashing) {\n'
          '  isDashing     = true;\n'
          '  dashTimer     = dashDuration;  // 0.18 s\n'
          '  cooldownTimer = dashCooldown;  // 1.5 s\n'
          '}\n'
          'if (cooldownTimer > 0) cooldownTimer -= dt;',
    joystick =>
      '// ECS component on the player entity:\n'
          'final joystick = JoystickInputComponent(\n'
          '  layout: JoystickInputLayout.floating,\n'
          '  axis:   JoystickInputAxis.both,\n'
          '  radius: 64,\n'
          ');\n\n'
          '// Flutter overlay widget:\n'
          'VirtualJoystick(\n'
          '  variant: JoystickVariant.floating,\n'
          '  onDirectionChanged: (d) {\n'
          '    joystick.direction = d;\n'
          '  },\n'
          ');',
    keyboard =>
      '// Hold — true while key is down:\n'
          'input.keyboard.isKeyDown(\n'
          '    LogicalKeyboardKey.keyW)\n\n'
          '// One-shot — true for exactly 1 tick:\n'
          'input.keyboard.isKeyPressed(\n'
          '    LogicalKeyboardKey.space)\n\n'
          '// Composite axis helpers:\n'
          'input.keyboard.horizontal  // ← -1 / 0 / +1 →\n'
          'input.keyboard.vertical    // ↑ -1 / 0 / +1 ↓',
    combined =>
      '// Prefer joystick on mobile, keyboard on desktop:\n'
          'Offset dir = isMobile\n'
          '    ? joystick.direction\n'
          '    : Offset(input.keyboard.horizontal,\n'
          '             input.keyboard.vertical);\n\n'
          '// One-shot dash:\n'
          'if (getDashPressed() && !isDashing\n'
          '    && cooldownTimer <= 0) {\n'
          '  isDashing = true;\n'
          '  dashTimer = _PlayerComponent.dashDuration;\n'
          '  cooldownTimer = dashCooldown;\n'
          '}',
  };

  bool get hasDash => this == dash || this == combined;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared state refs
// ─────────────────────────────────────────────────────────────────────────────

class _JoystickRef {
  JoystickInputComponent? component;
}

class _PlayerRef {
  _PlayerComponent? component;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class InputSystemScreen extends StatefulWidget {
  const InputSystemScreen({super.key});

  @override
  State<InputSystemScreen> createState() => _InputSystemScreenState();
}

class _InputSystemScreenState extends State<InputSystemScreen>
    with SingleTickerProviderStateMixin {
  // ── Engine ───────────────────────────────────────────────────────────────
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final GlobalKey _canvasKey = GlobalKey();

  // ── State ────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.combined;
  String _statusMessage = '';

  // ── Input refs ───────────────────────────────────────────────────────────
  final _JoystickRef _joystickRef = _JoystickRef();
  final _PlayerRef _playerRef = _PlayerRef();
  bool _dashPressed = false;

  // ── Joystick config ──────────────────────────────────────────────────────
  JoystickVariant _joystickVariant = JoystickVariant.floating;
  JoystickAxis _joystickAxis = JoystickAxis.both;

  final bool isMobile = getIt<AppConfig>().isMobile;

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
    _world.destroyAllEntities();
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

    _engine.input.update();

    if (!isMobile &&
        _demo.hasDash &&
        _engine.input.keyboard.isKeyPressed(LogicalKeyboardKey.space)) {
      _dashPressed = true;
    }

    _world.update(dt);
    _dashPressed = false;

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // World management
  // ─────────────────────────────────────────────────────────────────────────

  void _clearWorld() {
    for (final s in List<System>.from(_world.systems)) {
      _world.removeSystem(s);
    }
    _world.destroyAllEntities();
  }

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _dashPressed = false;
    _playerRef.component = null;
    _joystickRef.component = null;
    _lastTick = Duration.zero;
    _clearWorld();
    _engine.rendering.camera.reset();

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
    _createSceneLabel();

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // World entities
  // ─────────────────────────────────────────────────────────────────────────

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
          fillColor: _demo.accentColor.withValues(alpha: 0.9),
          strokeColor: Colors.white.withValues(alpha: 0.8),
          strokeWidth: 3,
          layer: 10,
        ),
      ),
      _PlayerComponent(speed: 220.0, dashSpeed: 700.0, dashCooldown: 1.5),
      joystick,
    ], name: 'player');
  }

  void _createSceneLabel() {
    final hint = isMobile
        ? (_demo.hasDash
              ? 'Drag to move  ·  Tap DASH to dash'
              : 'Drag anywhere to move')
        : (_demo.hasDash
              ? 'WASD / Arrows to move  ·  Space to dash'
              : 'WASD / Arrow Keys to move');
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

  // ─────────────────────────────────────────────────────────────────────────
  // Joystick config helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _setJoystickVariant(JoystickVariant v) {
    setState(() {
      _joystickVariant = v;
      _joystickRef.component
        ?..layout = v == JoystickVariant.fixed
            ? JoystickInputLayout.fixed
            : JoystickInputLayout.floating
        ..reset();
    });
  }

  void _setJoystickAxis(JoystickAxis a) {
    setState(() {
      _joystickAxis = a;
      _joystickRef.component
        ?..axis = switch (a) {
          JoystickAxis.horizontal => JoystickInputAxis.horizontal,
          JoystickAxis.vertical => JoystickInputAxis.vertical,
          JoystickAxis.both => JoystickInputAxis.both,
        }
        ..reset();
    });
  }

  void _triggerMobileDash() => _dashPressed = true;

  // ─────────────────────────────────────────────────────────────────────────
  // Stats
  // ─────────────────────────────────────────────────────────────────────────

  double get _dashCooldownFraction {
    final c = _playerRef.component;
    if (c == null || c.dashCooldown <= 0) return 0.0;
    return (c.dashCooldownTimer / c.dashCooldown).clamp(0.0, 1.0);
  }

  String get _statsLine {
    final c = _playerRef.component;
    final dx = c?.lastDirection.dx.toStringAsFixed(2) ?? '0.00';
    final dy = c?.lastDirection.dy.toStringAsFixed(2) ?? '0.00';
    final dashInfo = _demo.hasDash
        ? (c?.isDashing == true
              ? '  DASHING'
              : '  cd: ${(c?.dashCooldownTimer ?? 0).toStringAsFixed(1)}s')
        : '';
    return 'platform: ${isMobile ? "mobile" : "desktop"}'
        '  dir: ($dx, $dy)$dashInfo';
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
                'InputManager  ·  JoystickInputComponent  ·  VirtualJoystick',
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
    return Stack(
      children: [
        Positioned.fill(
          child: GameWidget(
            key: _canvasKey,
            engine: _engine,
            showFPS: true,
            showDebug: false,
          ),
        ),

        // Mobile: virtual joystick overlay
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

        // Mobile: dash button (bottom-right, only for dash-capable demos)
        if (isMobile && _demo.hasDash)
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
              dashCooldownFraction: _demo.hasDash ? _dashCooldownFraction : 0,
            ),
          ),
      ],
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
      case _Demo.movement:
        return _buildMovementControls();
      case _Demo.dash:
        return _buildDashControls();
      case _Demo.joystick:
        return _buildJoystickControls();
      case _Demo.keyboard:
        return _buildKeyboardControls();
      case _Demo.combined:
        return _buildCombinedControls();
    }
  }

  Widget _buildMovementControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        isMobile
            ? 'Drag anywhere — joystick.direction feeds the player controller'
            : 'WASD or Arrow Keys — input.keyboard.horizontal / .vertical',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }

  Widget _buildDashControls() {
    final cooldown = _playerRef.component?.dashCooldownTimer ?? 0;
    final ready = cooldown <= 0;
    return Row(
      children: [
        if (!isMobile) ...[
          _actionButton(
            ready
                ? '▶ Press Space to Dash'
                : 'Cooldown  ${cooldown.toStringAsFixed(1)} s',
            const Color(0xFFEA80FC),
            null,
          ),
          const SizedBox(width: 12),
        ],
        const Text(
          'duration: 0.18 s  ·  cooldown: 1.5 s  ·  speed: 700 px/s',
          style: TextStyle(
            color: Colors.white30,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildJoystickControls() {
    if (!isMobile) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'VirtualJoystick is a touch overlay — run on mobile to interact. '
          'On desktop the player responds to WASD / Arrow Keys.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Layout:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        _chipButton(
          'Floating',
          const Color(0xFF26C6DA),
          _joystickVariant == JoystickVariant.floating,
          () => _setJoystickVariant(JoystickVariant.floating),
        ),
        _chipButton(
          'Fixed',
          const Color(0xFF26C6DA),
          _joystickVariant == JoystickVariant.fixed,
          () => _setJoystickVariant(JoystickVariant.fixed),
        ),
        const SizedBox(width: 4),
        const Text(
          'Axis:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        _chipButton(
          'XY',
          const Color(0xFF26C6DA),
          _joystickAxis == JoystickAxis.both,
          () => _setJoystickAxis(JoystickAxis.both),
        ),
        _chipButton(
          'X only',
          const Color(0xFF26C6DA),
          _joystickAxis == JoystickAxis.horizontal,
          () => _setJoystickAxis(JoystickAxis.horizontal),
        ),
        _chipButton(
          'Y only',
          const Color(0xFF26C6DA),
          _joystickAxis == JoystickAxis.vertical,
          () => _setJoystickAxis(JoystickAxis.vertical),
        ),
      ],
    );
  }

  Widget _buildKeyboardControls() {
    if (isMobile) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Keyboard input is desktop-only. On mobile, use VirtualJoystick instead.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }
    final kb = _engine.input.keyboard;
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Live state:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 10),
        _KeyCap(label: 'W', active: w),
        const SizedBox(width: 4),
        _KeyCap(label: 'A', active: a),
        const SizedBox(width: 4),
        _KeyCap(label: 'S', active: s),
        const SizedBox(width: 4),
        _KeyCap(label: 'D', active: d),
        const SizedBox(width: 12),
        Text(
          'horizontal: ${kb.horizontal.toStringAsFixed(0)}'
          '  vertical: ${kb.vertical.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Color(0xFFFF7043),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (isMobile) ...[
          const Text(
            'Layout:',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          _chipButton(
            'Floating',
            const Color(0xFF29B6F6),
            _joystickVariant == JoystickVariant.floating,
            () => _setJoystickVariant(JoystickVariant.floating),
          ),
          _chipButton(
            'Fixed',
            const Color(0xFF29B6F6),
            _joystickVariant == JoystickVariant.fixed,
            () => _setJoystickVariant(JoystickVariant.fixed),
          ),
          const SizedBox(width: 4),
        ],
        _actionButton(
          'Reset',
          const Color(0xFF29B6F6),
          () => _buildDemo(_demo),
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

  Widget _chipButton(
    String label,
    Color color,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.22)
              : const Color(0xFF0E1A2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.7)
                : const Color(0xFF1E2E40),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
                  'just_game_engine · InputManager API',
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

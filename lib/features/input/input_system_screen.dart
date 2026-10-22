import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/widgets.dart';
import 'package:just_inputs/just_inputs.dart'
    show OnScreenControlDef, OnScreenKind, StickAxis, StickMode;

import '../../core/di/app_config.dart';
import '../../core/engine/demo_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Input asset
// ─────────────────────────────────────────────────────────────────────────────

/// Every action and binding of this screen lives in this file — there are no
/// bindings in code.
const String _inputAssetPath = 'assets/input/demo.input.json';

/// The action names the demo reads, as the asset names them.
abstract final class _Actions {
  static const String playerMap = 'player';
  static const String move = 'move';
  static const String jump = 'jump';
  static const String fire = 'fire';
  static const String charge = 'charge';
  static const String dash = 'dash';
  static const String pause = 'ui/pause';
}

/// The arena the players move in, in world units around the origin.
const double _halfW = 300.0;
const double _halfH = 200.0;

/// One colour per player slot.
const List<Color> _playerColors = [
  Color(0xFF7C4DFF),
  Color(0xFF26C6DA),
  Color(0xFFFFCA28),
  Color(0xFF66BB6A),
];

/// Where each player slot starts.
const List<Offset> _playerStarts = [
  Offset.zero,
  Offset(140, 0),
  Offset(-140, 0),
  Offset(0, 110),
];

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  actions,
  interactions,
  devices,
  onScreen,
  rebinding,
  players;

  String get label => switch (this) {
    actions => 'Actions & Bindings',
    interactions => 'Tap & Hold',
    devices => 'Devices',
    onScreen => 'On-screen Controls',
    rebinding => 'Rebinding',
    players => 'Local Multiplayer',
  };

  IconData get icon => switch (this) {
    actions => Icons.gamepad,
    interactions => Icons.touch_app,
    devices => Icons.keyboard,
    onScreen => Icons.sports_esports,
    rebinding => Icons.tune,
    players => Icons.group,
  };

  Color get accentColor => switch (this) {
    actions => const Color(0xFF7C4DFF),
    interactions => const Color(0xFFEA80FC),
    devices => const Color(0xFFFF7043),
    onScreen => const Color(0xFF26C6DA),
    rebinding => const Color(0xFFFFCA28),
    players => const Color(0xFF66BB6A),
  };

  String get description => switch (this) {
    actions =>
      'Named actions from assets/input/demo.input.json: move (WASD, arrows, '
          'stick, d-pad, on-screen stick), jump, fire, charge and dash. '
          'InputSystem copies the player map into InputComponent(playerIndex: 0) '
          'and a small System reads it by name. Esc / P / Start toggles '
          'ui/pause — input keeps running while the engine is paused.',
    interactions =>
      'One control, two actions: fire has a tap interaction (performed on a '
          'quick release), charge a hold (performed after 0.6 s). The log '
          'listens to the actions\' onStarted / onPerformed / onCanceled.',
    devices =>
      'The devices under the actions: engine.input.keyboard, mouse '
          '(position, buttons, wheel), touchscreen (every finger), gamepads '
          '(sticks, triggers, buttons) and the on-screen device. The cursor '
          'and fingers are drawn in the world; the wheel sizes the cursor.',
    onScreen =>
      'OnScreenControls draws the asset\'s on-screen stick and buttons; '
          'bindings read them as <OnScreen>/moveStick, <OnScreen>/jump like any '
          'other control, and each finger drives its own control. Using them '
          'switches player 1 to the Touch scheme.',
    rebinding =>
      'rebindRows lists every rebindable binding of player 1\'s scheme (what '
          'RebindList shows), each a RebindButton: click one, then press the '
          'new key or button (Esc cancels). A conflict swaps. Overrides are '
          'saved in the engine cache and come back when the asset loads again.',
    players =>
      'engine.input.players: player 1 is whoever plays first; hold Enter, Ⓐ '
          'or the on-screen JOIN for 0.6 s on a free device to join (up to 4). '
          'Each player\'s entity has InputComponent(playerIndex: n) and reads '
          'only that player\'s devices.',
  };

  String get codeSnippet => switch (this) {
    actions =>
      '// Load the asset once, after engine.initialize():\n'
          'final json = await rootBundle.loadString(\n'
          "    'assets/input/demo.input.json');\n"
          'engine.input.loadAsset(InputActionAsset.parse(json));\n\n'
          "// DefaultSystem.input copies the 'player' map into InputComponent:\n"
          'world.createEntityWithComponents([\n'
          '  TransformComponent(),\n'
          '  InputComponent(playerIndex: 0),\n'
          ']);\n\n'
          '// Gameplay reads actions by name, never devices:\n'
          'final input = entity.getComponent<InputComponent>()!;\n'
          "final Offset move = input.vector('move');\n"
          "if (input.wasPressed('jump')) hop();\n"
          "if (input.wasPressed('dash')) dash(move);\n\n"
          '// Or read an action anywhere — it works while paused:\n'
          "final pause = engine.input.actions.action('ui/pause');\n"
          'if (pause.wasPressedThisFrame()) engine.pause();',
    interactions =>
      '// demo.input.json: two actions on one control —\n'
          '//   "fire":   "interactions": [{"type": "tap",\n'
          '//              "params": {"duration": 0.25}}]\n'
          '//   "charge": "interactions": [{"type": "hold",\n'
          '//              "params": {"duration": 0.6}}]\n\n'
          "if (input.wasPerformed('fire')) shoot();      // quick release\n"
          "if (input.wasPerformed('charge')) shootBig(); // held 0.6 s\n"
          "final charging = input.isDown('charge');      // raw press\n\n"
          '// The phases as callbacks:\n'
          "final charge = engine.input.actions.action('player/charge');\n"
          'final subs = [\n'
          "  charge.onStarted((a) => log('\${a.name} started')),\n"
          "  charge.onPerformed((a) => log('\${a.name} performed')),\n"
          "  charge.onCanceled((a) => log('\${a.name} canceled')),\n"
          '];\n'
          '// dispose(): for (final s in subs) { s.cancel(); }',
    devices =>
      'final input = engine.input;\n'
          'input.keyboard.isDown(PhysicalKeyboardKey.keyW);\n'
          'input.mouse.applied.position;           // view pixels\n'
          'input.mouse.control(MouseControls.leftButton)!.read().dx;\n'
          'input.mouse.applied.scrolled;           // wheel, running total\n'
          'input.touchscreen.touches;              // pointer id → position\n'
          'for (final pad in input.gamepads) {\n'
          '  pad.control(GamepadControls.leftStick)!.read(); // y down\n'
          '}\n'
          'input.lastUsedDevice.value?.displayName; // button prompts\n\n'
          '// Opt-in: opens the gamepad platform channels.\n'
          'await input.attachGamepads();',
    onScreen =>
      "import 'package:just_game_engine/widgets.dart';\n"
          "import 'package:just_inputs/just_inputs.dart' show StickMode;\n\n"
          '// demo.input.json: "onScreen": [{"id": "moveStick",\n'
          '//   "kind": "stick", "mode": "floating", ...}, ...]\n'
          '// bound like any control: "<OnScreen>/moveStick"\n'
          'GameWidget(\n'
          '  engine: engine,\n'
          '  overlay: OnScreenControls(\n'
          '    input: engine.input,\n'
          '    visibility: OnScreenVisibility.always, // default: phones\n'
          '    controls: [ // optional: restyle the asset\'s layout\n'
          '      for (final def in engine.input.asset.onScreen)\n'
          '        def.copyWith(stickMode: StickMode.fixed),\n'
          '    ],\n'
          '  ),\n'
          ');',
    rebinding =>
      "import 'package:just_game_engine/widgets.dart';\n\n"
          'final player = engine.input.players[0]!; // a joined player\n'
          "RebindList(player: player, maps: const ['player']);\n\n"
          '// Or lay the rows out yourself:\n'
          'Column(children: [\n'
          "  for (final row in rebindRows(player, maps: const ['player']))\n"
          '    Row(children: [\n'
          '      Text(row.label),\n'
          '      RebindButton(player: player, bindingId: row.bindingId),\n'
          '    ]),\n'
          ']);\n\n'
          'await player.resetOverrides(); // back to the asset\'s bindings\n'
          '// Saved in the engine cache (CacheInputOverrideStore).',
    players =>
      '// demo.input.json: "players": {"max": 4,\n'
          '//   "joining": "onJoinAction", "joinActions": ["ui/join"]}\n'
          'final players = engine.input.players..start();\n'
          'final subs = [\n'
          '  players.joined.listen((p) => spawnPlayer(p.index)),\n'
          '  players.left.listen((p) => removePlayer(p.index)),\n'
          '];\n'
          'players.joiningEnabled = true; // e.g. false while paused\n\n'
          "// Each entity reads only its player's devices:\n"
          'world.createEntityWithComponents([\n'
          '  TransformComponent(),\n'
          '  InputComponent(playerIndex: 1),\n'
          ']);',
  };

  /// The line drawn above the arena.
  String get hint => switch (this) {
    actions => 'WASD / arrows / stick · Space jump · J fire · Shift dash · Esc pause',
    interactions => 'Tap J (or click) to fire · hold it 0.6 s for a charged shot',
    devices => 'Move the mouse · click · scroll · touch · plug in a gamepad',
    onScreen => 'Drag the stick · press JUMP / FIRE / DASH',
    rebinding => 'Rebind on the right, then try the new controls here',
    players => 'Hold Enter / Ⓐ / JOIN on a free device to join',
  };

  /// The on-screen controls show on every platform (else on phones only).
  bool get onScreenEverywhere => this == onScreen || this == players;

  /// The keyboard prompt pad in the bottom-left corner.
  bool get showsActionPad =>
      this == actions || this == interactions || this == rebinding;
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
  /// Gamepads are attached at most once for the shared engine: attaching
  /// opens platform channels, and the service keeps listening afterwards.
  static bool _gamepadsAttached = false;

  // ── Engine ───────────────────────────────────────────────────────────────
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;
  InputService get _input => _engine.input;
  late final Ticker _ticker;

  /// Bumped every frame. The live readouts listen to it; the rest of the
  /// screen (the game view, the rebind list) does not rebuild.
  final ValueNotifier<int> _frame = ValueNotifier(0);

  static const Set<DefaultSystem> _systems = {
    DefaultSystem.input,
    DefaultSystem.rendering,
  };

  // ── State ────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.actions;
  String _statusMessage = '';
  bool _inputReady = false;
  bool _playersWereStarted = false;
  bool _pauseRequested = false;
  String _gamepadStatus = 'not attached';

  final List<InputSubscription> _subscriptions = [];
  final List<String> _log = [];
  double? _chargeStartedAt;

  /// The player entities, by player index.
  final Map<int, Entity> _playerEntities = {};

  /// The wheel's running total when the devices demo started.
  Offset _wheelBase = Offset.zero;

  // ── On-screen layout options ─────────────────────────────────────────────
  StickMode _stickMode = StickMode.floating;
  StickAxis _stickAxis = StickAxis.both;

  /// Bumped to rebuild the rebind list after a reset.
  int _rebindGeneration = 0;

  final bool _isMobile = getIt<AppConfig>().isMobile;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _buildWorld(_demo);
    unawaited(_installInput());
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    if (_inputReady) {
      // Leave the shared input as it was found: no players of ours.
      final players = _input.players;
      players.joiningEnabled = true;
      players.stop();
      if (_playersWereStarted) players.start();
    }
    DemoEngine.reset(_engine);
    _frame.dispose();
    super.dispose();
  }

  /// Loads the input asset into the shared engine, reads saved bindings,
  /// starts local multiplayer and listens to the actions the HUD logs.
  Future<void> _installInput() async {
    final input = _input;
    try {
      final text = await rootBundle.loadString(_inputAssetPath, cache: false);
      input.loadAsset(InputActionAsset.parse(text));
      // Players' own bindings, saved in the engine cache by a rebind.
      await input.players.preloadOverrides();
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Could not load $_inputAssetPath: $e');
      }
      return;
    }
    if (!mounted) return;

    // Player 1 is whoever plays first (the asset's autoJoinFirst); players
    // from another screen's asset start over with this one.
    final players = input.players;
    _playersWereStarted = players.isStarted;
    if (_playersWereStarted) players.stop();
    players.start();
    // The manager joins player 1 when the last-used device *changes*; one
    // used before this screen opened would never change, so it joins now.
    final last = input.lastUsedDevice.value;
    if (last != null && last.connected && players.players.isEmpty) {
      players.join([last], ignoreHeld: false);
    }
    _listenToInput();
    _inputReady = true;
    _selectDemo(_demo);
    unawaited(_attachGamepads());
  }

  /// Starts listening to gamepads — once for the shared engine.
  Future<void> _attachGamepads() async {
    if (_gamepadsAttached) {
      _gamepadStatus = 'attached';
      return;
    }
    _gamepadsAttached = true;
    _gamepadStatus = 'attaching…';
    try {
      await _input.attachGamepads();
      _gamepadStatus = 'attached';
    } catch (e) {
      _gamepadStatus = 'unavailable';
      debugPrint('Gamepads unavailable: $e');
    }
  }

  void _listenToInput() {
    // The shared actions read every device, whoever is playing.
    final actions = _input.actions;
    final pause = actions.tryAction(_Actions.pause);
    if (pause != null) {
      // Toggled from the screen's ticker, outside the input update.
      _subscriptions.add(pause.onPerformed((_) => _pauseRequested = true));
    }
    for (final name in const [_Actions.fire, _Actions.charge]) {
      final action = actions.tryAction('${_Actions.playerMap}/$name');
      if (action == null) continue;
      _subscriptions
        ..add(action.onStarted((a) => _logPhase(a, 'started')))
        ..add(action.onPerformed((a) => _logPhase(a, 'performed')))
        ..add(action.onCanceled((a) => _logPhase(a, 'canceled')));
    }
    final players = _input.players;
    _subscriptions
      ..add(players.joined.listen((p) => _note('${p.label} joined · ${_schemeOf(p)}')))
      ..add(players.left.listen((p) => _note('${p.label} left')))
      ..add(
        players.schemeChanged.listen(
          (p) => _note('${p.label} switched to ${_schemeOf(p)}'),
        ),
      );
  }

  void _logPhase(InputAction action, String phase) {
    if (action.name == _Actions.charge && phase == 'started') {
      _chargeStartedAt = _input.time;
    }
    final control = action.activeControl;
    final via = control == null ? '' : '  ${_labelOf(control)}';
    _log.insert(
      0,
      '${_input.time.toStringAsFixed(2).padLeft(7)}s  '
      '${action.name.padRight(7)}${phase.padRight(10)}$via',
    );
    if (_log.length > 9) _log.removeLast();
  }

  void _note(String message) => _statusMessage = message;

  // ─────────────────────────────────────────────────────────────────────────
  // Tick — the engine drives the world; this only refreshes the HUD.
  // ─────────────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_pauseRequested) {
      _pauseRequested = false;
      _togglePause();
    }
    _fitCamera();
    if (_demo == _Demo.players && _inputReady) _syncPlayerEntities();
    _frame.value++;
  }

  void _togglePause() {
    if (_engine.isPaused) {
      _engine.resume();
    } else if (_engine.isRunning) {
      _engine.pause();
    }
  }

  /// Zooms the camera so the whole arena fits the view.
  void _fitCamera() {
    final camera = _engine.cameraSystem.mainCamera;
    final view = camera.viewportSize;
    if (view.isEmpty) return;
    final fit = math.min(
      view.width / (_halfW * 2 + 40),
      view.height / (_halfH * 2 + 90),
    );
    final zoom = fit.clamp(0.35, 1.0);
    if ((camera.zoom - zoom).abs() > 0.001) camera.zoom = zoom;
  }

  /// One entity per joined player (player 1's always).
  void _syncPlayerEntities() {
    final joined = {for (final p in _input.players.players) p.index};
    for (final index in joined) {
      if (!_playerEntities.containsKey(index)) _spawnPlayer(index);
    }
    for (final index in [..._playerEntities.keys]) {
      if (index != 0 && !joined.contains(index)) {
        _world.destroyEntity(_playerEntities.remove(index)!);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // World
  // ─────────────────────────────────────────────────────────────────────────

  void _selectDemo(_Demo demo) => setState(() => _buildWorld(demo));

  /// A clean world for [demo]: the default input and rendering systems,
  /// the demo's own two systems, the arena and player 1.
  void _buildWorld(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _playerEntities.clear();
    _chargeStartedAt = null;
    if (demo == _Demo.interactions) _log.clear();

    DemoEngine.reset(_engine, include: _systems);
    _world
      ..addSystem(_PlayerControllerSystem())
      ..addSystem(_FxSystem());

    _createBackdrop();
    _createBoundary();
    _createHint();
    _spawnPlayer(0);
    if (demo == _Demo.devices) {
      _createPointerMarkers();
      _wheelBase = _input.mouse.applied.scrolled;
    }

    if (_inputReady) {
      _input.players.joiningEnabled = demo == _Demo.players;
      // Extra players only play in the multiplayer demo.
      if (demo != _Demo.players) _dropExtraPlayers();
    }
  }

  /// Players 2–4 leave and their devices are free again. The last-used
  /// device is forgotten too: the manager only moves player 1 when that
  /// *changes*, and it may well be a device that just left.
  void _dropExtraPlayers() {
    final players = _input.players;
    var left = false;
    for (final p in players.players) {
      if (p.index == 0) continue;
      players.leave(p);
      left = true;
    }
    if (left) _input.lastUsedDevice.value = null;
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
            for (double x = -660; x <= 660; x += 60) {
              canvas.drawLine(Offset(x, -480), Offset(x, 480), paint);
            }
            for (double y = -480; y <= 480; y += 60) {
              canvas.drawLine(Offset(-660, y), Offset(660, y), paint);
            }
          },
        ),
      ),
    ], name: 'backdrop');
  }

  void _createBoundary() {
    const color = Color(0xFF3A5070);
    const corners = [
      Offset(-_halfW, -_halfH),
      Offset(_halfW, -_halfH),
      Offset(_halfW, _halfH),
      Offset(-_halfW, _halfH),
    ];
    for (int i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      _world.createEntityWithComponents([
        TransformComponent(position: Vector3.fromOffset(a)),
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
        TransformComponent(position: Vector3.fromOffset(c)),
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

  void _createHint() {
    _world.createEntityWithComponents([
      TransformComponent(
        position: Vector3.fromOffset(const Offset(0, -_halfH - 24)),
      ),
      RenderableComponent(
        renderable: TextRenderable(
          text: _demo.hint,
          textStyle: const TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          layer: 30,
        ),
      ),
    ], name: 'hint');
  }

  /// A player entity: [InputComponent] says whose input it reads, and the
  /// default InputSystem fills it every step.
  Entity _spawnPlayer(int index) {
    final player = _PlayerComponent(
      name: 'P${index + 1}',
      color: index == 0
          ? _demo.accentColor
          : _playerColors[index % _playerColors.length],
    );
    final start = _playerStarts[index % _playerStarts.length];
    final entity = _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(start)),
      InputComponent(playerIndex: index),
      player,
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 10,
          onRender: (canvas, _) => player.paint(canvas),
        ),
      ),
    ], name: 'player_${index + 1}');
    _playerEntities[index] = entity;
    return entity;
  }

  /// The mouse cursor and every finger, drawn where they are in the world.
  void _createPointerMarkers() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: 40,
          onRender: (canvas, _) => _paintPointers(canvas),
        ),
      ),
    ], name: 'pointer_markers');
  }

  void _paintPointers(Canvas canvas) {
    final camera = _engine.cameraSystem.mainCamera;
    final mouse = _input.mouse;
    final state = mouse.applied;
    if (state.position != Offset.zero) {
      final at = camera.screenToWorld(state.position);
      final wheel = (state.scrolled - _wheelBase).dy;
      final radius = (18 - wheel * 0.08).clamp(6.0, 80.0);
      final left = _isHeld(mouse, MouseControls.leftButton);
      final right = _isHeld(mouse, MouseControls.rightButton);
      final middle = _isHeld(mouse, MouseControls.middleButton);
      final color = left
          ? const Color(0xFFFF7043)
          : right
          ? const Color(0xFF29B6F6)
          : middle
          ? const Color(0xFF66BB6A)
          : Colors.white70;
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas
        ..drawCircle(at, radius, stroke)
        ..drawLine(at - Offset(radius + 6, 0), at + Offset(radius + 6, 0), stroke)
        ..drawLine(at - Offset(0, radius + 6), at + Offset(0, radius + 6), stroke);
      if (left || right || middle) {
        canvas.drawCircle(
          at,
          radius * 0.6,
          Paint()..color = color.withValues(alpha: 0.35),
        );
      }
    }
    final finger = Paint()
      ..color = const Color(0xFFFF7043).withValues(alpha: 0.45);
    for (final at in _input.touchscreen.touches.values) {
      canvas.drawCircle(camera.screenToWorld(at), 28, finger);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reading input for the HUD
  // ─────────────────────────────────────────────────────────────────────────

  /// Player 1's actions — or, before anyone has joined, the shared ones.
  InputActions get _hudActions => _input.actionsFor(0) ?? _input.actions;

  /// Turns bindings into prompts for player 1's device (or the last used).
  BindingDisplay _display([InputDevice? device]) => BindingDisplay.forDevice(
    device ?? _input.players[0]?.device ?? _input.lastUsedDevice.value,
    keyboard: _input.keyboard,
    asset: _input.asset,
  );

  String _labelOf(InputControl control) =>
      _display(control.device).control(control.path.toString());

  static bool _isHeld(InputDevice device, String control) =>
      (device.control(control)?.magnitude() ?? 0) >= 0.5;

  /// The controls held on [device] now, as prompts: `W`, `Space`, `Ⓐ`.
  List<String> _heldOn(InputDevice device) {
    final display = _display(device);
    return [
      for (final c in device.controls)
        if (!c.synthetic &&
            !c.continuous &&
            c.path.child == null &&
            c.magnitude() >= 0.5)
          display.control(c.path.toString()),
    ];
  }

  String _schemeOf(PlayerInput p) =>
      p.scheme?.name ?? p.device?.displayName ?? 'any device';

  _PlayerComponent? _player(int index) {
    final entity = _playerEntities[index];
    if (entity == null || !entity.isAlive) return null;
    return entity.getComponent<_PlayerComponent>();
  }

  /// How far the charge hold has come: 0 to 1.
  double get _chargeProgress {
    final charge = _input.actions.tryAction(
      '${_Actions.playerMap}/${_Actions.charge}',
    );
    if (charge == null) return 0;
    final duration =
        (charge.def.interactions.isEmpty
            ? null
            : charge.def.interactions.first.number('duration')) ??
        _input.asset.settings.holdTime;
    return switch (charge.phase) {
      InputActionPhase.performed => 1,
      InputActionPhase.started when _chargeStartedAt != null =>
        ((_input.time - _chargeStartedAt!) / duration).clamp(0.0, 1.0),
      _ => 0,
    };
  }

  String get _statsLine {
    final p1 = _input.players[0];
    final move = _hudActions
            .tryAction('${_Actions.playerMap}/${_Actions.move}')
            ?.readVector2() ??
        Offset.zero;
    final last = _input.lastUsedDevice.value?.displayName ?? '—';
    final who = !_inputReady
        ? 'loading input asset…'
        : p1 == null
        ? 'P1 not joined (shared actions)'
        : 'P1: ${_schemeOf(p1)}';
    return 'platform: ${_isMobile ? "mobile" : "desktop"}  ·  $who'
        '  ·  move ${_fmt(move)}  ·  last used: $last'
        '${_engine.isPaused ? '  ·  PAUSED' : ''}';
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
        // Buttons here must not take the keyboard from the game view.
        ExcludeFocus(child: _buildDemoSelector()),
        ExcludeFocus(child: _buildControlPanel()),
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
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'InputService  ·  InputComponent  ·  OnScreenControls  ·  RebindButton',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF29B6F6), fontSize: 10),
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
          ValueListenableBuilder<int>(
            valueListenable: _frame,
            builder: (context, _, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          Positioned.fill(
            child: GameWidget(
              engine: _engine,
              showFPS: true,
              overlay: _buildOnScreenControls(),
            ),
          ),

          // Live readouts — pointers pass through to the game.
          Positioned(
            left: 8,
            top: 8,
            child: IgnorePointer(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(360, box.maxWidth * 0.62),
                ),
                child: ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, _, _) => _buildHud(),
                ),
              ),
            ),
          ),

          // Paused banner, left of the FPS counter.
          Positioned(
            top: 8,
            right: 76,
            child: IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, _, _) => _engine.isPaused
                    ? _pausedBanner()
                    : const SizedBox.shrink(),
              ),
            ),
          ),

          // Keyboard prompts, lit by the actions.
          if (!_isMobile && _demo.showsActionPad && box.maxHeight >= 340)
            Positioned(
              left: 12,
              bottom: 12,
              child: IgnorePointer(
                child: ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, _, _) => _buildActionPad(),
                ),
              ),
            ),

          // The rebind list: beside the readouts, or over them when narrow.
          if (_demo == _Demo.rebinding)
            Positioned(
              top: 36,
              right: 8,
              bottom: 8,
              width: box.maxWidth < 560 ? box.maxWidth - 16 : 320,
              child: ExcludeFocus(
                child: ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, _, _) => _buildRebindPanel(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The asset's on-screen controls, drawn over the game: on every platform
  /// in the on-screen and multiplayer demos, on phones only elsewhere.
  Widget? _buildOnScreenControls() {
    if (!_inputReady || _demo == _Demo.rebinding) return null;
    final defs = <OnScreenControlDef>[];
    for (final def in _input.asset.onScreen) {
      if (def.id == 'join' && _demo != _Demo.players) continue;
      defs.add(
        def.kind == OnScreenKind.stick
            ? def.copyWith(stickMode: _stickMode, stickAxis: _stickAxis)
            : def,
      );
    }
    return OnScreenControls(
      // A new layout is a fresh set of controls: nothing stays held.
      key: ValueKey('${_demo.name}/${_stickMode.name}/${_stickAxis.name}'),
      input: _input,
      controls: defs,
      visibility: _demo.onScreenEverywhere
          ? OnScreenVisibility.always
          : OnScreenVisibility.touchPlatforms,
      color: _demo.accentColor,
    );
  }

  Widget _pausedBanner() {
    final resume = _display().action(_input.actions, _Actions.pause);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFCA28)),
      ),
      child: Text(
        'PAUSED — input keeps running'
        '${resume.isEmpty ? '' : '  ·  $resume resumes'}',
        style: const TextStyle(
          color: Color(0xFFFFCA28),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── HUD ──────────────────────────────────────────────────────────────────

  static const TextStyle _mono = TextStyle(
    color: Color(0xFFB0C8E0),
    fontSize: 10.5,
    fontFamily: 'monospace',
    height: 1.4,
  );

  Widget _hudPanel(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF060D18).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _demo.accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _demo.accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  Widget _buildHud() {
    if (!_inputReady) {
      return _hudPanel('INPUT', [
        Text(
          _statusMessage.isEmpty ? 'Loading $_inputAssetPath…' : _statusMessage,
          style: _mono,
        ),
      ]);
    }
    return switch (_demo) {
      _Demo.actions => _buildActionsHud(),
      _Demo.interactions => _buildInteractionsHud(),
      _Demo.devices => _buildDevicesHud(),
      _Demo.onScreen => _buildOnScreenHud(),
      _Demo.rebinding => _buildRebindingHud(),
      _Demo.players => _buildPlayersHud(),
    };
  }

  Widget _buildActionsHud() {
    final actions = _hudActions;
    final display = _display();
    final p1 = _input.players[0];
    final rows = <Widget>[];
    for (final map in actions.maps) {
      for (final action in map.actions) {
        rows.add(_actionRow(action, display.action(actions, action.path)));
      }
    }
    return _hudPanel(
      'ACTIONS  ·  ${p1 == null ? 'shared' : '${p1.label} ${_schemeOf(p1)}'}',
      rows,
    );
  }

  Widget _actionRow(InputAction action, String bound) {
    final value = action.type == ActionValueType.vector2
        ? _fmt(action.readVector2())
        : action.readAxis().toStringAsFixed(2);
    return Text.rich(
      TextSpan(
        style: _mono,
        children: [
          TextSpan(text: action.path.padRight(14)),
          TextSpan(
            text: action.phase.name.padRight(10),
            style: TextStyle(color: _phaseColor(action.phase)),
          ),
          TextSpan(
            text: value.padRight(14),
            style: TextStyle(
              color: action.isPressed() ? Colors.white : null,
            ),
          ),
          TextSpan(
            text: bound,
            style: const TextStyle(color: Colors.white38),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildInteractionsHud() {
    final progress = _chargeProgress;
    final actions = _input.actions;
    final fire = actions.tryAction('${_Actions.playerMap}/${_Actions.fire}');
    final charge = actions.tryAction(
      '${_Actions.playerMap}/${_Actions.charge}',
    );
    return _hudPanel('TAP & HOLD  ·  phases', [
      if (fire != null) _actionRow(fire, 'tap ≤ 0.25 s'),
      if (charge != null) _actionRow(charge, 'hold 0.6 s'),
      const SizedBox(height: 6),
      Row(
        children: [
          const Text('charge ', style: _mono),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white10,
                color: progress >= 1
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFFFFCA28),
              ),
            ),
          ),
          Text(' ${(progress * 100).round()}%', style: _mono),
        ],
      ),
      const SizedBox(height: 6),
      if (_log.isEmpty)
        const Text('(press J, click, Ⓧ or FIRE)', style: _mono)
      else
        for (final line in _log)
          Text(line, style: _mono, maxLines: 1, overflow: TextOverflow.clip),
    ]);
  }

  Widget _buildDevicesHud() {
    final input = _input;
    final camera = _engine.cameraSystem.mainCamera;
    final mouse = input.mouse;
    final mouseAt = mouse.applied.position;
    final world = camera.screenToWorld(mouseAt);
    String flag(String control) => _isHeld(mouse, control) ? '●' : '○';
    final wheel = (mouse.applied.scrolled - _wheelBase).dy;
    final touches = input.touchscreen.touches;
    final keys = _heldOn(input.keyboard);
    final onScreen = _heldOn(input.onScreen);
    final pads = input.gamepads;
    return _hudPanel('DEVICES  ·  engine.input', [
      Text('keyboard   ${keys.isEmpty ? '—' : keys.join(' ')}', style: _mono),
      Text(
        'mouse      ${_fmt(mouseAt, 0)} px → world ${_fmt(world, 0)}',
        style: _mono,
      ),
      Text(
        '           L${flag(MouseControls.leftButton)} '
        'R${flag(MouseControls.rightButton)} '
        'M${flag(MouseControls.middleButton)}   '
        'wheel Δ ${wheel.toStringAsFixed(0)}',
        style: _mono,
      ),
      Text(
        'touch      ${touches.isEmpty ? '—' : '${touches.length} finger(s) '
                  '${touches.entries.map((e) => '#${e.key} ${_fmt(e.value, 0)}').join(' ')}'}',
        style: _mono,
        maxLines: 2,
      ),
      Text(
        'on-screen  ${onScreen.isEmpty ? '—' : onScreen.join(' ')}',
        style: _mono,
      ),
      Text(
        'gamepads   $_gamepadStatus · ${pads.length} connected',
        style: _mono,
      ),
      for (final pad in pads) ...[
        Text(
          '  ${pad.displayName} (${pad.type.name})',
          style: _mono.copyWith(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '    LS ${_fmt(_vectorOf(pad, GamepadControls.leftStick))}'
          '  RS ${_fmt(_vectorOf(pad, GamepadControls.rightStick))}',
          style: _mono,
        ),
        Text(
          '    LT ${_axisOf(pad, GamepadControls.leftTrigger).toStringAsFixed(2)}'
          '  RT ${_axisOf(pad, GamepadControls.rightTrigger).toStringAsFixed(2)}'
          '  held ${_heldOn(pad).join(' ')}',
          style: _mono,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      Text(
        'last used  ${input.lastUsedDevice.value?.displayName ?? '—'}',
        style: _mono,
      ),
    ]);
  }

  static Offset _vectorOf(InputDevice device, String control) =>
      device.control(control)?.read() ?? Offset.zero;

  static double _axisOf(InputDevice device, String control) =>
      device.control(control)?.read().dx ?? 0;

  Widget _buildOnScreenHud() {
    final actions = _hudActions;
    final move = actions
            .tryAction('${_Actions.playerMap}/${_Actions.move}')
            ?.readVector2() ??
        Offset.zero;
    bool down(String name) =>
        actions.tryAction('${_Actions.playerMap}/$name')?.isPressed() ?? false;
    final held = _heldOn(_input.onScreen);
    final p1 = _input.players[0];
    return _hudPanel('ON-SCREEN  ·  <OnScreen>/…', [
      Text(
        'stick      ${_stickMode.name} · ${_stickAxis.name}'
        '${_stickMode == StickMode.floating ? ' (touch lower-left)' : ''}',
        style: _mono,
      ),
      Text('device     ${held.isEmpty ? '—' : held.join(' ')}', style: _mono),
      Text('move       ${_fmt(move)}', style: _mono),
      Text(
        'jump ${down(_Actions.jump) ? '●' : '○'}   '
        'fire ${down(_Actions.fire) ? '●' : '○'}   '
        'dash ${down(_Actions.dash) ? '●' : '○'}',
        style: _mono,
      ),
      Text(
        'P1 scheme  ${p1 == null ? '—' : _schemeOf(p1)}',
        style: _mono,
      ),
    ]);
  }

  Widget _buildRebindingHud() {
    final p1 = _input.players[0];
    if (p1 == null) {
      return _hudPanel('BOUND NOW', [
        const Text('Press any key or button to join as P1.', style: _mono),
      ]);
    }
    final style = _mono.copyWith(color: Colors.white);
    return _hudPanel('BOUND NOW  ·  ${p1.label} ${_schemeOf(p1)}', [
      for (final name in const [
        _Actions.move,
        _Actions.jump,
        _Actions.fire,
        _Actions.charge,
        _Actions.dash,
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name.padRight(8), style: _mono),
            BindingLabel(
              actions: p1.actions,
              action: '${_Actions.playerMap}/$name',
              style: style,
            ),
          ],
        ),
      const SizedBox(height: 4),
      Text(
        '${p1.overrides.paths.length} override(s) · '
        '${_input.players.overridesKey(p1.index)}',
        style: _mono.copyWith(color: Colors.white38),
      ),
    ]);
  }

  Widget _buildPlayersHud() {
    final players = _input.players;
    final max = _input.asset.players.maxPlayers;
    return _hudPanel(
      'PLAYERS  ·  ${players.players.length} / $max'
      '${players.canJoin ? '  ·  joining on' : ''}',
      [
        for (var i = 0; i < max; i++) _playerCard(i, players[i]),
      ],
    );
  }

  Widget _playerCard(int index, PlayerInput? player) {
    final color = index == 0
        ? _demo.accentColor
        : _playerColors[index % _playerColors.length];
    final component = _player(index);
    final move = component?.move ?? Offset.zero;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: player == null ? Colors.transparent : color,
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
            child: Text(
              'P${index + 1}',
              style: TextStyle(
                color: player == null ? color : const Color(0xFF101020),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              player == null
                  ? index == 0
                        ? 'press anything to play'
                        : 'hold Enter / Ⓐ / JOIN to join'
                  : '${_schemeOf(player)} · '
                        '${player.devices.map((d) => d.displayName).join(' + ')}'
                        '${player.isLost ? ' · LOST' : ''}  '
                        'move ${_fmt(move, 1)}',
              style: _mono.copyWith(
                color: player == null ? Colors.white38 : Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRebindPanel(BuildContext context) {
    final player = _input.players[0];
    final accent = _demo.accentColor;
    final Widget body;
    if (!_inputReady) {
      body = const Text('Loading the input asset…', style: _mono);
    } else if (player == null) {
      body = const Text(
        'Press any key or button: the first device used joins as P1, and '
        'its scheme decides which bindings are listed.',
        style: _mono,
      );
    } else {
      body = Expanded(
        child: SingleChildScrollView(
          child: Theme(
            data: Theme.of(context).copyWith(
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(56, 30),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: accent.withValues(alpha: 0.6)),
                ),
              ),
              iconButtonTheme: IconButtonThemeData(
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.white70,
                ),
              ),
            ),
            // A new player, scheme or reset is a fresh list.
            child: KeyedSubtree(
              key: ValueKey(
                '${player.index}/${player.scheme?.group}/$_rebindGeneration',
              ),
              child: _rebindList(player, accent),
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF060D18).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            player == null
                ? 'REBIND'
                : 'REBIND  ·  ${player.label} ${_schemeOf(player)}',
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          body,
        ],
      ),
    );
  }

  /// What `RebindList` shows — every rebindable binding of [player]'s
  /// scheme, a composite as its parts — built from `rebindRows` and
  /// `RebindButton` so overridden rows stand out and long prompts wrap.
  Widget _rebindList(PlayerInput player, Color accent) {
    final overrides = player.overrides;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rebindRows(player, maps: const [_Actions.playerMap]))
          Padding(
            key: ValueKey(row.bindingId),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: overrides[row.bindingId] == null
                          ? Colors.white70
                          : accent,
                      fontSize: 12,
                    ),
                  ),
                ),
                Flexible(
                  child: RebindButton(
                    player: player,
                    bindingId: row.bindingId,
                    listeningText: 'Press… (Esc)',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                IconButton(
                  tooltip: 'Default',
                  icon: const Icon(Icons.undo, size: 16),
                  onPressed: overrides[row.bindingId] == null
                      ? null
                      : () => unawaited(
                          player.resetOverrides(bindingId: row.bindingId),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionPad() {
    final actions = _hudActions;
    final display = _display();
    InputAction? action(String name) =>
        actions.tryAction('${_Actions.playerMap}/$name');
    bool down(String name) => action(name)?.isPressed() ?? false;
    String bound(String name) =>
        display.action(actions, '${_Actions.playerMap}/$name');
    final move = action(_Actions.move)?.readVector2() ?? Offset.zero;
    final player = _player(0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _KeyCap(label: '↑', active: move.dy < -0.3),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _KeyCap(label: '←', active: move.dx < -0.3),
                const SizedBox(width: 4),
                _KeyCap(label: '↓', active: move.dy > 0.3),
                const SizedBox(width: 4),
                _KeyCap(label: '→', active: move.dx > 0.3),
              ],
            ),
            const SizedBox(height: 4),
            Text(bound(_Actions.move), style: _mono),
          ],
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActionCap(
              label: 'JUMP',
              binding: bound(_Actions.jump),
              active: down(_Actions.jump),
            ),
            const SizedBox(height: 4),
            _ActionCap(
              label: 'FIRE',
              binding: '${bound(_Actions.fire)} · hold to charge',
              active: down(_Actions.fire),
              fill: _chargeProgress,
            ),
            const SizedBox(height: 4),
            _ActionCap(
              label: 'DASH',
              binding: bound(_Actions.dash),
              active: down(_Actions.dash) || (player?.isDashing ?? false),
              fill: player?.dashCooldownFraction ?? 0,
            ),
          ],
        ),
      ],
    );
  }

  // ── Selector, controls, code ─────────────────────────────────────────────

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
              separatorBuilder: (_, _) => const SizedBox(width: 6),
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
                  onSelected: (_) => _selectDemo(d),
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: ValueListenableBuilder<int>(
        valueListenable: _frame,
        builder: (context, _, _) => _buildDemoControls(),
      ),
    );
  }

  Widget _buildDemoControls() {
    final accent = _demo.accentColor;
    final pauseButton = _actionButton(
      _engine.isPaused ? '▶ Resume' : '❚❚ Pause',
      accent,
      _togglePause,
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: switch (_demo) {
        _Demo.actions => [
          pauseButton,
          _actionButton('Reset', accent, () => _selectDemo(_demo)),
          _note2('ui/pause: Esc · P · Start · II — read while paused'),
        ],
        _Demo.interactions => [
          pauseButton,
          _actionButton('Clear log', accent, () => setState(_log.clear)),
          _note2('J · LMB · Ⓧ · FIRE: tap = shot, hold 0.6 s = charged shot'),
        ],
        _Demo.devices => [
          _actionButton(
            'Reset wheel',
            accent,
            () => _wheelBase = _input.mouse.applied.scrolled,
          ),
          _note2(
            'attachGamepads(): $_gamepadStatus · '
            '${_input.devices.length} devices · '
            '${_input.gamepads.length} gamepad(s)',
          ),
        ],
        _Demo.onScreen => [
          const Text(
            'Stick:',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          for (final mode in StickMode.values)
            _chipButton(
              mode == StickMode.floating ? 'Floating' : 'Fixed',
              accent,
              _stickMode == mode,
              () => setState(() => _stickMode = mode),
            ),
          const SizedBox(width: 4),
          const Text(
            'Axis:',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          for (final axis in StickAxis.values)
            _chipButton(
              switch (axis) {
                StickAxis.both => 'XY',
                StickAxis.horizontal => 'X only',
                StickAxis.vertical => 'Y only',
              },
              accent,
              _stickAxis == axis,
              () => setState(() => _stickAxis = axis),
            ),
        ],
        _Demo.rebinding => [
          _actionButton(
            'Reset all bindings',
            accent,
            _input.players[0] == null ? null : _resetBindings,
          ),
          _note2('click a binding, press the new control · Esc cancels'),
        ],
        _Demo.players => [
          _actionButton(
            'Remove P2–P4',
            accent,
            _input.players.players.length > 1 ? _dropExtraPlayers : null,
          ),
          _note2('join: hold Enter / Ⓐ / JOIN 0.6 s on a free device'),
        ],
      },
    );
  }

  Future<void> _resetBindings() async {
    final player = _input.players[0];
    if (player == null) return;
    await player.resetOverrides();
    if (mounted) setState(() => _rebindGeneration++);
  }

  Widget _note2(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white30,
      fontSize: 11,
      fontFamily: 'monospace',
    ),
  );

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
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'just_game_engine 2.x · input',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white24, fontSize: 9),
                  ),
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmt(Offset v, [int digits = 2]) =>
    '(${v.dx.toStringAsFixed(digits)}, ${v.dy.toStringAsFixed(digits)})';

Color _phaseColor(InputActionPhase phase) => switch (phase) {
  InputActionPhase.disabled => Colors.white24,
  InputActionPhase.waiting => Colors.white38,
  InputActionPhase.started => const Color(0xFFFFCA28),
  InputActionPhase.performed => const Color(0xFF66BB6A),
  InputActionPhase.canceled => const Color(0xFFEF5350),
};

// ─── ECS Components ───────────────────────────────────────────────────────────

/// A player's character: what the controller system moves and draws.
class _PlayerComponent extends Component {
  _PlayerComponent({required this.name, required this.color});

  final String name;
  final Color color;

  static const double radius = 20.0;
  static const double speed = 220.0;
  static const double dashSpeed = 700.0;
  static const double dashDuration = 0.18;
  static const double dashCooldown = 1.2;
  static const double hopDuration = 0.4;

  /// The hold interaction's duration in demo.input.json, for the ring.
  static const double chargeTime = 0.6;

  // Mutable runtime state
  Offset move = Offset.zero;
  Offset facing = const Offset(1, 0);
  double hopTimer = 0;
  double chargeHeld = 0;
  bool isDashing = false;
  double dashTimer = 0;
  double dashCooldownTimer = 0;

  double get chargeProgress => (chargeHeld / chargeTime).clamp(0.0, 1.0);
  double get dashCooldownFraction =>
      (dashCooldownTimer / dashCooldown).clamp(0.0, 1.0);

  late final TextPainter _label = TextPainter(
    text: TextSpan(
      text: name,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = Colors.white.withValues(alpha: 0.8);
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  final Paint _nose = Paint()..color = Colors.white;

  /// Drawn around the entity's position (the canvas is already there).
  void paint(Canvas canvas) {
    final progress = chargeProgress;
    if (progress > 0) {
      _ring.color = progress >= 1
          ? const Color(0xFFFFCA28)
          : Colors.white.withValues(alpha: 0.6);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius + 9),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        _ring,
      );
    }
    _fill.color = color.withValues(alpha: isDashing ? 1.0 : 0.9);
    canvas
      ..drawCircle(Offset.zero, radius, _fill)
      ..drawCircle(Offset.zero, radius, _stroke)
      ..drawCircle(facing * (radius + 7), 5, _nose);
    _label.paint(canvas, Offset(-_label.width / 2, -_label.height / 2));
  }
}

/// A shot or a dash ghost: moves, fades and goes.
class _FxComponent extends Component {
  _FxComponent({
    required this.renderable,
    required this.color,
    required this.lifetime,
    this.velocity = Offset.zero,
  });

  final CircleRenderable renderable;
  final Color color;
  final double lifetime;
  final Offset velocity;
  double age = 0;
}

void _spawnFx(
  World world,
  Offset at, {
  required double radius,
  required Color color,
  required double lifetime,
  Offset velocity = Offset.zero,
  int layer = 9,
}) {
  final renderable = CircleRenderable(
    radius: radius,
    fillColor: color,
    layer: layer,
  );
  world.createEntityWithComponents([
    TransformComponent(position: Vector3.fromOffset(at)),
    RenderableComponent(renderable: renderable),
    _FxComponent(
      renderable: renderable,
      color: color,
      lifetime: lifetime,
      velocity: velocity,
    ),
  ]);
}

// ─── ECS Systems ──────────────────────────────────────────────────────────────

/// Moves each player from the [InputComponent] the default InputSystem
/// fills — by action name, whatever the device or the player.
class _PlayerControllerSystem extends System {
  _PlayerControllerSystem() {
    // After InputSystem (100) has copied this step's actions.
    priority = SystemPriorities.playerControl;
  }

  static const double _trailInterval = 0.03;

  final List<void Function()> _spawns = [];
  double _trailTimer = 0;

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    InputComponent,
    _PlayerComponent,
  ];

  @override
  void update(double deltaTime) {
    final dt = deltaTime;
    _spawns.clear();

    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final input = entity.getComponent<InputComponent>()!;
      final p = entity.getComponent<_PlayerComponent>()!;
      final position = transform.position.toOffset();

      // ── 1. Move: one vector, from any device ────────────────────────────
      var move = input.vector(_Actions.move);
      if (move.distance > 1) move = move / move.distance;
      p.move = move;
      if (move.distance > 0.1) p.facing = move / move.distance;

      // ── 2. Jump: a hop towards the camera ───────────────────────────────
      if (input.wasPressed(_Actions.jump) && p.hopTimer <= 0) {
        p.hopTimer = _PlayerComponent.hopDuration;
      }
      if (p.hopTimer > 0) p.hopTimer = math.max(0, p.hopTimer - dt);
      final lift = p.hopTimer > 0
          ? math.sin(math.pi * (1 - p.hopTimer / _PlayerComponent.hopDuration))
          : 0.0;
      transform.scale.setValues(1 + 0.45 * lift, 1 + 0.45 * lift, 1);

      // ── 3. Fire (tap) and charge (hold) share one control ───────────────
      p.chargeHeld = input.isDown(_Actions.charge) ? p.chargeHeld + dt : 0;
      final muzzle = position + p.facing * (_PlayerComponent.radius + 8);
      final facing = p.facing;
      final color = p.color;
      if (input.wasPerformed(_Actions.fire)) {
        _spawns.add(
          () => _spawnFx(
            world,
            muzzle,
            radius: 5,
            color: color,
            lifetime: 1.4,
            velocity: facing * 620,
            layer: 8,
          ),
        );
      }
      if (input.wasPerformed(_Actions.charge)) {
        _spawns.add(
          () => _spawnFx(
            world,
            muzzle,
            radius: 13,
            color: const Color(0xFFFFCA28),
            lifetime: 1.6,
            velocity: facing * 480,
            layer: 8,
          ),
        );
      }

      // ── 4. Dash: one press, with a cooldown ─────────────────────────────
      if (p.dashCooldownTimer > 0) {
        p.dashCooldownTimer = math.max(0, p.dashCooldownTimer - dt);
      }
      if (input.wasPressed(_Actions.dash) &&
          p.dashCooldownTimer <= 0 &&
          !p.isDashing) {
        p.isDashing = true;
        p.dashTimer = _PlayerComponent.dashDuration;
        p.dashCooldownTimer = _PlayerComponent.dashCooldown;
        _trailTimer = 0;
      }

      final Offset velocity;
      if (p.isDashing) {
        p.dashTimer -= dt;
        if (p.dashTimer <= 0) p.isDashing = false;
        velocity = p.facing * _PlayerComponent.dashSpeed;
        _trailTimer -= dt;
        if (_trailTimer <= 0) {
          _trailTimer = _trailInterval;
          final ghost = p.color.withValues(alpha: 0.5);
          _spawns.add(
            () => _spawnFx(
              world,
              position,
              radius: _PlayerComponent.radius - 2,
              color: ghost,
              lifetime: 0.32,
            ),
          );
        }
      } else {
        velocity = move * _PlayerComponent.speed;
      }

      // ── 5. Move and keep inside the arena ───────────────────────────────
      const r = _PlayerComponent.radius;
      final next = position + velocity * dt;
      transform.position.setValues(
        next.dx.clamp(-_halfW + r, _halfW - r),
        next.dy.clamp(-_halfH + r, _halfH - r),
        0,
      );
    });

    for (final spawn in _spawns) {
      spawn();
    }
  }
}

/// Moves shots, fades shots and dash ghosts, and removes them when done.
class _FxSystem extends System {
  _FxSystem() {
    priority = SystemPriorities.gameplay;
  }

  final List<Entity> _done = [];

  @override
  List<Type> get requiredComponents => const [TransformComponent, _FxComponent];

  @override
  void update(double deltaTime) {
    _done.clear();
    forEach((entity) {
      final fx = entity.getComponent<_FxComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;
      fx.age += deltaTime;
      final position = transform.position;
      if (fx.velocity != Offset.zero) {
        position.setValues(
          position.x + fx.velocity.dx * deltaTime,
          position.y + fx.velocity.dy * deltaTime,
          0,
        );
      }
      final k = (fx.age / fx.lifetime).clamp(0.0, 1.0);
      fx.renderable.fillColor = fx.color.withValues(
        alpha: fx.color.a * (1 - k),
      );
      final outside = position.x.abs() > _halfW || position.y.abs() > _halfH;
      if (fx.age >= fx.lifetime || outside) _done.add(entity);
    });
    for (final entity in _done) {
      world.destroyEntity(entity);
    }
  }
}

// ─── UI Widgets ───────────────────────────────────────────────────────────────

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// An action, the control it is bound to now, and a bar for a cooldown or
/// a charge.
class _ActionCap extends StatelessWidget {
  const _ActionCap({
    required this.label,
    required this.binding,
    required this.active,
    this.fill = 0,
  });

  final String label;
  final String binding;
  final bool active;
  final double fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 24,
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
      child: Stack(
        children: [
          if (fill > 0)
            FractionallySizedBox(
              widthFactor: fill,
              child: Container(
                color: const Color(0xFFFFCA28).withValues(alpha: 0.25),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    binding.isEmpty ? '—' : binding,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

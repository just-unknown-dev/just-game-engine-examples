import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/widgets.dart';

import '../../core/engine/demo_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  follow,
  groupFraming,
  confiner,
  rooms,
  dolly,
  blendList,
  stateDriven,
  impulses,
  outputCamera;

  /// Whether the demo's view comes from virtual cameras and the brain.
  bool get usesBrain => this != outputCamera;

  String get label => switch (this) {
    follow => 'Follow & Framing',
    groupFraming => 'Group Framing',
    confiner => 'Confiner',
    rooms => 'Rooms & Blends',
    dolly => 'Dolly Track',
    blendList => 'Blend List',
    stateDriven => 'State-Driven',
    impulses => 'Impulses & Noise',
    outputCamera => 'Output Camera',
  };

  IconData get icon => switch (this) {
    follow => Icons.track_changes,
    groupFraming => Icons.filter_center_focus,
    confiner => Icons.crop_free,
    rooms => Icons.meeting_room,
    dolly => Icons.route,
    blendList => Icons.movie,
    stateDriven => Icons.account_tree,
    impulses => Icons.vibration,
    outputCamera => Icons.auto_awesome,
  };

  Color get accentColor => switch (this) {
    follow => const Color(0xFF29B6F6),
    groupFraming => const Color(0xFFAB47BC),
    confiner => const Color(0xFF78909C),
    rooms => const Color(0xFF26A69A),
    dolly => const Color(0xFFFFCA28),
    blendList => const Color(0xFFFF7043),
    stateDriven => const Color(0xFF66BB6A),
    impulses => const Color(0xFFFF5252),
    outputCamera => const Color(0xFFEC407A),
  };

  String get description => switch (this) {
    follow =>
      'A shot is an entity: its VirtualCameraComponent follows the entity '
          'named Runner, and CameraFramingComponent holds it in a dead zone '
          '(no motion) inside a soft zone (eased) — both fractions of the '
          'screen — with damping and lookahead.',
    groupFraming =>
      'CameraTargetGroupComponent moves its entity to the weighted centre of '
          'every entity tagged "party"; the shot follows the group and '
          'CameraGroupFramingComponent zooms out as the party spreads.',
    confiner =>
      'CameraConfinerComponent keeps the whole view — not just its centre — '
          'inside the CameraBoundsComponent entity it names. Bounds narrower '
          'than the view are centred instead. Replaces Camera.worldBounds.',
    rooms =>
      'One virtual camera per room, switched on by a CameraTriggerComponent '
          'while the player is inside and confined to its room. The brain '
          'shows the highest priority and blends; a blend rule makes the '
          'pull-back to the overview slower.',
    dolly =>
      'CameraDollyComponent puts the shot on rails: auto-dolly rides to the '
          'point of the track nearest the target; switched off, pathPosition '
          '(0–1 by length) is animated for a scripted move.',
    blendList =>
      'A manager camera: CameraBlendListComponent plays its child shots in '
          'order, holding and blending. Raising its priority over the '
          'gameplay camera starts the cutscene; lowering it hands back.',
    stateDriven =>
      'CameraStateDrivenComponent shows the child camera mapped to the '
          "player's CameraStateComponent.state, blending between them. The "
          'boss shot frames a two-member target group.',
    impulses =>
      'brain.emitImpulse sends a CameraImpulse; every shot with a '
          'CameraImpulseListenerComponent feels it by distance. '
          'CameraNoiseComponent adds continuous handheld motion. Replaces '
          'camera.shake and trauma.',
    outputCamera =>
      'With no virtual camera in the world the brain leaves '
          'engine.cameraSystem.mainCamera alone: pan, zoom and roll it '
          'directly. Its CameraEffectManager runs ScreenFadeEffect and '
          'LetterboxEffect.',
  };

  String get codeSnippet => switch (this) {
    follow =>
      '''
// A shot is an entity: a virtual camera plus stage components.
world.createEntityWithComponents([
  TransformComponent(),
  VirtualCameraComponent(follow: const EntityTarget.name('Runner')),
  CameraFramingComponent(
    deadZoneWidth: 0.15,  // fractions of the screen
    deadZoneHeight: 0.15,
    softZoneWidth: 0.6,
    softZoneHeight: 0.6,
    dampingX: 0.6,        // seconds to close 99% of the gap
    dampingY: 0.6,
    lookaheadTime: 0.3,   // lead along the target's velocity
  ),
], name: 'Follow Cam');

// Target groups, triggers and the brain run in the world:
registerCameraSystems(world, engine.cameraSystem);
// (or DefaultSystem.cameras in registerDefaultSystems)

// Think once per rendered frame: smooth at any frame rate.
engine.cameraSystem.brain.updateMode = CameraUpdateMode.frame;''',
    groupFraming =>
      '''
// The group is a target: its entity sits at the members' centre.
world.createEntityWithComponents([
  TransformComponent(),
  CameraTargetGroupComponent(members: [
    // One tag member frames every entity tagged 'party'.
    CameraGroupMember(
      target: const EntityTarget.tag('party'),
      radius: 40,
    ),
  ]),
], name: 'Party');

world.createEntityWithComponents([
  TransformComponent(),
  VirtualCameraComponent(follow: const EntityTarget.name('Party')),
  CameraFramingComponent(deadZoneWidth: 0, deadZoneHeight: 0,
      dampingX: 0.3, dampingY: 0.3),
  CameraGroupFramingComponent(padding: 0.25, minZoom: 0.3, maxZoom: 1.6),
], name: 'Group Cam');''',
    confiner =>
      '''
// The level's edges: a rectangle centred on its entity.
world.createEntityWithComponents([
  TransformComponent(),
  CameraBoundsComponent(width: 1400, height: 900),
], name: 'Level Bounds');

world.createEntityWithComponents([
  TransformComponent(),
  VirtualCameraComponent(
    follow: const EntityTarget.name('Runner'),
    zoom: 1.2,
  ),
  CameraFramingComponent(dampingX: 0.25, dampingY: 0.25),
  // The whole view stays inside; narrower bounds are centred.
  CameraConfinerComponent(boundsName: 'Level Bounds', damping: 0.1),
], name: 'Main Camera');''',
    rooms =>
      r'''
// One shot per room, on while the player is inside its trigger.
world.createEntityWithComponents([
  TransformComponent(position: Vector3(-560, 0, 0)),
  VirtualCameraComponent(priority: 20, enabled: false, zoom: 1.15,
      follow: const EntityTarget.tag('player')),
  CameraTriggerComponent(width: 880, height: 760), // tag 'player'
  CameraFramingComponent(dampingX: 0.3, dampingY: 0.3),
  CameraConfinerComponent(boundsName: 'Room A'),
], name: 'Room A Cam');

// The brain shows the highest priority and blends between shots.
final brain = engine.cameraSystem.brain;
brain.defaultBlend =
    const CameraBlend(duration: 0.8, curve: Curves.easeInOut);
brain.blendTable = CameraBlendTable(const [
  CameraBlendRule(to: 'Overview', blend: CameraBlend(duration: 1.6)),
]);
brain.onCameraActivated = (from, to) => print('${from?.name} → ${to.name}');''',
    dolly =>
      '''
final dolly = CameraDollyComponent(
  waypoints: const [Offset(-560, 200), Offset(-360, -170),
                    Offset(-40, -230), Offset(240, -40),
                    Offset(440, -200), Offset(620, 140)],
  autoDolly: true,  // ride to the point nearest the target
  damping: 0.4,
);
world.createEntityWithComponents([
  TransformComponent(),
  VirtualCameraComponent(
    follow: const EntityTarget.name('Runner'),
    zoom: 1.25,
  ),
  dolly,
], name: 'Dolly Cam');

// Scripted: switch auto-dolly off and animate the position.
dolly
  ..autoDolly = false
  ..pathPosition = Curves.easeInOut.transform(t); // 0 → 1''',
    blendList =>
      '''
final rig = world.createEntityWithComponents([
  TransformComponent(),
  VirtualCameraComponent(priority: 5), // below 'Gameplay' (10)
  CameraBlendListComponent(steps: [
    CameraBlendStep(child: 'Wide', hold: 1.0),
    CameraBlendStep(child: 'POI 1', blend: 1.4, hold: 1.0),
    CameraBlendStep(child: 'POI 2', blend: 1.4, hold: 1.0),
    CameraBlendStep(child: 'POI 3', blend: 1.4, hold: 1.0),
  ]),
  CameraNoiseComponent(preset: CameraNoisePreset.handheldMild),
], name: 'Cutscene');

// The shots are its children; the brain only sees the manager.
world.createEntityWithComponents([
  TransformComponent(position: Vector3(-350, -150, 0)),
  VirtualCameraComponent(zoom: 1.8, dutch: 0.08),
  ParentComponent(parentId: rig.id),
], name: 'POI 1');

// Play: outrank the gameplay camera; the list starts over.
rig.getComponent<VirtualCameraComponent>()!.priority = 50;''',
    stateDriven =>
      '''
// The game writes a state; the camera follows it.
final hero = world.createEntityWithComponents([
  TransformComponent(),
  TagComponent('player'),
  CameraStateComponent(state: 'explore'),
], name: 'Hero');

final rig = world.createEntityWithComponents([
  TransformComponent(),
  VirtualCameraComponent(),
  CameraStateDrivenComponent(
    source: const EntityTarget.tag('player'),
    states: {'explore': 'Explore Cam', 'aim': 'Aim Cam',
             'boss': 'Boss Cam'},
    defaultChild: 'Explore Cam',
    blend: 0.6,
  ),
], name: 'State Rig');
// + child shots with ParentComponent(parentId: rig.id)

hero.getComponent<CameraStateComponent>()!.state = 'aim';''',
    impulses =>
      '''
// Shots that should feel impulses listen for them.
world.createEntityWithComponents([
  TransformComponent(),
  VirtualCameraComponent(),
  CameraImpulseListenerComponent(gain: 1.0),
  CameraNoiseComponent(preset: CameraNoisePreset.handheldMild),
], name: 'Main Camera');

// Something happened: every listener feels it, by distance.
final brain = engine.cameraSystem.brain;
brain.emitImpulse(CameraImpulse(
  position: const Offset(1100, 0),
  amplitude: 30, duration: 0.6,
  radius: 1400, // nothing felt beyond this
));

// Or emit what an entity is authored with:
brain.emitImpulseFrom(barrel); // its CameraImpulseSourceComponent''',
    outputCamera =>
      '''
// No virtual camera: the brain leaves the output camera alone.
final camera = engine.cameraSystem.mainCamera;
camera.setPosition(const Offset(100, 0)); // immediate
camera.setZoom(1.5);
camera.rotation = 0.2;
camera.zoomToPoint(const Offset(280, -180), 2.0);

// Effects: add once, play again whenever.
final fade = ScreenFadeEffect();
camera.effectManager.addEffect(fade);
fade.flash(Colors.white, holdDuration: 0.08, fadeDuration: 0.3);

final bars = LetterboxEffect(barHeightFraction: 0.12);
camera.effectManager.addEffect(bars);
bars.show(0.4);''',
  };
}

/// How a change of shot eases in the rooms demo.
enum _BlendCurve {
  easeInOut('Ease in-out', Curves.easeInOut),
  linear('Linear', Curves.linear),
  overshoot('Overshoot', Curves.easeOutBack);

  const _BlendCurve(this.label, this.curve);

  final String label;
  final Curve curve;
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS components & systems used across demos
// ─────────────────────────────────────────────────────────────────────────────

/// Moves its entity along a path of time — the demos' targets.
class _PathMover extends Component {
  _PathMover(this.path);

  /// Where the entity is [t] seconds in.
  final Offset Function(double t) path;

  /// Multiplies time; `0` holds the entity still.
  double speed = 1.0;

  double time = 0;
}

/// Puts each [_PathMover] where its path says, once per fixed update.
class _PathMoverSystem extends System {
  @override
  int get priority => SystemPriorities.movement;

  @override
  List<Type> get requiredComponents => const [TransformComponent, _PathMover];

  @override
  void update(double deltaTime) {
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final mover = entity.getComponent<_PathMover>()!;
      mover.time += deltaTime * mover.speed;
      final at = mover.path(mover.time);
      // Captured every step, so the renderer draws the entity between its
      // last two poses — and the brain, in CameraUpdateMode.frame, follows
      // it the same way.
      entity.getComponent<TransformComponent>()!
        ..capturePrevious()
        ..setPositionXY(at.dx, at.dy);
    }
  }
}

/// Runs a demo's scripted logic on the engine's fixed step.
class _ScriptSystem extends System {
  _ScriptSystem(this.onUpdate);

  final void Function(double deltaTime) onUpdate;

  @override
  int get priority => SystemPriorities.gameplay;

  @override
  List<Type> get requiredComponents => const [];

  @override
  void update(double deltaTime) => onUpdate(deltaTime);
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
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;
  late final Ticker _ticker;

  /// Keeps the game view's state while it moves in and out of the camera
  /// controls (director view).
  final GlobalKey _gameKey = GlobalKey();
  Duration _lastHud = Duration.zero;

  Camera get _camera => _engine.cameraSystem.mainCamera;
  CameraBrain get _brain => _engine.cameraSystem.brain;

  // ── State ────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.follow;
  String _statusMessage = '';
  bool _built = false;

  /// `brain.driveOutput = false`: the user pans and zooms the output camera
  /// while the brain keeps evaluating; its live shot is drawn as a frame.
  bool _directorView = false;

  // ── Screen effects: added once per demo, played again and again ─────────
  final ScreenFadeEffect _fade = ScreenFadeEffect();
  final LetterboxEffect _letterbox = LetterboxEffect(barHeightFraction: 0.12);
  bool _letterboxVisible = false;

  // ── Per-demo live handles ─────────────────────────────────────────────────
  Entity? _runner;
  VirtualCameraComponent? _shot;
  CameraFramingComponent? _framing;
  CameraConfinerComponent? _confiner;
  bool _confinerOn = true;
  Entity? _groupEntity;
  CameraTargetGroupComponent? _group;
  CameraGroupFramingComponent? _groupFraming;
  final List<Entity> _partyMembers = [];
  CameraDollyComponent? _dolly;
  DollyPath? _dollyPath;
  double _dollyScript = -1;
  VirtualCameraComponent? _cutscene;
  CameraBlendListComponent? _blendList;
  double _cutsceneTime = -1;
  CameraStateComponent? _heroState;
  CameraImpulseListenerComponent? _listener;
  CameraNoiseComponent? _noise;
  CameraNoisePreset? _noisePreset;
  Entity? _barrel;
  _PathMover? _walker;

  // Rooms: how shots blend.
  double _blendSeconds = 0.8;
  _BlendCurve _blendCurve = _BlendCurve.easeInOut;

  static const double _kDollyScriptSeconds = 6.0;
  static const List<Offset> _kDollyTrack = [
    Offset(-560, 200),
    Offset(-360, -170),
    Offset(-40, -230),
    Offset(240, -40),
    Offset(440, -200),
    Offset(620, 140),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    // After this frame: the screen this one replaces cleans the shared
    // engine in its dispose(), which runs after this initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _engine.rendering.overlayHooks.addIfAbsent(_paintGizmos, order: 100);
      _buildDemo(_demo);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.rendering.overlayHooks.remove(_paintGizmos);
    DemoEngine.reset(_engine);
    _restoreBrain();
    super.dispose();
  }

  /// Puts the shared brain back as the engine made it.
  void _restoreBrain() {
    _brain
      ..reset()
      ..updateMode = CameraUpdateMode.fixed
      ..driveOutput = true
      ..defaultBlend = const CameraBlend()
      ..blendTable = CameraBlendTable()
      ..onCameraActivated = null
      ..soloEntity = null;
  }

  /// Refreshes the live numbers about ten times a second. The engine runs
  /// itself: GameWidget drives the world, the brain and the effects.
  void _onTick(Duration elapsed) {
    if (elapsed - _lastHud < const Duration(milliseconds: 100)) return;
    _lastHud = elapsed;
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo construction
  // ─────────────────────────────────────────────────────────────────────────

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _runner = null;
    _shot = null;
    _framing = null;
    _confiner = null;
    _confinerOn = true;
    _groupEntity = null;
    _group = null;
    _groupFraming = null;
    _partyMembers.clear();
    _dolly = null;
    _dollyPath = null;
    _dollyScript = -1;
    _cutscene = null;
    _blendList = null;
    _cutsceneTime = -1;
    _heroState = null;
    _listener = null;
    _noise = null;
    _noisePreset = null;
    _barrel = null;
    _walker = null;

    DemoEngine.reset(
      _engine,
      include: {DefaultSystem.rendering, DefaultSystem.cameras},
    );
    _restoreBrain();
    _brain
      // Once per rendered frame, following targets between fixed updates.
      ..updateMode = CameraUpdateMode.frame
      ..driveOutput = !(_directorView && demo.usesBrain);

    // The camera reset dropped every effect: add the reusable ones back,
    // put away.
    _camera.effectManager
      ..addEffect(_fade)
      ..addEffect(_letterbox);
    _fade.fadeOut(0);
    _letterbox.hide(0);
    _letterboxVisible = false;

    _world
      ..addSystem(_PathMoverSystem())
      ..addSystem(_ScriptSystem(_scriptUpdate));

    _spawnWorldGrid();

    switch (demo) {
      case _Demo.follow:
        _buildFollow();
      case _Demo.groupFraming:
        _buildGroupFraming();
      case _Demo.confiner:
        _buildConfiner();
      case _Demo.rooms:
        _buildRooms();
      case _Demo.dolly:
        _buildDolly();
      case _Demo.blendList:
        _buildBlendList();
      case _Demo.stateDriven:
        _buildStateDriven();
      case _Demo.impulses:
        _buildImpulses();
      case _Demo.outputCamera:
        _buildOutputCamera();
    }

    _built = true;
    if (mounted) setState(() {});
  }

  /// The demo's scripted logic, on the engine's fixed step.
  void _scriptUpdate(double dt) {
    switch (_demo) {
      case _Demo.dolly:
        _tickDollyScript(dt);
      case _Demo.blendList:
        _tickCutscene(dt);
      default:
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared world: background grid, landmarks and helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _spawnWorldGrid() {
    const extent = Rect.fromLTRB(-1440, -960, 1440, 960);
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          getBoundsCallback: () => extent,
          onRender: (canvas, _) {
            final gridPaint = Paint()
              ..color = const Color(0xFF1A2535)
              ..strokeWidth = 1.0;
            for (var x = extent.left; x <= extent.right; x += 80) {
              canvas.drawLine(
                Offset(x, extent.top),
                Offset(x, extent.bottom),
                gridPaint,
              );
            }
            for (var y = extent.top; y <= extent.bottom; y += 80) {
              canvas.drawLine(
                Offset(extent.left, y),
                Offset(extent.right, y),
                gridPaint,
              );
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

    // Landmarks scattered around the world for visual reference.
    final rng = math.Random(1337);
    const landmarks = [
      (Offset(-320, -200), Color(0xFF37474F), Color(0xFF546E7A)),
      (Offset(280, -180), Color(0xFF1A237E), Color(0xFF3949AB)),
      (Offset(-250, 220), Color(0xFF1B5E20), Color(0xFF2E7D32)),
      (Offset(310, 240), Color(0xFF4A148C), Color(0xFF7B1FA2)),
      (Offset(0, -280), Color(0xFF37474F), Color(0xFF455A64)),
      (Offset(-400, 50), Color(0xFF0D47A1), Color(0xFF1565C0)),
      (Offset(420, 60), Color(0xFF880E4F), Color(0xFFAD1457)),
      (Offset(-820, -300), Color(0xFF004D40), Color(0xFF00796B)),
      (Offset(860, 320), Color(0xFF3E2723), Color(0xFF6D4C41)),
    ];
    for (final (pos, dark, light) in landmarks) {
      final sides = 5 + rng.nextInt(4);
      final size = 28.0 + rng.nextDouble() * 24;
      _world.createEntityWithComponents([
        TransformComponent(position: Vector3(pos.dx, pos.dy, 0)),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: -5,
            // Local bounds, around the entity's own origin.
            getBoundsCallback: () => Rect.fromCenter(
              center: Offset.zero,
              width: size * 3,
              height: size * 3,
            ),
            onRender: (canvas, _) {
              final path = Path();
              for (var i = 0; i < sides; i++) {
                final a = (i / sides) * math.pi * 2 - math.pi / 2;
                final p = Offset(math.cos(a) * size, math.sin(a) * size);
                if (i == 0) {
                  path.moveTo(p.dx, p.dy);
                } else {
                  path.lineTo(p.dx, p.dy);
                }
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

  Renderable _makeBallRenderable(Color color, {double radius = 18}) {
    return CustomRenderable(
      layer: 10,
      getBoundsCallback: () => Rect.fromCenter(
        center: Offset.zero,
        width: radius * 4,
        height: radius * 4,
      ),
      onRender: (canvas, _) {
        canvas.drawCircle(
          Offset.zero,
          radius * 1.6,
          Paint()
            ..color = color.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
        canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
        canvas.drawCircle(
          Offset.zero,
          radius,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.drawCircle(
          Offset.zero,
          radius * 0.25,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      },
    );
  }

  /// A ball at a fixed spot.
  Entity _spawnBall(
    String? name,
    Offset at,
    Color color, {
    double radius = 18,
    List<Component> extra = const [],
  }) {
    return _world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0)),
      RenderableComponent(
        renderable: _makeBallRenderable(color, radius: radius),
      ),
      ...extra,
    ], name: name);
  }

  /// A ball moving along [path].
  Entity _spawnMover(
    String? name,
    Offset Function(double t) path,
    Color color, {
    double radius = 18,
    List<Component> extra = const [],
  }) {
    final start = path(0);
    return _spawnBall(
      name,
      start,
      color,
      radius: radius,
      extra: [_PathMover(path), ...extra],
    );
  }

  /// A world-space label: a TextRenderable on its own entity.
  void _spawnLabel(
    String text,
    Offset at,
    Color color, {
    double fontSize = 13,
  }) {
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0)),
      RenderableComponent(
        renderable: TextRenderable(
          text: text,
          layer: 12,
          textStyle: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ]);
  }

  /// A smooth figure-of-eight style path.
  static Offset Function(double t) _lissajous({
    Offset centre = Offset.zero,
    double ax = 520,
    double ay = 300,
    double fx = 0.55,
    double fy = 1.05,
    double phaseX = 0,
    double phaseY = 0,
  }) {
    return (t) =>
        centre +
        Offset(ax * math.sin(fx * t + phaseX), ay * math.sin(fy * t + phaseY));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Follow & Framing
  // ─────────────────────────────────────────────────────────────────────────

  void _buildFollow() {
    _runner = _spawnMover(
      'Runner',
      _lissajous(ax: 560, ay: 320, fx: 0.55, fy: 1.05),
      const Color(0xFF29B6F6),
    );

    _framing = CameraFramingComponent(
      deadZoneWidth: 0.15,
      deadZoneHeight: 0.15,
      softZoneWidth: 0.6,
      softZoneHeight: 0.6,
      dampingX: 0.6,
      dampingY: 0.6,
    );
    _world.createEntityWithComponents([
      TransformComponent(),
      _shot = VirtualCameraComponent(follow: const EntityTarget.name('Runner')),
      _framing!,
    ], name: 'Follow Cam');
    _statusMessage =
        'Inner box: dead zone (camera still) · outer box: soft zone '
        '(camera eases) · red: the camera keeps up whatever the damping';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Group framing
  // ─────────────────────────────────────────────────────────────────────────

  static const _kPartyColors = [
    Color(0xFF29B6F6),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
  ];

  void _buildGroupFraming() {
    for (var i = 0; i < 3; i++) {
      _addPartyMember();
    }
    _group = CameraTargetGroupComponent(
      members: [
        // One member naming a tag: everyone tagged 'party', however many.
        CameraGroupMember(target: const EntityTarget.tag('party'), radius: 40),
      ],
    );
    _groupEntity = _world.createEntityWithComponents([
      TransformComponent(),
      _group!,
    ], name: 'Party');

    _groupFraming = CameraGroupFramingComponent(
      padding: 0.25,
      minZoom: 0.3,
      maxZoom: 1.6,
    );
    _world.createEntityWithComponents([
      TransformComponent(),
      VirtualCameraComponent(follow: const EntityTarget.name('Party')),
      CameraFramingComponent(
        deadZoneWidth: 0,
        deadZoneHeight: 0,
        dampingX: 0.3,
        dampingY: 0.3,
      ),
      _groupFraming!,
    ], name: 'Group Cam');
    _statusMessage = 'Add or remove members: the tag finds them all';
  }

  void _addPartyMember() {
    final i = _partyMembers.length;
    if (i >= _kPartyColors.length) return;
    final rng = math.Random(42 + i * 7);
    _partyMembers.add(
      _spawnMover(
        'Member ${i + 1}',
        _lissajous(
          centre: Offset(
            (rng.nextDouble() - 0.5) * 500,
            (rng.nextDouble() - 0.5) * 300,
          ),
          ax: 220 + rng.nextDouble() * 380,
          ay: 140 + rng.nextDouble() * 220,
          fx: 0.2 + rng.nextDouble() * 0.5,
          fy: 0.25 + rng.nextDouble() * 0.5,
          phaseX: rng.nextDouble() * math.pi * 2,
          phaseY: rng.nextDouble() * math.pi * 2,
        ),
        _kPartyColors[i],
        extra: [TagComponent('party')],
      ),
    );
  }

  void _removePartyMember() {
    if (_partyMembers.length <= 1) return;
    _world.destroyEntity(_partyMembers.removeLast());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Confiner (was worldBounds)
  // ─────────────────────────────────────────────────────────────────────────

  static const _kLevelBounds = Rect.fromLTWH(-700, -450, 1400, 900);

  void _buildConfiner() {
    // What lies outside the level, shaded, so leaving it shows.
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -15,
          getBoundsCallback: () => _kLevelBounds.inflate(2000),
          onRender: (canvas, _) {
            canvas.drawPath(
              Path()
                ..fillType = PathFillType.evenOdd
                ..addRect(_kLevelBounds.inflate(2000))
                ..addRect(_kLevelBounds),
              Paint()..color = const Color(0xC0140A10),
            );
            canvas.drawRect(
              _kLevelBounds,
              Paint()
                ..color = const Color(0xFF78909C).withValues(alpha: 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            );
          },
        ),
      ),
    ]);
    _spawnLabel(
      'Level Bounds (CameraBoundsComponent)',
      _kLevelBounds.topCenter + const Offset(0, 22),
      const Color(0xFF90A4AE),
    );

    // The level's edges: a rectangle centred on its own entity.
    _world.createEntityWithComponents([
      TransformComponent(
        position: Vector3(_kLevelBounds.center.dx, _kLevelBounds.center.dy, 0),
      ),
      CameraBoundsComponent(
        width: _kLevelBounds.width,
        height: _kLevelBounds.height,
      ),
    ], name: 'Level Bounds');

    _runner = _spawnMover(
      'Runner',
      _lissajous(ax: 640, ay: 410, fx: 0.45, fy: 0.71, phaseY: 0.6),
      const Color(0xFF78909C),
    );

    _confiner = CameraConfinerComponent(
      boundsName: 'Level Bounds',
      damping: 0.1,
    );
    _world.createEntityWithComponents([
      TransformComponent(),
      _shot = VirtualCameraComponent(
        follow: const EntityTarget.name('Runner'),
        zoom: 1.2,
      ),
      CameraFramingComponent(
        deadZoneWidth: 0.05,
        deadZoneHeight: 0.05,
        dampingX: 0.25,
        dampingY: 0.25,
      ),
      _confiner!,
    ], name: 'Main Camera');
    _statusMessage =
        'The view never shows the shaded outside — zoom out past the bounds '
        'and it centres on them';
  }

  void _toggleConfiner() {
    final confiner = _confiner;
    if (confiner == null) return;
    setState(() {
      _confinerOn = !_confinerOn;
      // An empty name confines to nothing.
      confiner.boundsName = _confinerOn ? 'Level Bounds' : '';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Rooms, triggers and blends
  // ─────────────────────────────────────────────────────────────────────────

  static const _kRoomA = Rect.fromLTWH(-1000, -380, 880, 760);
  static const _kRoomB = Rect.fromLTWH(120, -380, 880, 760);

  void _buildRooms() {
    // Corridor between the rooms: no trigger, so the overview shows.
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -11,
          getBoundsCallback: () => const Rect.fromLTRB(-120, -260, 120, 260),
          onRender: (canvas, _) => canvas.drawRect(
            const Rect.fromLTRB(-120, -260, 120, 260),
            Paint()..color = const Color(0xFF141A22),
          ),
        ),
      ),
    ]);
    _spawnLabel('corridor', const Offset(0, -230), Colors.white38);

    _spawnRoom(
      'Room A',
      _kRoomA,
      const Color(0xFF0A1A10),
      const Color(0xFF4CAF50),
    );
    _spawnRoom(
      'Room B',
      _kRoomB,
      const Color(0xFF0A0F1A),
      const Color(0xFF42A5F5),
    );

    // The overview frames both rooms, at any window size: it follows a
    // group of the two bounds entities and fits it.
    _world.createEntityWithComponents([
      TransformComponent(),
      CameraTargetGroupComponent(
        members: [
          CameraGroupMember(
            target: const EntityTarget.name('Room A'),
            radius: 470,
          ),
          CameraGroupMember(
            target: const EntityTarget.name('Room B'),
            radius: 470,
          ),
        ],
      ),
    ], name: 'Level');
    _world.createEntityWithComponents([
      TransformComponent(),
      VirtualCameraComponent(
        priority: 10,
        follow: const EntityTarget.name('Level'),
      ),
      CameraFramingComponent(
        deadZoneWidth: 0,
        deadZoneHeight: 0,
        dampingX: 0,
        dampingY: 0,
      ),
      CameraGroupFramingComponent(
        padding: 0.05,
        minZoom: 0.1,
        maxZoom: 1.0,
        zoomDamping: 0,
      ),
    ], name: 'Overview');

    // The player walks from room to room.
    final player = _spawnMover(
      'Player',
      _lissajous(ax: 820, ay: 230, fx: 0.3, fy: 0.85),
      const Color(0xFFFFCA28),
      extra: [TagComponent('player')],
    );
    _walker = player.getComponent<_PathMover>();

    _applyRoomBlends();
    _brain.onCameraActivated = (from, to) {
      _statusMessage =
          'Cut to ${to.name}'
          '${from == null ? '' : ' from ${from.name}'}';
    };
    _statusMessage = 'Watch the live camera and the blend in the stats';
  }

  void _spawnRoom(String name, Rect rect, Color fill, Color border) {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -10,
          getBoundsCallback: () => rect,
          onRender: (canvas, _) {
            canvas.drawRect(rect, Paint()..color = fill);
            canvas.drawRect(
              rect,
              Paint()
                ..color = border
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            );
          },
        ),
      ),
    ]);
    _spawnLabel(
      '$name  ·  trigger + confiner',
      Offset(rect.center.dx, rect.top + 30),
      border,
      fontSize: 22,
    );

    // The room's edges, for its camera's confiner.
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3(rect.center.dx, rect.center.dy, 0)),
      CameraBoundsComponent(width: rect.width, height: rect.height),
    ], name: name);

    // The room's shot: off until the player is inside its trigger.
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3(rect.center.dx, rect.center.dy, 0)),
      VirtualCameraComponent(
        priority: 20,
        enabled: false,
        zoom: 1.15,
        follow: const EntityTarget.tag('player'),
      ),
      CameraTriggerComponent(width: rect.width, height: rect.height),
      CameraFramingComponent(
        deadZoneWidth: 0.1,
        deadZoneHeight: 0.1,
        dampingX: 0.3,
        dampingY: 0.3,
      ),
      CameraConfinerComponent(boundsName: name),
    ], name: '$name Cam');
  }

  void _applyRoomBlends() {
    final curve = _blendCurve.curve;
    _brain
      ..defaultBlend = CameraBlend(duration: _blendSeconds, curve: curve)
      ..blendTable = CameraBlendTable([
        // Pulling back to the overview takes twice as long.
        CameraBlendRule(
          to: 'Overview',
          blend: CameraBlend(duration: _blendSeconds * 2, curve: curve),
        ),
      ]);
  }

  void _toggleWalk() {
    final walker = _walker;
    if (walker == null) return;
    setState(() => walker.speed = walker.speed == 0 ? 1 : 0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dolly track
  // ─────────────────────────────────────────────────────────────────────────

  void _buildDolly() {
    final track = DollyPath(_kDollyTrack);
    _dollyPath = track;

    // The runner wanders back and forth along the track, and off it.
    _runner = _spawnMover('Runner', (t) {
      final along = 0.5 - 0.5 * math.cos(t * 0.22);
      return track.pointAt(along) + Offset(0, 150 * math.sin(t * 1.1));
    }, const Color(0xFFFFCA28));

    _dolly = CameraDollyComponent(
      waypoints: List.of(_kDollyTrack),
      autoDolly: true,
      damping: 0.4,
    );
    _world.createEntityWithComponents([
      TransformComponent(),
      _shot = VirtualCameraComponent(
        follow: const EntityTarget.name('Runner'),
        zoom: 1.25,
      ),
      _dolly!,
    ], name: 'Dolly Cam');
    _statusMessage =
        'The camera stays on the rails, at the point nearest the runner';
  }

  void _setAutoDolly() {
    final dolly = _dolly;
    if (dolly == null) return;
    setState(() {
      dolly.autoDolly = true;
      _dollyScript = -1;
      _statusMessage = 'Auto-dolly: riding to the point nearest the runner';
    });
  }

  void _playDollyScript() {
    final dolly = _dolly;
    if (dolly == null) return;
    setState(() {
      dolly
        ..autoDolly = false
        ..pathPosition = 0;
      _dollyScript = 0;
      _statusMessage =
          'Scripted: pathPosition 0 → 1 over '
          '${_kDollyScriptSeconds.toStringAsFixed(0)} s';
    });
  }

  void _tickDollyScript(double dt) {
    final dolly = _dolly;
    if (dolly == null || _dollyScript < 0) return;
    _dollyScript += dt;
    final t = (_dollyScript / _kDollyScriptSeconds).clamp(0.0, 1.0);
    dolly.pathPosition = Curves.easeInOut.transform(t);
    if (t >= 1) {
      _dollyScript = -1;
      _statusMessage = 'Scripted move done: held at pathPosition 1.0';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Blend list (cutscene)
  // ─────────────────────────────────────────────────────────────────────────

  void _buildBlendList() {
    const pois = [
      (Offset(-350, -150), Color(0xFFFFCA28), 'POI 1'),
      (Offset(-50, 200), Color(0xFF29B6F6), 'POI 2'),
      (Offset(320, -90), Color(0xFFAB47BC), 'POI 3'),
    ];
    for (final (pos, color, label) in pois) {
      _spawnBall(null, pos, color, radius: 22);
      _spawnLabel(label, pos + const Offset(0, 40), Colors.white70);
    }

    // Gameplay: the hero, and the camera that normally follows it.
    _spawnMover(
      'Hero',
      (t) => Offset(200 * math.cos(t * 0.6), 40 + 140 * math.sin(t * 0.6)),
      const Color(0xFF66BB6A),
    );
    _world.createEntityWithComponents([
      TransformComponent(),
      VirtualCameraComponent(
        priority: 10,
        follow: const EntityTarget.name('Hero'),
      ),
      CameraFramingComponent(dampingX: 0.4, dampingY: 0.4),
    ], name: 'Gameplay');

    // The cutscene: a manager whose shots are its children. Its own
    // stages — handheld noise here — apply to whichever child shows.
    _blendList = CameraBlendListComponent(
      steps: [
        CameraBlendStep(child: 'Wide', hold: 1.0),
        CameraBlendStep(child: 'POI 1', blend: 1.4, hold: 1.0),
        CameraBlendStep(child: 'POI 2', blend: 1.4, hold: 1.0),
        CameraBlendStep(child: 'POI 3', blend: 1.4, hold: 1.0),
        CameraBlendStep(child: 'Wide', blend: 1.2, hold: 0.6),
      ],
    );
    final rig = _world.createEntityWithComponents([
      TransformComponent(),
      _cutscene = VirtualCameraComponent(priority: 5),
      _blendList!,
      CameraNoiseComponent(preset: CameraNoisePreset.handheldMild),
    ], name: 'Cutscene');

    void child(String name, Offset at, double zoom, {double dutch = 0}) {
      _world.createEntityWithComponents([
        TransformComponent(position: Vector3(at.dx, at.dy, 0)),
        VirtualCameraComponent(zoom: zoom, dutch: dutch),
        ParentComponent(parentId: rig.id),
      ], name: name);
    }

    child('Wide', Offset.zero, 0.55);
    child('POI 1', pois[0].$1, 1.8, dutch: 0.08);
    child('POI 2', pois[1].$1, 1.6);
    child('POI 3', pois[2].$1, 2.0, dutch: -0.06);

    _brain
      ..defaultBlend = const CameraBlend(duration: 1.0)
      ..blendTable = CameraBlendTable(const [
        // Leaving the cutscene is gentler than entering it.
        CameraBlendRule(from: 'Cutscene', blend: CameraBlend(duration: 1.6)),
      ]);
    _statusMessage = 'Gameplay camera follows the hero — play the cutscene';
  }

  double get _cutsceneLength {
    final steps = _blendList?.steps ?? const <CameraBlendStep>[];
    var total = 0.0;
    for (var i = 0; i < steps.length; i++) {
      total += (i == 0 ? 0 : steps[i].blend) + steps[i].hold;
    }
    return total;
  }

  void _playCutscene() {
    final cutscene = _cutscene;
    if (cutscene == null || _cutsceneTime >= 0) return;
    setState(() {
      // Outranking the gameplay camera makes it live; the list starts over.
      cutscene.priority = 50;
      _cutsceneTime = 0;
      _letterbox.show(0.5);
      _letterboxVisible = true;
      _statusMessage = 'Cutscene: blending in from Gameplay…';
    });
  }

  void _endCutscene() {
    _cutscene?.priority = 5;
    _cutsceneTime = -1;
    _letterbox.hide(0.5);
    _letterboxVisible = false;
    _statusMessage = 'Cutscene over: back to Gameplay';
  }

  void _tickCutscene(double dt) {
    final list = _blendList;
    if (list == null || _cutsceneTime < 0) return;
    _cutsceneTime += dt;
    if (_cutsceneTime >= _cutsceneLength) {
      _endCutscene();
      return;
    }
    var t = _cutsceneTime;
    for (var i = 0; i < list.steps.length; i++) {
      final step = list.steps[i];
      final blend = i == 0 ? 0.0 : step.blend;
      if (t < blend) {
        _statusMessage = 'Step ${i + 1}: blending to ${step.child}';
        return;
      }
      t -= blend;
      if (t < step.hold) {
        _statusMessage = 'Step ${i + 1}: holding ${step.child}';
        return;
      }
      t -= step.hold;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // State-driven camera
  // ─────────────────────────────────────────────────────────────────────────

  static const _kStates = [
    ('explore', 'Explore'),
    ('aim', 'Aim'),
    ('boss', 'Boss fight'),
  ];

  void _buildStateDriven() {
    _heroState = CameraStateComponent(state: 'explore');
    _spawnMover(
      'Hero',
      _lissajous(
        centre: const Offset(-80, 60),
        ax: 380,
        ay: 180,
        fx: 0.4,
        fy: 0.8,
      ),
      const Color(0xFF66BB6A),
      extra: [TagComponent('player'), _heroState!],
    );
    _spawnBall(
      'Boss',
      const Offset(460, -220),
      const Color(0xFFFF5252),
      radius: 34,
    );
    _spawnLabel('Boss', const Offset(460, -160), const Color(0xFFFF8A80));

    // The boss shot frames the hero and the boss together.
    _world.createEntityWithComponents([
      TransformComponent(),
      CameraTargetGroupComponent(
        members: [
          CameraGroupMember(
            target: const EntityTarget.tag('player'),
            radius: 60,
          ),
          CameraGroupMember(
            target: const EntityTarget.name('Boss'),
            radius: 90,
          ),
        ],
      ),
    ], name: 'Duel');

    final rig = _world.createEntityWithComponents([
      TransformComponent(),
      VirtualCameraComponent(),
      CameraStateDrivenComponent(
        source: const EntityTarget.tag('player'),
        states: {
          'explore': 'Explore Cam',
          'aim': 'Aim Cam',
          'boss': 'Boss Cam',
        },
        defaultChild: 'Explore Cam',
        blend: 0.6,
      ),
    ], name: 'State Rig');

    void child(String name, List<Component> components) {
      _world.createEntityWithComponents([
        TransformComponent(),
        ...components,
        ParentComponent(parentId: rig.id),
      ], name: name);
    }

    child('Explore Cam', [
      VirtualCameraComponent(
        follow: const EntityTarget.tag('player'),
        zoom: 0.7,
      ),
      CameraFramingComponent(deadZoneWidth: 0.2, deadZoneHeight: 0.2),
    ]);
    child('Aim Cam', [
      VirtualCameraComponent(
        follow: const EntityTarget.tag('player'),
        zoom: 1.6,
      ),
      // Over the shoulder: the hero sits left of centre.
      CameraFramingComponent(
        screenX: -0.2,
        deadZoneWidth: 0.04,
        deadZoneHeight: 0.04,
        dampingX: 0.15,
        dampingY: 0.15,
      ),
    ]);
    child('Boss Cam', [
      VirtualCameraComponent(follow: const EntityTarget.name('Duel')),
      CameraFramingComponent(
        deadZoneWidth: 0,
        deadZoneHeight: 0,
        dampingX: 0.35,
        dampingY: 0.35,
      ),
      CameraGroupFramingComponent(padding: 0.3, minZoom: 0.3, maxZoom: 1.4),
    ]);
    _statusMessage = "state = 'explore' → Explore Cam";
  }

  void _setHeroState(String state) {
    final hero = _heroState;
    if (hero == null) return;
    setState(() {
      hero.state = state;
      const shots = {
        'explore': 'Explore Cam',
        'aim': 'Aim Cam',
        'boss': 'Boss Cam',
      };
      _statusMessage = "state = '$state' → ${shots[state]}";
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Impulses & noise (was shake / trauma)
  // ─────────────────────────────────────────────────────────────────────────

  void _buildImpulses() {
    const colors = [
      Color(0xFFFF5252),
      Color(0xFFFFCA28),
      Color(0xFF69F0AE),
      Color(0xFF40C4FF),
    ];
    for (var i = 0; i < colors.length; i++) {
      final phase = i * math.pi / 2;
      _spawnMover(
        null,
        (t) => Offset(
          130 * math.cos(t * 0.7 + phase),
          130 * math.sin(t * 0.7 + phase),
        ),
        colors[i],
        radius: 14,
      );
    }

    // A barrel authored with the impulse it makes when it goes off.
    _barrel = _spawnBall(
      'Barrel',
      const Offset(300, 170),
      const Color(0xFFFF9800),
      radius: 24,
      extra: [
        CameraImpulseSourceComponent(
          amplitude: 24,
          duration: 0.6,
          radius: 1500,
        ),
      ],
    );
    _spawnLabel('Barrel', const Offset(300, 216), const Color(0xFFFFB74D));
    _spawnLabel(
      'distant blast at (1100, 0) →',
      const Offset(400, -80),
      Colors.white38,
    );

    _listener = CameraImpulseListenerComponent();
    _noise = CameraNoiseComponent(
      preset: CameraNoisePreset.handheldMild,
      amplitudeGain: 0,
    );
    _world.createEntityWithComponents([
      TransformComponent(),
      _shot = VirtualCameraComponent(),
      _listener!,
      _noise!,
    ], name: 'Main Camera');
    _statusMessage = 'Emit impulses, or turn on handheld noise';
  }

  void _emitImpulse(
    double amplitude, {
    double duration = 0.4,
    Offset at = Offset.zero,
    double radius = 0,
    double frequency = 22,
  }) {
    _brain.emitImpulse(
      CameraImpulse(
        position: at,
        amplitude: amplitude,
        duration: duration,
        radius: radius,
        frequency: frequency,
      ),
    );
  }

  void _detonateBarrel() {
    final barrel = _barrel;
    if (barrel == null) return;
    if (_brain.emitImpulseFrom(barrel)) {
      _fade.flash(
        const Color(0xFFFFB74D),
        holdDuration: 0.04,
        fadeDuration: 0.3,
      );
    }
  }

  void _setNoise(CameraNoisePreset? preset) {
    final noise = _noise;
    if (noise == null) return;
    setState(() {
      _noisePreset = preset;
      if (preset == null) {
        // A gain of zero switches the noise off.
        noise.amplitudeGain = 0;
      } else {
        noise
          ..preset = preset
          ..amplitudeGain = 1;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Output camera & screen effects
  // ─────────────────────────────────────────────────────────────────────────

  void _buildOutputCamera() {
    for (var i = 0; i < 5; i++) {
      final radius = 100 + i * 30.0;
      final speed = 0.5 + i * 0.15;
      final phase = i * math.pi * 2 / 5;
      _spawnMover(
        null,
        (t) => Offset(
          radius * math.cos(t * speed + phase),
          radius * math.sin(t * speed + phase),
        ),
        HSLColor.fromAHSL(1.0, i * 72.0, 0.7, 0.6).toColor(),
        radius: 16,
      );
    }
    _statusMessage = 'Drag to pan · scroll / pinch / buttons to zoom';
  }

  void _flash(Color color) =>
      _fade.flash(color, holdDuration: 0.08, fadeDuration: 0.35);

  void _toggleLetterbox() {
    setState(() {
      _letterboxVisible = !_letterboxVisible;
      if (_letterboxVisible) {
        _letterbox.show(0.4);
      } else {
        _letterbox.hide(0.4);
      }
    });
  }

  void _resetOutputView() {
    setState(() {
      // Not camera.reset(): that would also drop the effects.
      _camera
        ..setPosition(Offset.zero)
        ..setZoom(1.0)
        ..rotation = 0;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Director view
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether the user, not the brain, moves the output camera.
  bool get _userOwnsCamera => !_demo.usesBrain || _directorView;

  void _toggleDirectorView() {
    setState(() {
      _directorView = !_directorView;
      // The brain keeps evaluating either way; it just stops writing the
      // output camera.
      _brain.driveOutput = !_directorView;
      if (_directorView) {
        _camera.setZoom(_camera.zoom * 0.6);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Gizmos: drawn in world space through engine.rendering.overlayHooks
  // ─────────────────────────────────────────────────────────────────────────

  void _paintGizmos(Canvas canvas, Size size) {
    if (!_built) return;
    // Overlay hooks are called in screen space, after the engine has put
    // the camera transform back (the world's own hook applies it itself),
    // so the gizmos apply the output camera's transform to draw in world
    // units over the world they annotate.
    canvas.save();
    _camera.applyTransform(canvas, size);
    // One screen pixel, in world units.
    final px = 1 / _camera.zoom;
    switch (_demo) {
      case _Demo.follow:
        _paintFramingZones(canvas, px);
      case _Demo.groupFraming:
        _paintGroupBounds(canvas, px);
      case _Demo.dolly:
        _paintDolly(canvas, px);
      default:
        break;
    }
    if (_directorView && _demo.usesBrain) _paintLiveShot(canvas, px);
    canvas.restore();
  }

  /// Where [entity] is drawn this frame (between its last two poses).
  Offset? _drawnAt(Entity? entity) => entity
      ?.getComponent<RenderableComponent>()
      ?.renderable
      .position
      .toOffset();

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    double px,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(px, px);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
    painter.dispose();
  }

  void _paintFramingZones(Canvas canvas, double px) {
    final framing = _framing;
    final state = _brain.liveState;
    final viewport = _camera.viewportSize;
    if (framing == null || state == null || viewport.isEmpty) return;

    // The live shot's view, in world units, and the target's screen spot.
    final view = Size(
      viewport.width / state.zoom,
      viewport.height / state.zoom,
    );
    final frame = Rect.fromCenter(
      center: state.position,
      width: view.width,
      height: view.height,
    );
    final spot =
        state.position +
        Offset(framing.screenX * view.width, framing.screenY * view.height);
    final dead = Rect.fromCenter(
      center: spot,
      width: framing.deadZoneWidth * view.width,
      height: framing.deadZoneHeight * view.height,
    );
    final soft = Rect.fromCenter(
      center: spot,
      width:
          math.max(framing.softZoneWidth, framing.deadZoneWidth) * view.width,
      height:
          math.max(framing.softZoneHeight, framing.deadZoneHeight) *
          view.height,
    );

    const accent = Color(0xFF29B6F6);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(frame)
        ..addRect(soft),
      Paint()..color = const Color(0x1AFF5252),
    );
    canvas.drawRect(soft, Paint()..color = accent.withValues(alpha: 0.05));
    canvas.drawRect(soft, _stroke(accent.withValues(alpha: 0.45), 1.5 * px));
    canvas.drawRect(dead, Paint()..color = accent.withValues(alpha: 0.12));
    canvas.drawRect(dead, _stroke(accent.withValues(alpha: 0.9), 1.5 * px));
    _paintLabel(
      canvas,
      'soft zone',
      soft.topLeft + Offset(4 * px, 4 * px),
      accent.withValues(alpha: 0.7),
      px,
    );
    if (!dead.isEmpty) {
      _paintLabel(
        canvas,
        'dead zone',
        dead.topLeft + Offset(4 * px, 4 * px),
        accent,
        px,
      );
    }

    final target = _drawnAt(_runner);
    if (target != null) {
      canvas.drawLine(spot, target, _stroke(Colors.white38, 1 * px));
      canvas.drawCircle(spot, 3 * px, Paint()..color = Colors.white54);
    }
  }

  void _paintGroupBounds(Canvas canvas, double px) {
    final group = _group;
    final centre = _groupEntity
        ?.getComponent<TransformComponent>()
        ?.position
        .toOffset();
    if (group == null || centre == null || group.resolved == 0) return;
    const accent = Color(0xFFAB47BC);
    canvas.drawRect(
      group.bounds,
      Paint()..color = accent.withValues(alpha: 0.06),
    );
    canvas.drawRect(
      group.bounds,
      _stroke(accent.withValues(alpha: 0.8), 2 * px),
    );
    final arm = 10 * px;
    final cross = _stroke(Colors.white70, 2 * px);
    canvas
      ..drawLine(centre - Offset(arm, 0), centre + Offset(arm, 0), cross)
      ..drawLine(centre - Offset(0, arm), centre + Offset(0, arm), cross);
    _paintLabel(
      canvas,
      'Party · ${group.resolved} members (bounds incl. radius)',
      group.bounds.topLeft + Offset(4 * px, -16 * px),
      accent,
      px,
    );
  }

  void _paintDolly(Canvas canvas, double px) {
    final track = _dollyPath;
    final dolly = _dolly;
    if (track == null || dolly == null) return;
    const accent = Color(0xFFFFCA28);
    final rail = Path()..moveTo(track.points.first.dx, track.points.first.dy);
    for (final p in track.points.skip(1)) {
      rail.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(rail, _stroke(accent.withValues(alpha: 0.25), 10 * px));
    canvas.drawPath(rail, _stroke(accent.withValues(alpha: 0.8), 2 * px));
    for (final p in track.points) {
      canvas.drawCircle(p, 5 * px, Paint()..color = accent);
    }

    final Offset onTrack;
    if (dolly.autoDolly) {
      final target = _drawnAt(_runner);
      if (target == null) return;
      onTrack = track.pointAt(track.nearestTo(target));
      canvas.drawLine(target, onTrack, _stroke(Colors.white54, 1 * px));
      _paintLabel(
        canvas,
        'nearest point',
        onTrack + Offset(8 * px, 6 * px),
        accent,
        px,
      );
    } else {
      onTrack = track.pointAt(dolly.pathPosition);
      _paintLabel(
        canvas,
        'pathPosition ${dolly.pathPosition.toStringAsFixed(2)}',
        onTrack + Offset(8 * px, 6 * px),
        accent,
        px,
      );
    }
    canvas.drawCircle(onTrack, 7 * px, _stroke(Colors.white, 2 * px));
  }

  /// The live shot's frame, for director view.
  void _paintLiveShot(Canvas canvas, double px) {
    final state = _brain.liveState;
    final viewport = _camera.viewportSize;
    if (state == null || viewport.isEmpty) return;
    final w = viewport.width / state.zoom / 2;
    final h = viewport.height / state.zoom / 2;
    final c = math.cos(-state.rotation), s = math.sin(-state.rotation);
    Offset corner(double x, double y) =>
        state.position + Offset(x * c - y * s, x * s + y * c);
    final frame = Path()
      ..moveTo(corner(-w, -h).dx, corner(-w, -h).dy)
      ..lineTo(corner(w, -h).dx, corner(w, -h).dy)
      ..lineTo(corner(w, h).dx, corner(w, h).dy)
      ..lineTo(corner(-w, h).dx, corner(-w, h).dy)
      ..close();
    const accent = Color(0xFFF5746F);
    canvas.drawPath(frame, _stroke(accent, 2 * px));
    final arm = 12 * px;
    canvas
      ..drawLine(
        state.position - Offset(arm, 0),
        state.position + Offset(arm, 0),
        _stroke(accent, 1.5 * px),
      )
      ..drawLine(
        state.position - Offset(0, arm),
        state.position + Offset(0, arm),
        _stroke(accent, 1.5 * px),
      );
    final live = _brain.liveCamera;
    _paintLabel(
      canvas,
      'live: ${live?.name ?? '#${live?.id}'}  ×${state.zoom.toStringAsFixed(2)}',
      corner(-w, -h) + Offset(6 * px, 6 * px),
      accent,
      px,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Camera stats (live header line)
  // ─────────────────────────────────────────────────────────────────────────

  String get _cameraStatsLine {
    final cam = _camera;
    final pos = cam.position;
    final live = _brain.liveCamera;
    final blend = _brain.activeBlend;
    return [
      'pos (${pos.dx.toStringAsFixed(0)}, ${pos.dy.toStringAsFixed(0)})',
      'zoom ${cam.zoom.toStringAsFixed(2)}',
      'rot ${(cam.rotation * 180 / math.pi).toStringAsFixed(1)}°',
      if (live != null)
        'live: ${live.name ?? '#${live.id}'}'
      else
        'no virtual camera',
      if (blend != null) 'blend ${(blend.progress * 100).toStringAsFixed(0)}%',
      if (_demo == _Demo.impulses) 'impulses ${_brain.impulses.activeCount}',
    ].join('  ·  ');
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
              const Flexible(
                child: Text(
                  'VirtualCamera  ·  CameraBrain  ·  CameraEffect',
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
    final game = GameWidget(
      key: _gameKey,
      engine: _engine,
      showFPS: true,
      overlay: _demo.usesBrain ? _buildDirectorToggle() : null,
    );
    // With the brain driving, user pan and zoom would be overwritten each
    // frame: the controls are there when the user owns the camera.
    if (!_userOwnsCamera) return game;
    return GameCameraControls(
      camera: _camera,
      enablePan: true,
      enablePinch: true,
      showZoomLevel: true,
      child: game,
    );
  }

  Widget _buildDirectorToggle() {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Tooltip(
          message:
              'brain.driveOutput = false: pan and zoom the output camera '
              'yourself while the brain keeps choosing and blending shots; '
              'the live shot is drawn as a frame.',
          child: _actionButton(
            _directorView ? '🎬 Director view: on' : '🎬 Director view: off',
            const Color(0xFFF5746F),
            _toggleDirectorView,
            selected: _directorView,
          ),
        ),
      ),
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: _buildDemoControls(),
    );
  }

  Widget _buildDemoControls() {
    final controls = switch (_demo) {
      _Demo.follow => _followControls(),
      _Demo.groupFraming => _groupControls(),
      _Demo.confiner => _confinerControls(),
      _Demo.rooms => _roomControls(),
      _Demo.dolly => _dollyControls(),
      _Demo.blendList => _blendListControls(),
      _Demo.stateDriven => _stateControls(),
      _Demo.impulses => _impulseControls(),
      _Demo.outputCamera => _outputControls(),
    };
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: controls,
    );
  }

  List<Widget> _followControls() {
    final f = _framing;
    if (f == null) return const [];
    return [
      _slider('Damping', f.dampingX, 0, 2, (v) {
        f
          ..dampingX = v
          ..dampingY = v;
      }, unit: 's'),
      _slider('Dead zone', f.deadZoneWidth, 0, 0.5, (v) {
        f
          ..deadZoneWidth = v
          ..deadZoneHeight = v;
      }),
      _slider('Soft zone', f.softZoneWidth, 0.1, 1, (v) {
        f
          ..softZoneWidth = v
          ..softZoneHeight = v;
      }),
      _slider('Lookahead', f.lookaheadTime, 0, 1, (v) {
        f.lookaheadTime = v;
      }, unit: 's'),
    ];
  }

  List<Widget> _groupControls() {
    final framing = _groupFraming;
    const color = Color(0xFFAB47BC);
    return [
      _actionButton(
        '+ Member',
        color,
        _partyMembers.length < _kPartyColors.length
            ? () => setState(_addPartyMember)
            : null,
      ),
      _actionButton(
        '− Member',
        color,
        _partyMembers.length > 1 ? () => setState(_removePartyMember) : null,
      ),
      if (framing != null) ...[
        _slider('Padding', framing.padding, 0, 1, (v) => framing.padding = v),
        _slider('Max zoom', framing.maxZoom, 0.5, 3, (v) {
          framing.maxZoom = v;
        }),
      ],
    ];
  }

  List<Widget> _confinerControls() {
    final shot = _shot;
    final confiner = _confiner;
    const color = Color(0xFF78909C);
    return [
      _actionButton(
        _confinerOn ? 'Confiner: on' : 'Confiner: off',
        color,
        _toggleConfiner,
        selected: _confinerOn,
      ),
      if (shot != null)
        _slider('Lens zoom', shot.zoom, 0.3, 2, (v) => shot.zoom = v),
      if (confiner != null)
        _slider('Wall damp', confiner.damping, 0, 0.6, (v) {
          confiner.damping = v;
        }, unit: 's'),
    ];
  }

  List<Widget> _roomControls() {
    const color = Color(0xFF26A69A);
    final walking = (_walker?.speed ?? 0) > 0;
    return [
      _slider('Blend', _blendSeconds, 0, 2, (v) {
        _blendSeconds = v;
        _applyRoomBlends();
      }, unit: 's'),
      for (final curve in _BlendCurve.values)
        _actionButton(curve.label, color, () {
          setState(() => _blendCurve = curve);
          _applyRoomBlends();
        }, selected: curve == _blendCurve),
      _actionButton(walking ? '❚❚ Pause walk' : '▶ Walk', color, _toggleWalk),
      Text(
        _blendSeconds == 0 ? 'duration 0 = cut' : '→ Overview: ×2 (rule)',
        style: const TextStyle(color: Colors.white30, fontSize: 11),
      ),
    ];
  }

  List<Widget> _dollyControls() {
    final dolly = _dolly;
    const color = Color(0xFFFFCA28);
    if (dolly == null) return const [];
    return [
      _actionButton(
        'Auto-dolly',
        color,
        dolly.autoDolly ? null : _setAutoDolly,
        selected: dolly.autoDolly,
      ),
      _actionButton(
        _dollyScript >= 0 ? '⏳ Scripted move…' : '▶ Scripted move',
        color,
        _dollyScript >= 0 ? null : _playDollyScript,
        selected: !dolly.autoDolly,
      ),
      _slider('Damping', dolly.damping, 0, 1.5, (v) {
        dolly.damping = v;
      }, unit: 's'),
    ];
  }

  List<Widget> _blendListControls() {
    final playing = _cutsceneTime >= 0;
    const color = Color(0xFFFF7043);
    return [
      _actionButton(
        playing ? '⏳ Playing…' : '▶ Play cutscene',
        color,
        playing ? null : _playCutscene,
      ),
      _actionButton(
        'Skip',
        color,
        playing ? () => setState(_endCutscene) : null,
      ),
      Text(
        '${_cutsceneLength.toStringAsFixed(1)} s · letterbox · handheld '
        'noise on the rig',
        style: const TextStyle(color: Colors.white30, fontSize: 11),
      ),
    ];
  }

  List<Widget> _stateControls() {
    const color = Color(0xFF66BB6A);
    final current = _heroState?.state;
    return [
      const Text(
        'Hero state:',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
      for (final (state, label) in _kStates)
        _actionButton(
          label,
          color,
          () => _setHeroState(state),
          selected: current == state,
        ),
      const Text(
        'blend 0.6 s between children',
        style: TextStyle(color: Colors.white30, fontSize: 11),
      ),
    ];
  }

  List<Widget> _impulseControls() {
    const color = Color(0xFFFF5252);
    final listener = _listener;
    return [
      _actionButton('Tap', color, () => _emitImpulse(6, duration: 0.25)),
      _actionButton('Hit', color, () => _emitImpulse(14)),
      _actionButton(
        'Explosion',
        color,
        () => _emitImpulse(28, duration: 0.7, frequency: 18),
      ),
      _actionButton(
        'Distant blast',
        color,
        () => _emitImpulse(
          30,
          duration: 0.6,
          at: const Offset(1100, 0),
          radius: 1400,
        ),
      ),
      _actionButton('Barrel', const Color(0xFFFF9800), _detonateBarrel),
      if (listener != null)
        _slider('Gain', listener.gain, 0, 2, (v) => listener.gain = v),
      const Text(
        'Noise:',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
      _actionButton(
        'Off',
        color,
        () => _setNoise(null),
        selected: _noisePreset == null,
      ),
      for (final preset in CameraNoisePreset.values)
        _actionButton(
          preset.name,
          color,
          () => _setNoise(preset),
          selected: _noisePreset == preset,
        ),
    ];
  }

  List<Widget> _outputControls() {
    const color = Color(0xFFEC407A);
    return [
      _slider(
        'Roll',
        _camera.rotation * 180 / math.pi,
        -45,
        45,
        (v) => _camera.rotation = v * math.pi / 180,
        unit: '°',
        digits: 0,
      ),
      _actionButton('Flash White', color, () => _flash(Colors.white)),
      _actionButton('Flash Red', color, () => _flash(Colors.red)),
      _actionButton(
        'Fade to black',
        color,
        () => _fade.fadeIn(0.5, color: Colors.black),
      ),
      _actionButton('Fade back', color, () => _fade.fadeOut(0.5)),
      _actionButton(
        _letterboxVisible ? 'Hide Letterbox' : 'Show Letterbox',
        color,
        _toggleLetterbox,
        selected: _letterboxVisible,
      ),
      _actionButton(
        'Zoom ×2 at landmark',
        color,
        () => setState(() => _camera.zoomToPoint(const Offset(280, -180), 2.0)),
      ),
      _actionButton('Reset view', color, _resetOutputView),
    ];
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String unit = '',
    int digits = 2,
  }) {
    final color = _demo.accentColor;
    return SizedBox(
      width: 236,
      height: 30,
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.2),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                onChanged: (v) => setState(() => onChanged(v)),
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              '${value.toStringAsFixed(digits)}$unit',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    String label,
    Color color,
    VoidCallback? onTap, {
    bool selected = false,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.32)
              : enabled
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF111C2A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected || enabled
                ? color.withValues(alpha: selected ? 0.9 : 0.55)
                : const Color(0xFF1A2535),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled || selected ? Colors.white : Colors.white30,
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
                const Text(
                  'just_game_engine 2.x · virtual cameras',
                  style: TextStyle(color: Colors.white24, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              width: double.infinity,
              child: SingleChildScrollView(
                child: SelectableText(
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

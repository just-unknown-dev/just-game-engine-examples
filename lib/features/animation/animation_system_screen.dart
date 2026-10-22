import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/engine/demo_engine.dart';
import '../../core/widgets/camera_zoom_controls.dart';

// -----------------------------------------------------------------------------
// Assets
// -----------------------------------------------------------------------------

const _kChar02Root = 'assets/sprites/characters/character02';
const _kChar03Root = 'assets/sprites/characters/character03';

/// TexturePacker multi-page atlas: the idle sheet (page 0) and the walk
/// sheet (page 1) of character02.
const _kChar02Atlas = '$_kChar02Root/character02.atlas.json';

/// Aseprite export of character02's walk sheet: tags, per-frame durations,
/// a one-shot clip and frame events.
const _kChar02Walk = '$_kChar02Root/character02_walk.aseprite.json';

/// character02's state machine: idle / move (1-D blend tree) / hop.
const _kChar02Graph = '$_kChar02Root/character02.animator.json';

/// TexturePacker multi-page atlas: one page per direction of character03.
const _kChar03Atlas = '$_kChar03Root/character03.atlas.json';

/// character03's state machine: 2-D blend trees by facing and velocity.
const _kChar03Graph = '$_kChar03Root/character03.animator.json';

// -----------------------------------------------------------------------------
// Demo mode
// -----------------------------------------------------------------------------

enum _AnimDemo {
  atlasClips,
  aseprite,
  multiPage,
  stateMachine,
  blendTree;

  String get label => switch (this) {
    atlasClips => 'Atlas Clips',
    aseprite => 'Aseprite Tags',
    multiPage => 'Multi-Page',
    stateMachine => 'State Machine',
    blendTree => 'Blend Tree',
  };

  IconData get icon => switch (this) {
    atlasClips => Icons.layers_outlined,
    aseprite => Icons.timer_outlined,
    multiPage => Icons.view_comfy_alt_outlined,
    stateMachine => Icons.account_tree_outlined,
    blendTree => Icons.explore_outlined,
  };

  Color get accentColor => switch (this) {
    atlasClips => const Color(0xFF29B6F6),
    aseprite => const Color(0xFFFFCA28),
    multiPage => const Color(0xFFAB47BC),
    stateMachine => const Color(0xFF66BB6A),
    blendTree => const Color(0xFFFF7043),
  };

  String get description => switch (this) {
    atlasClips =>
      'A crowd playing clips of one TexturePacker multi-page atlas (idle '
          'sheet = page 0, walk sheet = page 1) through '
          'SpriteAnimationComponent(atlasPath:, clip:). TexturePacker files '
          'carry regions, so the clips are registered from code with '
          'atlas.registerClip — "smear" has hand-timed frames. switchClip and '
          'speed change every walker live (a negative speed plays backwards); '
          'the bobbing is a looping RepeatEffect.',
    aseprite =>
      'An Aseprite export of the walk sheet: its frameTags become clips '
          '(forward, reverse, pingpong), every frame keeps its own duration '
          '(the strip below), meta.just.clips makes "step" a one-shot, and '
          'meta.just.events fires frame events, heard on '
          'SpriteAnimationSystem.signals.',
    multiPage =>
      'One TexturePacker atlas, eight pages — one image per direction. Each '
          'character plays a clip from a different page; idle / run calls '
          'switchClip on all of them and the page image follows the frame.',
    stateMachine =>
      'AnimatorComponent(graphPath:, faceVelocity: true) runs '
          'character02.animator.json: "speed" is bound to speedX, so the graph '
          'picks idle or move with no code; move is a 1-D blend tree (walk, '
          'run above ~120 px/s); the hop trigger enters a one-shot state left '
          'on its exit time while a SequenceEffect lifts the body.',
    blendTree =>
      'Top-down character03.animator.json: run is a 2-D blend tree over '
          '(velocityX, velocityY) and idle a 2-D tree over the last facing. A '
          'sprite plays the heaviest motion, so one state covers four '
          'directions. Tap the canvas to walk there, or let it wander.',
  };

  String get codeSnippet => switch (this) {
    atlasClips =>
      '// Cached in engine.assets — the same atlas the systems play:\n'
          'final atlas = await SpriteAtlas.fromAsset(\n'
          '  \'$_kChar02Atlas\',\n'
          '  assets: engine.assets,\n'
          ');\n'
          '// TexturePacker carries regions; clips come from code:\n'
          'atlas.registerClip(AtlasAnimationClip(\n'
          '  name: \'walk\',\n'
          '  frames: [\n'
          '    for (var i = 0; i < 24; i++)\n'
          '      AtlasFrame(regionName: \'walk_\$i\', duration: 1 / 12),\n'
          '  ],\n'
          '));\n\n'
          '// Systems: DefaultSystem.sprites (registerSpriteSystems).\n'
          'final walker = world.createEntityWithComponents([\n'
          '  TransformComponent(position: pos, scale: Vector3(1.6, 1.6, 1)),\n'
          '  SpriteAnimationComponent(\n'
          '    atlasPath: \'$_kChar02Atlas\',\n'
          '    clip: \'idle\',\n'
          '  ),\n'
          ']);\n'
          'walker.getComponent<SpriteAnimationComponent>()!\n'
          '  ..switchClip(\'walk\')\n'
          '  ..speed = -1; // backwards',
    aseprite =>
      '// character02_walk.aseprite.json (an Aseprite export):\n'
          '//   meta.frameTags: walk, walk_back (reverse),\n'
          '//                   sway (pingpong), step\n'
          '//   frames[i].duration: per-frame milliseconds\n'
          '//   meta.just.clips.step.loop: false\n'
          '//   meta.just.events.walk: [{time: 0, name: footstep_left}, …]\n'
          'final hero = world.createEntityWithComponents([\n'
          '  TransformComponent(scale: Vector3(3.5, 3.5, 1)),\n'
          '  SpriteAnimationComponent(\n'
          '    atlasPath: \'$_kChar02Walk\',\n'
          '    clip: \'walk\',\n'
          '  ),\n'
          ']);\n'
          'final sub = world.getSystem<SpriteAnimationSystem>()!.signals\n'
          '    .listen((s) => print(\'\${s.clip}: \${s.name}\'));\n'
          '// A one-shot plays once, then signals \'completed\':\n'
          'hero.getComponent<SpriteAnimationComponent>()!\n'
          '    .switchClip(\'step\', restartIfSame: true);',
    multiPage =>
      '// One atlas, eight pages:\n'
          '// { "textures": [\n'
          '//   { "image": "character_03_idle_down.png",\n'
          '//     "frames": [ { "filename": "idle_down_0", … } ] },\n'
          '//   … ] }\n'
          'for (final dir in [\'down\', \'right\', \'up\', \'left\']) {\n'
          '  world.createEntityWithComponents([\n'
          '    TransformComponent(\n'
          '      position: spots[dir], scale: Vector3(2, 2, 1)),\n'
          '    SpriteAnimationComponent(\n'
          '      atlasPath: \'$_kChar03Atlas\',\n'
          '      clip: \'idle_\$dir\',\n'
          '    ),\n'
          '  ]);\n'
          '}\n'
          '// Switching to a clip on another page swaps the image:\n'
          'anim.switchClip(\'run_\$dir\');',
    stateMachine =>
      'world.createEntityWithComponents([\n'
          '  TransformComponent(scale: Vector3(2.2, 2.2, 1)),\n'
          '  VelocityComponent(), // read by the speedX binding\n'
          '  SpriteAnimationComponent(\n'
          '    atlasPath: \'$_kChar02Atlas\',\n'
          '    clip: \'idle\', // until the graph has loaded\n'
          '  ),\n'
          '  AnimatorComponent(\n'
          '    graphPath: \'$_kChar02Graph\',\n'
          '    faceVelocity: true, // flipX follows velocity.x\n'
          '  ),\n'
          ']);\n'
          '// character02.animator.json (version 2):\n'
          '//   idle --speed > 15 (0.12 s)--> move [1-D: walk | run]\n'
          '//   move --speed <= 15--> idle\n'
          '//   *    --hop (trigger)-->  hop --exit time--> idle\n'
          'animator.setTrigger(\'hop\');\n'
          'world.getSystem<AnimatorSystem>()!.stateChanges\n'
          '    .listen((c) => print(\'\${c.from} → \${c.to}\'));',
    blendTree =>
      '// character03.animator.json, the run state:\n'
          '// "blend": { "type": "2d",\n'
          '//   "parameter": "vx", "parameterY": "vy", // velocityX/Y\n'
          '//   "motions": [\n'
          '//     { "clip": "run_right", "x": 120 },\n'
          '//     { "clip": "run_left",  "x": -120 },\n'
          '//     { "clip": "run_down",  "y": 120 },\n'
          '//     { "clip": "run_up",    "y": -120 } ] }\n'
          '// idle blends idle_* by faceX / faceY, set from code:\n'
          'animator\n'
          '  ..setFloat(\'faceX\', dir.dx)\n'
          '  ..setFloat(\'faceY\', dir.dy);\n'
          'velocity.velocity = Vector3(dir.dx, dir.dy, 0) * 140;',
  };
}

// -----------------------------------------------------------------------------
// ECS -- the demos' own steering (the animation itself is the engine's)
// -----------------------------------------------------------------------------

/// Walks an entity left and right between [minX] and [maxX] at [speed].
class _PaceComponent extends Component {
  _PaceComponent({required this.minX, required this.maxX, required this.speed});

  final double minX;
  final double maxX;
  double speed;
  double direction = 1;
}

/// Sets each pacer's velocity; `MovementSystem` moves it and the animator's
/// speedX binding reads it.
class _PaceSystem extends System {
  @override
  int get priority => SystemPriorities.playerControl;

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    VelocityComponent,
    _PaceComponent,
  ];

  @override
  void update(double deltaTime) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final v = entity.getComponent<VelocityComponent>()!;
      final p = entity.getComponent<_PaceComponent>()!;
      if (t.position.x >= p.maxX) p.direction = -1;
      if (t.position.x <= p.minX) p.direction = 1;
      v.velocity = Vector3(p.direction * p.speed, 0, 0);
    });
  }
}

/// Walks an entity to [target], or to random spots inside [bounds] while
/// [wander] is on, resting a moment at each.
class _SeekComponent extends Component {
  _SeekComponent({required this.bounds, required this.speed});

  final Rect bounds;
  double speed;
  Offset? target;
  bool wander = true;
  double rest = 0.6;
}

/// Steers seekers and tells their animator which way they face, for the
/// idle blend tree.
class _SeekSystem extends System {
  _SeekSystem(this._random);

  final math.Random _random;

  @override
  int get priority => SystemPriorities.playerControl;

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    VelocityComponent,
    _SeekComponent,
  ];

  @override
  void update(double deltaTime) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final v = entity.getComponent<VelocityComponent>()!;
      final s = entity.getComponent<_SeekComponent>()!;
      var target = s.target;
      if (target == null) {
        v.velocity = Vector3.zero();
        if (!s.wander) return;
        s.rest -= deltaTime;
        if (s.rest > 0) return;
        target = s.target = Offset(
          s.bounds.left + _random.nextDouble() * s.bounds.width,
          s.bounds.top + _random.nextDouble() * s.bounds.height,
        );
      }
      final to = target - Offset(t.position.x, t.position.y);
      final distance = to.distance;
      if (distance < 4) {
        s
          ..target = null
          ..rest = 0.6 + _random.nextDouble();
        v.velocity = Vector3.zero();
        return;
      }
      final dir = to / distance;
      v.velocity = Vector3(dir.dx * s.speed, dir.dy * s.speed, 0);
      entity.getComponent<AnimatorComponent>()
        ?..setFloat('faceX', dir.dx)
        ..setFloat('faceY', dir.dy);
    });
  }
}

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

class AnimationSystemScreen extends StatefulWidget {
  const AnimationSystemScreen({super.key});

  @override
  State<AnimationSystemScreen> createState() => _AnimationSystemScreenState();
}

class _AnimationSystemScreenState extends State<AnimationSystemScreen>
    with SingleTickerProviderStateMixin {
  // The app's one shared 2-D engine: already started and driven by the
  // GameWidget, so this screen never steps the world itself.
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;
  late final Ticker _ticker;
  final math.Random _random = math.Random();

  // Demo state
  _AnimDemo _demo = _AnimDemo.atlasClips;
  bool _loading = true;
  String? _loadError;
  String _statusMessage = '';

  // Atlases (loaded once into engine.assets; the sprite systems share them)
  SpriteAtlas? _char02;
  SpriteAtlas? _char02Walk;
  SpriteAtlas? _char03;

  // The current demo's systems and listeners (fresh after every reset).
  EffectSystemECS? _effects;
  StreamSubscription<SpriteAnimationSignal>? _signalSub;
  StreamSubscription<AnimatorStateChange>? _stateSub;

  // Atlas Clips
  int _characterCount = 12;
  String _atlasClip = 'idle';
  double _atlasSpeed = 1.0;
  final List<Entity> _walkers = [];

  // Aseprite Tags
  String _asepriteClip = 'walk';
  Entity? _asepriteHero;
  final List<SpriteAnimationSignal> _pendingSignals = [];
  final List<String> _eventLog = [];
  int _eventCount = 0;

  // Multi-Page
  String _topDownMode = 'idle';
  final List<(Entity sprite, Entity label)> _directions = [];

  // State Machine
  double _paceSpeed = 90;
  Entity? _pacer;

  // Blend Tree
  double _seekSpeed = 140;
  bool _wander = true;
  Entity? _explorer;
  Entity? _targetMarker;
  static const _kExploreBounds = Rect.fromLTWH(-300, -160, 600, 320);

  // Animator state changes, newest first.
  final List<String> _stateLog = [];

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _cancelListeners();
    // Clears the shared world and leaves the engine running.
    DemoEngine.reset(_engine);
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Loading
  // -------------------------------------------------------------------------

  Future<void> _initialize() async {
    try {
      final assets = _engine.assets;
      final char02 = await SpriteAtlas.fromAsset(_kChar02Atlas, assets: assets);
      final char02Walk = await SpriteAtlas.fromAsset(
        _kChar02Walk,
        assets: assets,
      );
      final char03 = await SpriteAtlas.fromAsset(_kChar03Atlas, assets: assets);

      // TexturePacker atlases have regions but no clips: make them.
      _registerRuns(char02, const {'idle': 10, 'walk': 12});
      _registerRuns(char03, const {
        'idle_down': 8,
        'idle_up': 8,
        'idle_left': 8,
        'idle_right': 8,
        'run_down': 12,
        'run_up': 12,
        'run_left': 12,
        'run_right': 12,
      });
      // The same walk frames, faster: the state machine's "run" motion.
      char02.registerClip(
        AtlasAnimationClip(
          name: 'run',
          frames: [
            for (final f in char02.requireClip('walk').frames)
              AtlasFrame(regionName: f.regionName, duration: 0.045),
          ],
        ),
      );
      // Hand-timed frames: a long anticipation, quick smears, a long
      // follow-through.
      char02.registerClip(
        const AtlasAnimationClip(
          name: 'smear',
          frames: [
            AtlasFrame(regionName: 'walk_0', duration: 0.20),
            AtlasFrame(regionName: 'walk_1', duration: 0.05),
            AtlasFrame(regionName: 'walk_8', duration: 0.05),
            AtlasFrame(regionName: 'walk_12', duration: 0.05),
            AtlasFrame(regionName: 'walk_16', duration: 0.05),
            AtlasFrame(regionName: 'walk_20', duration: 0.18),
            AtlasFrame(regionName: 'walk_22', duration: 0.08),
          ],
        ),
      );

      _char02 = char02;
      _char02Walk = char02Walk;
      _char03 = char03;
    } catch (error) {
      _loadError = '$error';
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _buildDemo(_demo);
  }

  /// Registers a looping clip for every run of regions named
  /// `<clip>_<n>`, at [fps] frames a second for each clip named there.
  static void _registerRuns(SpriteAtlas atlas, Map<String, double> fps) {
    final runs = <String, List<String>>{};
    for (final name in atlas.regionNames) {
      final cut = name.lastIndexOf('_');
      if (cut <= 0) continue;
      (runs[name.substring(0, cut)] ??= []).add(name);
    }
    int indexOf(String region) =>
        int.tryParse(region.substring(region.lastIndexOf('_') + 1)) ?? 0;
    for (final MapEntry(key: clip, value: regions) in runs.entries) {
      final rate = fps[clip];
      if (rate == null) continue;
      regions.sort((a, b) => indexOf(a).compareTo(indexOf(b)));
      atlas.registerClip(
        AtlasAnimationClip(
          name: clip,
          frames: [
            for (final region in regions)
              AtlasFrame(regionName: region, duration: 1 / rate),
          ],
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Tick (UI only: the engine runs itself)
  // -------------------------------------------------------------------------

  void _onTick(Duration _) {
    if (!mounted) return;
    _flushSignals();
    _syncLabels();
    setState(() {});
  }

  /// Frame events heard during the last fixed steps, shown as floating
  /// labels — spawned here, outside the systems' update.
  void _flushSignals() {
    if (_pendingSignals.isEmpty) return;
    final signals = [..._pendingSignals];
    _pendingSignals.clear();
    for (final s in signals) {
      _eventCount++;
      _eventLog.insert(0, '${s.clip}: ${s.name}');
      if (_eventLog.length > 4) _eventLog.removeLast();
      _spawnFloatingLabel(s.name);
    }
  }

  void _spawnFloatingLabel(String text) {
    final effects = _effects;
    if (effects == null) return;
    final completed = text == SpriteAnimationSignal.completed;
    final label = _world.createEntityWithComponents([
      TransformComponent(
        position: Vector3(-40 + _random.nextDouble() * 80, 70, 0),
      ),
      RenderableComponent(
        renderable: TextRenderable(
          text: text,
          textStyle: TextStyle(
            color: completed
                ? const Color(0xFF66BB6A)
                : const Color(0xFFFFCA28),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          layer: 40,
        ),
      ),
    ], name: 'event-label');
    // Rise and fade together, then go.
    effects.scheduleEffect(
      entity: label,
      effect: ParallelEffect(
        children: [
          MoveEffect(
            from: Vector3.zero(),
            to: Vector3(0, -60, 0),
            easing: EasingType.easeOutCubic,
            durationTicks: 50,
          ),
          FadeEffect(
            from: 1,
            to: 0,
            easing: EasingType.easeInQuad,
            durationTicks: 50,
          ),
        ],
        onComplete: () => _world.commands.destroy(label),
      ),
    );
  }

  /// Keeps the world-space readouts in step with what the systems did.
  void _syncLabels() {
    switch (_demo) {
      case _AnimDemo.multiPage:
        final sprites = _world.getSystem<SpriteAnimationSystem>();
        for (final (sprite, label) in _directions) {
          final anim = sprite.getComponent<SpriteAnimationComponent>();
          final text = label.getComponent<RenderableComponent>()?.renderable;
          final atlas = sprites?.atlasOf(sprite);
          if (anim == null || text is! TextRenderable || atlas == null) {
            continue;
          }
          final clip = sprites!.clipOf(atlas, anim);
          if (clip.frames.isEmpty) continue;
          final frame =
              clip.frames[anim.frameIndex.clamp(0, clip.frames.length - 1)];
          final page = atlas.getRegion(frame.regionName)?.pageIndex ?? 0;
          text.text = '${anim.clip}\npage $page · frame ${anim.frameIndex}';
        }
      case _AnimDemo.blendTree:
        final marker = _targetMarker;
        final target = _explorer?.getComponent<_SeekComponent>()?.target;
        if (marker == null) break;
        final r = marker.getComponent<RenderableComponent>()?.renderable;
        r?.visible = target != null;
        if (target != null) {
          marker.getComponent<TransformComponent>()?.position =
              Vector3.fromOffset(target);
        }
      default:
        break;
    }
  }

  // -------------------------------------------------------------------------
  // Demo construction
  // -------------------------------------------------------------------------

  void _cancelListeners() {
    _signalSub?.cancel();
    _signalSub = null;
    _stateSub?.cancel();
    _stateSub = null;
  }

  void _buildDemo(_AnimDemo demo) {
    if (!mounted) return;
    _demo = demo;
    _statusMessage = '';
    _cancelListeners();
    _walkers.clear();
    _directions.clear();
    _asepriteHero = null;
    _pacer = null;
    _explorer = null;
    _targetMarker = null;
    _pendingSignals.clear();
    _eventLog.clear();
    _stateLog.clear();
    _eventCount = 0;

    // A clean world: the standard renderer, the sprite systems (sprites,
    // animators, clip playback, timelines) and MovementSystem.
    DemoEngine.reset(
      _engine,
      include: {
        DefaultSystem.rendering,
        DefaultSystem.sprites,
        DefaultSystem.movement,
      },
    );
    // Not default systems: effects, and this screen's own steering.
    final effects = _effects = EffectSystemECS();
    _world
      ..addSystem(effects)
      ..addSystem(_PaceSystem())
      ..addSystem(_SeekSystem(_random));

    if (_char02 == null || _char02Walk == null || _char03 == null) {
      if (mounted) setState(() {});
      return;
    }

    _spawnBackdrop();
    switch (demo) {
      case _AnimDemo.atlasClips:
        _buildAtlasClipsDemo();
      case _AnimDemo.aseprite:
        _buildAsepriteDemo();
      case _AnimDemo.multiPage:
        _buildMultiPageDemo();
      case _AnimDemo.stateMachine:
        _buildStateMachineDemo();
      case _AnimDemo.blendTree:
        _buildBlendTreeDemo();
    }
    if (mounted) setState(() {});
  }

  void _spawnBackdrop() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          getBoundsCallback: () => const Rect.fromLTRB(-900, -700, 900, 700),
          onRender: (canvas, _) {
            final gridPaint = Paint()
              ..color = const Color(0xFF1A2E40).withValues(alpha: 0.35)
              ..strokeWidth = 1;
            for (double x = -900; x <= 900; x += 72) {
              canvas.drawLine(Offset(x, -700), Offset(x, 700), gridPaint);
            }
            for (double y = -700; y <= 700; y += 72) {
              canvas.drawLine(Offset(-900, y), Offset(900, y), gridPaint);
            }
            canvas.drawRect(
              const Rect.fromLTRB(-900, 90, 900, 270),
              Paint()..color = const Color(0xFF223349).withValues(alpha: 0.40),
            );
          },
        ),
      ),
    ], name: 'backdrop');
  }

  Entity _spawnText(Offset at, String text, {Color? color, double size = 11}) {
    return _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(at)),
      RenderableComponent(
        renderable: TextRenderable(
          text: text,
          textStyle: TextStyle(
            color: color ?? _demo.accentColor,
            fontSize: size,
            fontWeight: FontWeight.w600,
          ),
          layer: 30,
        ),
      ),
    ], name: 'label');
  }

  // -- Atlas Clips -----------------------------------------------------------

  void _buildAtlasClipsDemo() {
    final atlas = _char02!;
    final effects = _effects!;
    final rows = (_characterCount / 6).ceil();
    final cols = (_characterCount / rows).ceil();
    const sx = 120.0, sy = 130.0;
    final startX = -((cols - 1) * sx) / 2;

    for (int i = 0; i < _characterCount; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      final pos = Offset(startX + col * sx, -30.0 + row * sy);

      final walker = _world.createEntityWithComponents([
        TransformComponent(
          position: Vector3.fromOffset(pos),
          scale: Vector3(1.6, 1.6, 1),
        ),
        SpriteAnimationComponent(
          atlasPath: _kChar02Atlas,
          clip: _atlasClip,
          speed: _atlasSpeed,
        ),
      ], name: 'walker-$i');
      _walkers.add(walker);

      // A gentle bob: up and back for ever, each walker on its own beat.
      final amplitude = 6 + _random.nextDouble() * 8;
      final half = 28 + _random.nextInt(20);
      effects.scheduleEffect(
        entity: walker,
        startTick: effects.currentTick + _random.nextInt(half * 2),
        effect: RepeatEffect(
          times: 0,
          child: SequenceEffect(
            children: [
              MoveEffect(
                from: Vector3.zero(),
                to: Vector3(0, -amplitude, 0),
                easing: EasingType.easeInOutSine,
                durationTicks: half,
              ),
              MoveEffect(
                from: Vector3(0, -amplitude, 0),
                to: Vector3.zero(),
                easing: EasingType.easeInOutSine,
                durationTicks: half,
              ),
            ],
          ),
        ),
      );
    }

    _statusMessage =
        'atlas: ${atlas.regionCount} regions · ${atlas.pages.length} pages · '
        '${atlas.clipNames.length} clips (registered from code)';
  }

  void _switchAtlasClip(String clip) {
    setState(() => _atlasClip = clip);
    for (final w in _walkers) {
      w.getComponent<SpriteAnimationComponent>()?.switchClip(clip);
    }
  }

  void _setAtlasSpeed(double speed) {
    setState(() => _atlasSpeed = speed);
    for (final w in _walkers) {
      w.getComponent<SpriteAnimationComponent>()?.speed = speed;
    }
  }

  // -- Aseprite Tags ---------------------------------------------------------

  void _buildAsepriteDemo() {
    final atlas = _char02Walk!;
    final hero = _world.createEntityWithComponents([
      TransformComponent(
        position: Vector3(0, -10, 0),
        scale: Vector3(3.5, 3.5, 1),
      ),
      SpriteAnimationComponent(atlasPath: _kChar02Walk, clip: _asepriteClip),
    ], name: 'aseprite-hero');
    _asepriteHero = hero;
    _spawnFrameStrip();

    // Signals arrive inside the system's update; they are queued and shown
    // on the next UI tick.
    _signalSub = _world.getSystem<SpriteAnimationSystem>()?.signals.listen((s) {
      if (identical(s.entity, _asepriteHero)) _pendingSignals.add(s);
    });

    _statusMessage =
        'Aseprite atlas: ${atlas.regionCount} frames · tags '
        '${atlas.clipNames.join(', ')} · events in meta.just';
  }

  /// Every frame of the playing clip as a bar as long as its duration, the
  /// showing frame lit, and the clip's events as ticks.
  void _spawnFrameStrip() {
    const strip = Rect.fromLTWH(-260, 130, 520, 22);
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: 20,
          getBoundsCallback: () => strip.inflate(24),
          onRender: (canvas, _) {
            final atlas = _char02Walk;
            final anim = _asepriteHero
                ?.getComponent<SpriteAnimationComponent>();
            final clip = anim == null ? null : atlas?.getClip(anim.clip);
            if (atlas == null || anim == null || clip == null) return;
            if (clip.frames.isEmpty) return;
            final total = clip.totalDuration;
            final accent = _AnimDemo.aseprite.accentColor;
            var x = strip.left;
            for (var i = 0; i < clip.frames.length; i++) {
              final w = strip.width * clip.frames[i].duration / total;
              canvas.drawRect(
                Rect.fromLTWH(
                  x + 1,
                  strip.top,
                  math.max(1, w - 2),
                  strip.height,
                ),
                Paint()
                  ..color = i == anim.frameIndex
                      ? accent
                      : const Color(0xFF2A3F55),
              );
              x += w;
            }
            final events = atlas.userData['events'];
            final forClip = events is Map ? events[anim.clip] : null;
            if (forClip is List) {
              final tick = Paint()
                ..color = const Color(0xFFFF7043)
                ..strokeWidth = 2;
              for (final e in forClip) {
                if (e is! Map) continue;
                final time = (e['time'] as num?)?.toDouble() ?? 0;
                final ex = strip.left + strip.width * time / total;
                canvas.drawLine(
                  Offset(ex, strip.top - 8),
                  Offset(ex, strip.bottom + 4),
                  tick,
                );
              }
            }
          },
        ),
      ),
    ], name: 'frame-strip');
    _spawnText(
      Offset(strip.center.dx, strip.bottom + 16),
      'frame durations (bars) · frame events (orange ticks)',
      color: Colors.white38,
      size: 10,
    );
  }

  void _playAsepriteClip(String clip) {
    setState(() => _asepriteClip = clip);
    _asepriteHero?.getComponent<SpriteAnimationComponent>()?.switchClip(
      clip,
      restartIfSame: true,
    );
  }

  void _toggleAsepritePlay() {
    final anim = _asepriteHero?.getComponent<SpriteAnimationComponent>();
    if (anim == null) return;
    setState(() => anim.isPlaying ? anim.pause() : anim.play());
  }

  // -- Multi-Page ------------------------------------------------------------

  void _buildMultiPageDemo() {
    final atlas = _char03!;
    const dirs = ['down', 'right', 'up', 'left'];
    const positions = [
      Offset(0, 110),
      Offset(170, 0),
      Offset(0, -110),
      Offset(-170, 0),
    ];

    for (int i = 0; i < dirs.length; i++) {
      final sprite = _world.createEntityWithComponents([
        TransformComponent(
          position: Vector3.fromOffset(positions[i]),
          scale: Vector3(2, 2, 1),
        ),
        SpriteAnimationComponent(
          atlasPath: _kChar03Atlas,
          clip: '${_topDownMode}_${dirs[i]}',
        ),
      ], name: 'dir-${dirs[i]}');
      final label = _spawnText(
        positions[i] + const Offset(0, 62),
        '${_topDownMode}_${dirs[i]}',
        size: 10,
      );
      _directions.add((sprite, label));
    }

    _statusMessage =
        'multi-page atlas: ${atlas.pages.length} pages · '
        '${atlas.regionCount} regions · ${atlas.clipNames.length} clips';
  }

  void _switchTopDownMode(String mode) {
    setState(() => _topDownMode = mode);
    for (final (sprite, _) in _directions) {
      final anim = sprite.getComponent<SpriteAnimationComponent>();
      if (anim == null) continue;
      final dir = anim.clip.substring(anim.clip.indexOf('_') + 1);
      anim.switchClip('${mode}_$dir');
    }
  }

  // -- State Machine ---------------------------------------------------------

  void _buildStateMachineDemo() {
    final pacer = _world.createEntityWithComponents([
      TransformComponent(
        position: Vector3(0, 40, 0),
        scale: Vector3(2.2, 2.2, 1),
      ),
      VelocityComponent(),
      // The graph picks the clip; 'idle' shows until it has loaded.
      SpriteAnimationComponent(atlasPath: _kChar02Atlas, clip: 'idle'),
      AnimatorComponent(graphPath: _kChar02Graph, faceVelocity: true),
      _PaceComponent(minX: -260, maxX: 260, speed: _paceSpeed),
    ], name: 'pacer');
    _pacer = pacer;
    _listenToStates(pacer);
    _spawnText(
      const Offset(0, -110),
      'idle ⇄ move (1-D blend: walk | run) · any → hop → idle',
      color: Colors.white38,
      size: 11,
    );
    _statusMessage = 'graph: $_kChar02Graph';
  }

  void _listenToStates(Entity entity) {
    _stateSub = _world.getSystem<AnimatorSystem>()?.stateChanges.listen((c) {
      if (!identical(c.entity, entity)) return;
      _stateLog.insert(0, '${c.from.isEmpty ? 'entry' : c.from} → ${c.to}');
      if (_stateLog.length > 4) _stateLog.removeLast();
    });
  }

  void _setPaceSpeed(double speed) {
    setState(() => _paceSpeed = speed);
    _pacer?.getComponent<_PaceComponent>()?.speed = speed;
  }

  void _hop() {
    final pacer = _pacer;
    final effects = _effects;
    if (pacer == null || effects == null) return;
    // The graph's any-state transition takes the trigger and switches it off.
    pacer.getComponent<AnimatorComponent>()?.setTrigger('hop');
    // The body's arc is an effect: additive, so it rides on the walking.
    effects.scheduleEffect(
      entity: pacer,
      effect: SequenceEffect(
        children: [
          MoveEffect(
            from: Vector3.zero(),
            to: Vector3(0, -60, 0),
            easing: EasingType.easeOutQuad,
            durationTicks: 15,
          ),
          MoveEffect(
            from: Vector3(0, -60, 0),
            to: Vector3.zero(),
            easing: EasingType.easeInQuad,
            durationTicks: 15,
          ),
        ],
      ),
    );
  }

  // -- Blend Tree ------------------------------------------------------------

  void _buildBlendTreeDemo() {
    const bounds = _kExploreBounds;
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -10,
          getBoundsCallback: () => bounds.inflate(10),
          onRender: (canvas, _) {
            canvas.drawRect(
              bounds,
              Paint()
                ..color = _AnimDemo.blendTree.accentColor.withValues(
                  alpha: 0.05,
                ),
            );
            canvas.drawRect(
              bounds,
              Paint()
                ..color = _AnimDemo.blendTree.accentColor.withValues(alpha: 0.4)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          },
        ),
      ),
    ], name: 'arena');

    _targetMarker = _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: -5,
          visible: false,
          getBoundsCallback: () =>
              Rect.fromCircle(center: Offset.zero, radius: 14),
          onRender: (canvas, _) {
            final paint = Paint()
              ..color = _AnimDemo.blendTree.accentColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2;
            canvas
              ..drawCircle(Offset.zero, 10, paint)
              ..drawLine(const Offset(-14, 0), const Offset(14, 0), paint)
              ..drawLine(const Offset(0, -14), const Offset(0, 14), paint);
          },
        ),
      ),
    ], name: 'target');

    final explorer = _world.createEntityWithComponents([
      TransformComponent(scale: Vector3(1.6, 1.6, 1)),
      VelocityComponent(),
      SpriteAnimationComponent(atlasPath: _kChar03Atlas, clip: 'idle_down'),
      AnimatorComponent(graphPath: _kChar03Graph),
      _SeekComponent(bounds: bounds.deflate(30), speed: _seekSpeed)
        ..wander = _wander,
    ], name: 'explorer');
    _explorer = explorer;
    _listenToStates(explorer);
    _statusMessage = 'graph: $_kChar03Graph · tap the canvas to walk there';
  }

  void _handleTap(Offset screenPos) {
    if (_demo != _AnimDemo.blendTree) return;
    final seek = _explorer?.getComponent<_SeekComponent>();
    if (seek == null) return;
    final world = _engine.cameraSystem.mainCamera.screenToWorld(screenPos);
    final area = seek.bounds;
    seek.target = Offset(
      world.dx.clamp(area.left, area.right),
      world.dy.clamp(area.top, area.bottom),
    );
  }

  // -------------------------------------------------------------------------
  // Live stats
  // -------------------------------------------------------------------------

  String _describeAnimator(Entity? entity) {
    final animator = entity?.getComponent<AnimatorComponent>();
    final anim = entity?.getComponent<SpriteAnimationComponent>();
    if (animator == null || anim == null) return 'loading...';
    if (animator.currentState.isEmpty) return 'loading graph...';
    final faceOrFlip = _demo == _AnimDemo.stateMachine
        ? 'flipX ${anim.flipX}'
        : 'face (${animator.getFloat('faceX').toStringAsFixed(1)}, '
              '${animator.getFloat('faceY').toStringAsFixed(1)})';
    return 'state ${animator.currentState} '
        '(${animator.stateTime.toStringAsFixed(1)} s) · clip ${anim.clip} · '
        'speed ${animator.getFloat('speed').toStringAsFixed(0)} · $faceOrFlip';
  }

  String get _statsLine {
    if (_loading) return 'loading atlases...';
    if (_loadError != null) return 'could not load the atlases';
    switch (_demo) {
      case _AnimDemo.atlasClips:
        final anim = _walkers.firstOrNull
            ?.getComponent<SpriteAnimationComponent>();
        final clip = _char02?.getClip(_atlasClip);
        if (anim == null || clip == null) return '';
        return 'walkers ${_walkers.length} · clip "${anim.clip}" '
            '${clip.frames.length} frames / '
            '${clip.totalDuration.toStringAsFixed(2)} s · '
            'frame ${anim.frameIndex} · speed ${anim.speed.toStringAsFixed(1)}';
      case _AnimDemo.aseprite:
        final anim = _asepriteHero?.getComponent<SpriteAnimationComponent>();
        final clip = anim == null ? null : _char02Walk?.getClip(anim.clip);
        if (anim == null || clip == null || clip.frames.isEmpty) return '';
        final frame =
            clip.frames[anim.frameIndex.clamp(0, clip.frames.length - 1)];
        final state = anim.isComplete
            ? 'complete'
            : (anim.isPlaying ? 'playing' : 'paused');
        return 'clip "${anim.clip}" · frame ${anim.frameIndex + 1}/'
            '${clip.frames.length} (${(frame.duration * 1000).round()} ms) · '
            't ${anim.elapsed.toStringAsFixed(2)}/'
            '${clip.totalDuration.toStringAsFixed(2)} s · $state · '
            'events $_eventCount';
      case _AnimDemo.multiPage:
        return '${_directions.length} sprites · mode $_topDownMode · '
            'one atlas, ${_char03?.pages.length ?? 0} page images';
      case _AnimDemo.stateMachine:
        return _describeAnimator(_pacer);
      case _AnimDemo.blendTree:
        return _describeAnimator(_explorer);
    }
  }

  String get _logLine => switch (_demo) {
    _AnimDemo.aseprite =>
      _eventLog.isEmpty ? '' : 'signals: ${_eventLog.join('  ·  ')}',
    _AnimDemo.stateMachine || _AnimDemo.blendTree =>
      _stateLog.isEmpty ? '' : 'stateChanges: ${_stateLog.join('  ·  ')}',
    _ => '',
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
    final log = _logLine;
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
                  'SpriteAnimationComponent  .  AnimatorComponent  .  Effects',
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
            _statsLine,
            style: TextStyle(
              color: _demo.accentColor.withValues(alpha: 0.85),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          if (log.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              log,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
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
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Loading sprite atlases...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load the atlases:\n$_loadError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFF7043), fontSize: 12),
          ),
        ),
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _handleTap(e.localPosition),
      child: CameraZoomControls(
        camera: _engine.cameraSystem.mainCamera,
        child: GameWidget(engine: _engine, showFPS: true, showDebug: true),
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
              itemCount: _AnimDemo.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final d = _AnimDemo.values[i];
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
                  onSelected: _loading ? null : (_) => _buildDemo(d),
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
    return switch (_demo) {
      _AnimDemo.atlasClips => _buildAtlasClipsControls(),
      _AnimDemo.aseprite => _buildAsepriteControls(),
      _AnimDemo.multiPage => _buildMultiPageControls(),
      _AnimDemo.stateMachine => _buildStateMachineControls(),
      _AnimDemo.blendTree => _buildBlendTreeControls(),
    };
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white54, fontSize: 12),
    ),
  );

  Widget _buildAtlasClipsControls() {
    const accent = Color(0xFF29B6F6);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _label('switchClip:'),
            for (final c in ['idle', 'walk', 'smear']) ...[
              _actionButton(
                c,
                accent,
                _atlasClip == c ? null : () => _switchAtlasClip(c),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 10),
            _label('Count:'),
            Expanded(
              child: Slider(
                value: _characterCount.toDouble(),
                min: 1,
                max: 36,
                divisions: 35,
                label: '$_characterCount',
                onChanged: (v) => setState(() => _characterCount = v.round()),
                onChangeEnd: (_) => _buildDemo(_demo),
              ),
            ),
          ],
        ),
        Row(
          children: [
            _label('speed:'),
            Expanded(
              child: Slider(
                value: _atlasSpeed,
                min: -2.0,
                max: 3.0,
                divisions: 50,
                label: 'x${_atlasSpeed.toStringAsFixed(1)}',
                onChanged: _setAtlasSpeed,
              ),
            ),
            _actionButton('Respawn', accent, () => _buildDemo(_demo)),
          ],
        ),
      ],
    );
  }

  Widget _buildAsepriteControls() {
    const accent = Color(0xFFFFCA28);
    final anim = _asepriteHero?.getComponent<SpriteAnimationComponent>();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label('Tag:'),
        for (final (clip, text) in const [
          ('walk', 'walk'),
          ('walk_back', 'walk_back (reverse)'),
          ('sway', 'sway (pingpong)'),
          ('step', 'step (one-shot)'),
        ])
          _actionButton(
            text,
            _asepriteClip == clip ? accent : const Color(0xFF2A4060),
            () => _playAsepriteClip(clip),
          ),
        _actionButton(
          anim?.isPlaying ?? false ? 'Pause' : 'Play',
          const Color(0xFF78909C),
          _toggleAsepritePlay,
        ),
      ],
    );
  }

  Widget _buildMultiPageControls() {
    const accent = Color(0xFFAB47BC);
    return Row(
      children: [
        _label('Mode:'),
        for (final m in ['idle', 'run']) ...[
          _actionButton(
            m,
            accent,
            _topDownMode == m ? null : () => _switchTopDownMode(m),
          ),
          const SizedBox(width: 6),
        ],
        const SizedBox(width: 16),
        const Flexible(
          child: Text(
            '4 sprites  .  8-page atlas  .  page image follows the clip',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildStateMachineControls() {
    const accent = Color(0xFF66BB6A);
    return Row(
      children: [
        _label('Walk speed:'),
        Expanded(
          child: Slider(
            value: _paceSpeed,
            min: 0,
            max: 240,
            divisions: 24,
            label: '${_paceSpeed.round()} px/s',
            onChanged: _setPaceSpeed,
          ),
        ),
        _actionButton('Hop (trigger)', accent, _hop),
        const SizedBox(width: 6),
        _actionButton(
          'Stop',
          const Color(0xFF78909C),
          _paceSpeed == 0 ? null : () => _setPaceSpeed(0),
        ),
      ],
    );
  }

  Widget _buildBlendTreeControls() {
    const accent = Color(0xFFFF7043);
    return Row(
      children: [
        _actionButton(_wander ? 'Wander: on' : 'Wander: off', accent, () {
          setState(() => _wander = !_wander);
          _explorer?.getComponent<_SeekComponent>()?.wander = _wander;
        }),
        const SizedBox(width: 12),
        _label('Speed:'),
        Expanded(
          child: Slider(
            value: _seekSpeed,
            min: 40,
            max: 240,
            divisions: 20,
            label: '${_seekSpeed.round()} px/s',
            onChanged: (v) {
              setState(() => _seekSpeed = v);
              _explorer?.getComponent<_SeekComponent>()?.speed = v;
            },
          ),
        ),
        const Text(
          'Tap the canvas to set a target',
          style: TextStyle(color: Colors.white30, fontSize: 11),
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
                  'just_game_engine  .  sprite animation API',
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

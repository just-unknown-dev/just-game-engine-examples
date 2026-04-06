import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _AnimDemo {
  spriteAtlas,
  clipRegistry,
  topDown,
  perFrame;

  String get label => switch (this) {
    spriteAtlas => 'Sprite Atlas',
    clipRegistry => 'Clip Registry',
    topDown => 'Multi-Page',
    perFrame => 'Per-Frame Timing',
  };

  IconData get icon => switch (this) {
    spriteAtlas => Icons.layers_outlined,
    clipRegistry => Icons.movie_filter_outlined,
    topDown => Icons.view_comfy_alt_outlined,
    perFrame => Icons.timer_outlined,
  };

  Color get accentColor => switch (this) {
    spriteAtlas => const Color(0xFF29B6F6),
    clipRegistry => const Color(0xFF66BB6A),
    topDown => const Color(0xFFAB47BC),
    perFrame => const Color(0xFFFFCA28),
  };

  String get description => switch (this) {
    spriteAtlas =>
      'A SpriteAtlas is built from info.json, creating a two-page atlas '
          '(idle=page0, walk=page1). All sprites share the same atlas; '
          'AtlasSpriteAnimation updates only sourceRect each tick — zero heap allocation per frame.',
    clipRegistry =>
      'One SpriteAtlas can hold many named AtlasAnimationClips. registerClip() adds '
          'runtime clips at any time. Switching is a single createAnimation() call — '
          'page swaps and trim correction are handled automatically.',
    topDown =>
      'Multi-page atlas: each of the 8 direction images is a separate SpriteAtlasPage '
          'inside one SpriteAtlas. AtlasSpriteAnimation swaps Sprite.image transparently '
          'whenever a frame crosses a page boundary.',
    perFrame =>
      'Each AtlasFrame carries its own duration in seconds, enabling anticipation / '
          'follow-through timing identical to Aseprite per-frame delays. Frame lookup '
          'uses O(log n) binary-search over a pre-built cumulative time table.',
  };

  String get codeSnippet => switch (this) {
    spriteAtlas =>
      '// Two-page atlas built from grid sprite-sheets:\n'
          'final atlas = SpriteAtlas(\n'
          '  name: \'character02\',\n'
          '  pages: [idlePage, walkPage],  // SpriteAtlasPage(image: ...)\n'
          '  regions: regionMap,            // \'idle_0\'..\'walk_23\' -> SpriteRegion\n'
          '  clips: {\'idle\': idleClip, \'walk\': walkClip},\n'
          ');\n\n'
          'final sprite = atlas.createSprite(\'idle_0\', position: pos);\n'
          'final anim   = atlas.createAnimation(\'idle\', sprite);\n'
          '// Manually tick: anim.update(dt)  -- or pass to AnimationSystem',
    clipRegistry =>
      '// Register a runtime clip (3 hand-picked walk frames):\n'
          'atlas.registerClip(AtlasAnimationClip(\n'
          '  name: \'preview\',\n'
          '  loop: true,\n'
          '  frames: [\n'
          '    AtlasFrame(regionName: \'walk_0\',  duration: 0.12),\n'
          '    AtlasFrame(regionName: \'walk_8\',  duration: 0.08),\n'
          '    AtlasFrame(regionName: \'walk_16\', duration: 0.08),\n'
          '  ],\n'
          '));\n\n'
          '// Switch clip at runtime:\n'
          'final newAnim = atlas.createAnimation(\'preview\', sprite);\n'
          'engine.animation.remove(prevAnim);\n'
          'engine.animation.add(newAnim);',
    topDown =>
      '// Multi-page: one SpriteAtlasPage per direction image\n'
          'final pages = <SpriteAtlasPage>[];\n'
          'for (int i = 0; i < directions.length; i++) {\n'
          '  pages.add(SpriteAtlasPage(\n'
          '    index: i,\n'
          '    imagePath: directions[i] + \'.png\',\n'
          '    size: Size(imageW, imageH),\n'
          '    image: loadedImages[i],\n'
          '  ));\n'
          '}\n'
          'final atlas = SpriteAtlas(\n'
          '  name: \'char03\',\n'
          '  pages: pages,            // pageIndex = direction index\n'
          '  regions: regions,\n'
          '  clips: clips,\n'
          ');\n'
          '// applyFrame() swaps Sprite.image when frame crosses a page boundary',
    perFrame =>
      '// Non-uniform frame durations (anticipation + follow-through):\n'
          'atlas.registerClip(AtlasAnimationClip(\n'
          '  name: \'walk_smear\',\n'
          '  loop: true,\n'
          '  frames: [\n'
          '    AtlasFrame(regionName: \'walk_0\',  duration: 0.20), // anticipation\n'
          '    AtlasFrame(regionName: \'walk_1\',  duration: 0.05),\n'
          '    AtlasFrame(regionName: \'walk_8\',  duration: 0.05),\n'
          '    AtlasFrame(regionName: \'walk_16\', duration: 0.05),\n'
          '    AtlasFrame(regionName: \'walk_20\', duration: 0.18), // follow-through\n'
          '  ],\n'
          '));\n'
          '// Frame index resolved via O(log n) cumulative-duration binary search\n'
          'final anim = atlas.createAnimation(\'walk_smear\', sprite);\n'
          'anim.speed = 1.5; // scale the entire clip uniformly',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS -- private components & systems
// ─────────────────────────────────────────────────────────────────────────────

class _AtlasAnimComponent extends Component {
  AtlasSpriteAnimation? anim;
  _AtlasAnimComponent({this.anim});
}

class _AtlasAnimSystem extends System {
  @override
  List<Type> get requiredComponents => [_AtlasAnimComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      entity.getComponent<_AtlasAnimComponent>()!.anim?.update(dt);
    });
  }
}

class _FloatComponent extends Component {
  final Offset origin;
  final double amplitudeY;
  final double speed;
  final double phase;
  double time = 0;
  _FloatComponent({
    required this.origin,
    required this.amplitudeY,
    required this.speed,
    required this.phase,
  });
}

class _FloatSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _FloatComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final f = entity.getComponent<_FloatComponent>()!;
      f.time += dt;
      t.position = Offset(
        f.origin.dx,
        f.origin.dy + math.sin(f.phase + f.time * f.speed) * f.amplitudeY,
      );
    });
  }
}

// Internal data class used by _buildGridAtlas.
class _ClipData {
  const _ClipData({
    required this.clipName,
    required this.image,
    required this.imagePath,
    required this.pageIndex,
    required this.frameWidth,
    required this.frameHeight,
    required this.frameCount,
    required this.linear,
    required this.fps,
  });
  final String clipName;
  final ui.Image image;
  final String imagePath;
  final int pageIndex;
  final int frameWidth;
  final int frameHeight;
  final int frameCount;
  final bool linear;
  final double fps;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AnimationSystemScreen extends StatefulWidget {
  const AnimationSystemScreen({super.key});

  @override
  State<AnimationSystemScreen> createState() => _AnimationSystemScreenState();
}

class _AnimationSystemScreenState extends State<AnimationSystemScreen>
    with SingleTickerProviderStateMixin {
  static const _char02Root = 'assets/sprites/characters/character02';
  static const _char03Root = 'assets/sprites/characters/character03';

  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  final GlobalKey _gameWidgetKey = GlobalKey();
  final math.Random _random = math.Random();

  Duration _lastTick = Duration.zero;

  // Demo state
  _AnimDemo _demo = _AnimDemo.spriteAtlas;
  bool _loading = true;
  String _statusMessage = '';

  // Atlases (built once; shared across demos)
  SpriteAtlas? _char02Atlas;
  SpriteAtlas? _char03Atlas;

  // Sprite Atlas demo controls
  int _characterCount = 12;
  String _atlasClip = 'idle';
  double _atlasSpeed = 1.0;

  // Clip Registry demo controls
  String _registryClip = 'idle';

  // Top-Down demo controls
  String _topDownMode = 'idle';

  // Per-Frame demo (live ref for speed without world rebuild)
  double _perFrameSpeed = 1.0;
  AtlasSpriteAnimation? _perFrameAnim;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world.destroyAllEntities();
    _world.clearSystems();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Loading
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    setState(() => _loading = true);
    await _loadAtlases();
    if (!mounted) return;
    _buildDemo(_demo);
    setState(() => _loading = false);
  }

  Future<void> _loadAtlases() async {
    // Character02: two-page atlas (idle = page 0, walk = page 1)
    final c02Json =
        (await _engine.assets.loadJson('$_char02Root/info.json')).data
            as Map<String, dynamic>;
    final sheet02 = c02Json['spriteSheet'] as Map<String, dynamic>;
    final idleInfo = sheet02['idle'] as Map<String, dynamic>;
    final walkInfo = sheet02['walk'] as Map<String, dynamic>;

    final idlePath = '$_char02Root/${idleInfo['imagePath']}';
    final walkPath = '$_char02Root/${walkInfo['imagePath']}';
    final idleImg = (await _engine.assets.loadImage(idlePath)).image!;
    final walkImg = (await _engine.assets.loadImage(walkPath)).image!;

    _char02Atlas = _buildGridAtlas(
      atlasName: 'character02',
      clips: [
        _ClipData(
          clipName: 'idle',
          image: idleImg,
          imagePath: idlePath,
          pageIndex: 0,
          frameWidth: idleInfo['frameWidth'] as int,
          frameHeight: idleInfo['frameHeight'] as int,
          frameCount: idleInfo['frameCount'] as int,
          linear: (idleInfo['linear'] as bool?) ?? true,
          fps: 10.0,
        ),
        _ClipData(
          clipName: 'walk',
          image: walkImg,
          imagePath: walkPath,
          pageIndex: 1,
          frameWidth: walkInfo['frameWidth'] as int,
          frameHeight: walkInfo['frameHeight'] as int,
          frameCount: walkInfo['frameCount'] as int,
          linear: (walkInfo['linear'] as bool?) ?? false,
          fps: 12.0,
        ),
      ],
    );

    // Character03: 8-page multi-direction atlas
    final c03Json =
        (await _engine.assets.loadJson('$_char03Root/info.json')).data
            as Map<String, dynamic>;
    final sheet03 = c03Json['spriteSheet'] as Map<String, dynamic>;

    final pages03 = <SpriteAtlasPage>[];
    final regions03 = <String, SpriteRegion>{};
    final clips03 = <String, AtlasAnimationClip>{};
    int pageIdx = 0;

    for (final entry in sheet03.entries) {
      final clipName = entry.key;
      final info = entry.value as Map<String, dynamic>;
      final imgPath = '$_char03Root/${info['imagePath']}';
      final img = (await _engine.assets.loadImage(imgPath)).image!;
      final fw = info['frameWidth'] as int;
      final fh = info['frameHeight'] as int;
      final fc = info['frameCount'] as int;

      pages03.add(
        SpriteAtlasPage(
          index: pageIdx,
          imagePath: imgPath,
          size: Size(img.width.toDouble(), img.height.toDouble()),
          image: img,
        ),
      );

      final frames = <AtlasFrame>[];
      for (int f = 0; f < fc; f++) {
        final rn = '${clipName}_$f';
        regions03[rn] = SpriteRegion(
          name: rn,
          pageIndex: pageIdx,
          frame: Rect.fromLTWH(
            (f * fw).toDouble(),
            0,
            fw.toDouble(),
            fh.toDouble(),
          ),
          sourceSize: Size(fw.toDouble(), fh.toDouble()),
        );
        frames.add(AtlasFrame(regionName: rn, duration: 0.1));
      }
      clips03[clipName] = AtlasAnimationClip(
        name: clipName,
        frames: frames,
        loop: true,
      );
      pageIdx++;
    }

    _char03Atlas = SpriteAtlas(
      name: 'character03',
      pages: pages03,
      regions: regions03,
      clips: clips03,
    );
  }

  SpriteAtlas _buildGridAtlas({
    required String atlasName,
    required List<_ClipData> clips,
  }) {
    final pages = <SpriteAtlasPage>[];
    final regions = <String, SpriteRegion>{};
    final clipMap = <String, AtlasAnimationClip>{};

    for (final cd in clips) {
      pages.add(
        SpriteAtlasPage(
          index: cd.pageIndex,
          imagePath: cd.imagePath,
          size: Size(cd.image.width.toDouble(), cd.image.height.toDouble()),
          image: cd.image,
        ),
      );

      final frameDuration = 1.0 / cd.fps;
      final frames = <AtlasFrame>[];

      for (int i = 0; i < cd.frameCount; i++) {
        final int x, y;
        if (cd.linear) {
          x = i * cd.frameWidth;
          y = 0;
        } else {
          final cols = cd.image.width ~/ cd.frameWidth;
          x = (i % cols) * cd.frameWidth;
          y = (i ~/ cols) * cd.frameHeight;
        }
        final rn = '${cd.clipName}_$i';
        regions[rn] = SpriteRegion(
          name: rn,
          pageIndex: cd.pageIndex,
          frame: Rect.fromLTWH(
            x.toDouble(),
            y.toDouble(),
            cd.frameWidth.toDouble(),
            cd.frameHeight.toDouble(),
          ),
          sourceSize: Size(cd.frameWidth.toDouble(), cd.frameHeight.toDouble()),
        );
        frames.add(AtlasFrame(regionName: rn, duration: frameDuration));
      }
      clipMap[cd.clipName] = AtlasAnimationClip(
        name: cd.clipName,
        frames: frames,
        loop: true,
      );
    }
    return SpriteAtlas(
      name: atlasName,
      pages: pages,
      regions: regions,
      clips: clipMap,
    );
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

  void _buildDemo(_AnimDemo demo) {
    if (_char02Atlas == null || _char03Atlas == null) return;

    _demo = demo;
    _perFrameAnim = null;
    _statusMessage = '';

    _world.destroyAllEntities();
    _world.clearSystems();

    _engine.rendering.camera
      ..viewportSize = _readViewportSize()
      ..position = Offset.zero
      ..rotation = 0
      ..zoom = 1;

    _world.addSystem(_AtlasAnimSystem()..priority = 90);
    _world.addSystem(_FloatSystem()..priority = 80);
    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));

    _spawnBackdrop();

    switch (demo) {
      case _AnimDemo.spriteAtlas:
        _buildSpriteAtlasDemo();
      case _AnimDemo.clipRegistry:
        _buildClipRegistryDemo();
      case _AnimDemo.topDown:
        _buildTopDownDemo();
      case _AnimDemo.perFrame:
        _buildPerFrameDemo();
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

  // Sprite Atlas demo
  void _buildSpriteAtlasDemo() {
    final atlas = _char02Atlas!;
    final rows = (_characterCount / 6).ceil();
    final cols = (_characterCount / rows).ceil();
    const sx = 120.0, sy = 130.0;
    final startX = -((cols - 1) * sx) / 2;

    for (int i = 0; i < _characterCount; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      final pos = Offset(startX + col * sx, -30.0 + row * sy);

      final sprite = atlas.createSprite('${_atlasClip}_0', layer: 6);
      sprite.position = pos;
      final anim = atlas.createAnimation(
        _atlasClip,
        sprite,
        speed: _atlasSpeed,
      );

      _world.createEntityWithComponents([
        TransformComponent(position: pos),
        RenderableComponent(renderable: sprite),
        _AtlasAnimComponent(anim: anim),
        _FloatComponent(
          origin: pos,
          amplitudeY: 6 + _random.nextDouble() * 8,
          speed: 1.0 + _random.nextDouble() * 0.8,
          phase: _random.nextDouble() * math.pi * 2,
        ),
      ], name: 'char-$i');
    }

    final clip = atlas.requireClip(_atlasClip);
    _statusMessage =
        'atlas: ${atlas.regionCount} regions · ${atlas.clipNames.length} clips '
        '· ${atlas.pages.length} pages  |  '
        'clip "$_atlasClip": ${clip.frames.length} frames · '
        '${clip.totalDuration.toStringAsFixed(2)}s';
  }

  // Clip Registry demo
  void _buildClipRegistryDemo() {
    final atlas = _char02Atlas!;

    atlas.registerClip(
      AtlasAnimationClip(
        name: 'preview',
        loop: true,
        frames: [
          AtlasFrame(regionName: 'walk_0', duration: 0.12),
          AtlasFrame(regionName: 'walk_8', duration: 0.08),
          AtlasFrame(regionName: 'walk_16', duration: 0.08),
        ],
      ),
    );

    final firstRegion = atlas
        .requireClip(_registryClip)
        .frames
        .first
        .regionName;
    final sprite = atlas.createSprite(firstRegion, scale: 3.0, layer: 6);
    final anim = atlas.createAnimation(_registryClip, sprite);

    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(renderable: sprite),
      _AtlasAnimComponent(anim: anim),
    ], name: 'solo-char');

    final clip = atlas.requireClip(_registryClip);
    _statusMessage =
        'active clip: "$_registryClip" · ${clip.frames.length} frames · '
        '${clip.totalDuration.toStringAsFixed(2)}s · '
        '${atlas.clipNames.length} clips registered';
  }

  // Top-Down multi-page demo
  void _buildTopDownDemo() {
    final atlas = _char03Atlas!;
    const dirs = ['down', 'right', 'up', 'left'];
    const positions = [
      Offset(0, 110),
      Offset(160, 0),
      Offset(0, -110),
      Offset(-160, 0),
    ];

    for (int i = 0; i < dirs.length; i++) {
      final clipName = '${_topDownMode}_${dirs[i]}';
      final sprite = atlas.createSprite('${clipName}_0', scale: 2.0, layer: 6);
      sprite.position = positions[i];
      final anim = atlas.createAnimation(clipName, sprite);

      _world.createEntityWithComponents([
        TransformComponent(position: positions[i]),
        RenderableComponent(renderable: sprite),
        _AtlasAnimComponent(anim: anim),
      ], name: 'dir-${dirs[i]}');
    }

    _statusMessage =
        'multi-page atlas: ${atlas.pages.length} pages · '
        '${atlas.regionCount} regions · ${atlas.clipNames.length} clips  |  '
        'mode: $_topDownMode';
  }

  // Per-Frame timing demo
  void _buildPerFrameDemo() {
    final atlas = _char02Atlas!;

    atlas.registerClip(
      AtlasAnimationClip(
        name: 'walk_smear',
        loop: true,
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

    final sprite = atlas.createSprite('walk_0', scale: 3.5, layer: 6);
    final anim = atlas.createAnimation(
      'walk_smear',
      sprite,
      speed: _perFrameSpeed,
    );
    _perFrameAnim = anim;

    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(renderable: sprite),
      _AtlasAnimComponent(anim: anim),
    ], name: 'perframe-char');

    final clip = atlas.requireClip('walk_smear');
    _statusMessage =
        '${clip.frames.length}-frame walk_smear clip · '
        '${clip.totalDuration.toStringAsFixed(2)}s total · '
        'O(log n) binary-search frame lookup';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  Size _readViewportSize() {
    final ro = _gameWidgetKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) return ro.size;
    return MediaQuery.sizeOf(context);
  }

  String get _statsLine {
    final a2 = _char02Atlas;
    final a3 = _char03Atlas;
    if (a2 == null || a3 == null) return 'loading...';
    return 'char02  ${a2.regionCount} regions · ${a2.pages.length} pages'
        '  |  char03  ${a3.regionCount} regions · ${a3.pages.length} pages';
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
                'SpriteAtlas  .  AtlasSpriteAnimation  .  AtlasAnimationClip',
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
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Building sprite atlases...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }
    return CameraZoomControls(
      camera: _engine.rendering.camera,
      child: GameWidget(
        key: _gameWidgetKey,
        engine: _engine,
        showFPS: true,
        showDebug: false,
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
    switch (_demo) {
      case _AnimDemo.spriteAtlas:
        return _buildSpriteAtlasControls();
      case _AnimDemo.clipRegistry:
        return _buildClipRegistryControls();
      case _AnimDemo.topDown:
        return _buildTopDownControls();
      case _AnimDemo.perFrame:
        return _buildPerFrameControls();
    }
  }

  Widget _buildSpriteAtlasControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              'Clip:',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(width: 8),
            for (final c in ['idle', 'walk']) ...[
              _actionButton(
                c,
                const Color(0xFF29B6F6),
                _atlasClip == c
                    ? null
                    : () => setState(() {
                        _atlasClip = c;
                        _buildDemo(_demo);
                      }),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 16),
            const Text(
              'Count:',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
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
            const Text(
              'Speed:',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Expanded(
              child: Slider(
                value: _atlasSpeed,
                min: 0.2,
                max: 3.0,
                divisions: 28,
                label: 'x${_atlasSpeed.toStringAsFixed(1)}',
                onChanged: (v) => setState(() => _atlasSpeed = v),
                onChangeEnd: (_) => _buildDemo(_demo),
              ),
            ),
            _actionButton(
              'Respawn',
              const Color(0xFF29B6F6),
              () => _buildDemo(_demo),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClipRegistryControls() {
    return Row(
      children: [
        const Text(
          'Active clip:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 8),
        for (final c in ['idle', 'walk', 'preview']) ...[
          _actionButton(
            c == 'preview' ? 'preview (runtime)' : c,
            const Color(0xFF66BB6A),
            _registryClip == c
                ? null
                : () => setState(() {
                    _registryClip = c;
                    _buildDemo(_demo);
                  }),
          ),
          const SizedBox(width: 6),
        ],
        const Spacer(),
        const Text(
          '2 file clips + 1 runtime registered',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildTopDownControls() {
    return Row(
      children: [
        const Text(
          'Mode:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 8),
        for (final m in ['idle', 'run']) ...[
          _actionButton(
            m,
            const Color(0xFFAB47BC),
            _topDownMode == m
                ? null
                : () => setState(() {
                    _topDownMode = m;
                    _buildDemo(_demo);
                  }),
          ),
          const SizedBox(width: 6),
        ],
        const SizedBox(width: 16),
        const Text(
          '4 chars  .  8-page atlas  .  image swapped per-frame',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPerFrameControls() {
    return Row(
      children: [
        const Text(
          'Speed:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Expanded(
          child: Slider(
            value: _perFrameSpeed,
            min: 0.1,
            max: 4.0,
            divisions: 39,
            label: 'x${_perFrameSpeed.toStringAsFixed(1)}',
            onChanged: (v) {
              setState(() => _perFrameSpeed = v);
              _perFrameAnim?.speed = v; // live update -- no world rebuild
            },
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '7-frame walk_smear  .  non-uniform durations',
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
                  'just_game_engine  .  SpriteAtlas API',
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

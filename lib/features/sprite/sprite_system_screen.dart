import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _SpriteDemo {
  environment,
  atlasInspector,
  characters;

  String get label => switch (this) {
    environment => 'Environment',
    atlasInspector => 'Atlas Inspector',
    characters => 'Characters',
  };

  IconData get icon => switch (this) {
    environment => Icons.landscape_outlined,
    atlasInspector => Icons.grid_on_outlined,
    characters => Icons.people_outline,
  };

  Color get accentColor => switch (this) {
    environment => const Color(0xFF81C784),
    atlasInspector => const Color(0xFF4DD0E1),
    characters => const Color(0xFFFFB74D),
  };

  String get description => switch (this) {
    environment =>
      'Three house sprites loaded as a SpriteAtlas — one SpriteAtlasPage per '
          'image, one full-image SpriteRegion per house. atlas.createSprite() '
          'instantiates each sprite from its region name.',
    atlasInspector =>
      'Visualises the raw packed texture of the character02 idle atlas. Each '
          'SpriteRegion frame is outlined directly on the sheet so you can see '
          'exactly what the atlas parser extracted.',
    characters =>
      'First frame of every clip in the character03 multi-page atlas laid out '
          'in a grid. Each sprite comes from a different texture page, demonstrating '
          'that createSprite() works across page boundaries.',
  };

  String get codeSnippet => switch (this) {
    environment =>
      '// Build a 3-page atlas from individual house images:\n'
          'final pages = <SpriteAtlasPage>[\n'
          '  SpriteAtlasPage(index: 0, imagePath: h1, size: Size(256,160), image: img1),\n'
          '  SpriteAtlasPage(index: 1, imagePath: h2, size: Size(384,256), image: img2),\n'
          '  SpriteAtlasPage(index: 2, imagePath: h3, size: Size(608,352), image: img3),\n'
          '];\n'
          'final atlas = SpriteAtlas(name: \'houses\', pages: pages, regions: regions);\n\n'
          '// Instantiate from region name -- no manual Rect math needed:\n'
          'final sprite = atlas.createSprite(\'house_01\', position: pos, scale: 0.45);',
    atlasInspector =>
      '// Iterate every region the parser extracted:\n'
          'for (final name in atlas.regionNames) {\n'
          '  final region = atlas.getRegion(name)!;   // SpriteRegion\n'
          '  final page   = atlas.pages[region.pageIndex];\n'
          '  print(\'\$name  frame:\${region.frame}  sourceSize:\${region.sourceSize}\');\n'
          '}\n\n'
          '// Atlas stats:\n'
          'print(\'regions: \${atlas.regionCount}\');\n'
          'print(\'clips:   \${atlas.clipNames.length}\');',
    characters =>
      '// Multi-page atlas: each page is a different direction image.\n'
          '// createSprite() returns a Sprite pointing at the correct page:\n'
          'for (final clipName in atlas.clipNames) {\n'
          '  final firstRegion = atlas.requireClip(clipName).frames.first.regionName;\n'
          '  final sprite = atlas.createSprite(\n'
          '    firstRegion,          // e.g. \'idle_down_0\'\n'
          '    scale: 2.0,\n'
          '    position: gridPos,\n'
          '  );\n'
          '  // sprite.image is already set to the correct page texture\n'
          '}',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SpriteSystemScreen extends StatefulWidget {
  const SpriteSystemScreen({super.key});

  @override
  State<SpriteSystemScreen> createState() => _SpriteSystemScreenState();
}

class _SpriteSystemScreenState extends State<SpriteSystemScreen>
    with SingleTickerProviderStateMixin {
  static const _houseRoot = 'assets/sprites/environment/house';
  static const _char02Root = 'assets/sprites/characters/character02';
  static const _char03Root = 'assets/sprites/characters/character03';

  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  final GlobalKey _gameWidgetKey = GlobalKey();

  Duration _lastTick = Duration.zero;

  // Demo state
  _SpriteDemo _demo = _SpriteDemo.environment;
  bool _loading = true;
  String _statusMessage = '';

  // Atlases (built once, shared across demos)
  SpriteAtlas? _houseAtlas;
  SpriteAtlas? _char02Atlas;
  SpriteAtlas? _char03Atlas;

  // Environment demo controls
  double _envScale = 0.45;

  // Inspector demo
  double _inspectorScale = 3.5;

  // Characters demo
  double _charScale = 2.0;

  // Credit info from house info.json
  String _houseArtist = '';
  String _houseSource = '';

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
    // ── Houses ────────────────────────────────────────────────────────────
    final houseJson =
        (await _engine.assets.loadJson('$_houseRoot/info.json')).data
            as Map<String, dynamic>;

    final credits = houseJson['credits'] as Map<String, dynamic>?;
    _houseArtist = (credits?['artist'] as String?) ?? '';
    _houseSource = (credits?['source'] as String?) ?? '';

    final spritesMap =
        (houseJson['sprites'] as Map<String, dynamic>?) ?? const {};
    final houseNames = spritesMap.keys.toList()..sort();

    final housePages = <SpriteAtlasPage>[];
    final houseRegions = <String, SpriteRegion>{};

    for (int i = 0; i < houseNames.length; i++) {
      final key = houseNames[i];
      final info = spritesMap[key] as Map<String, dynamic>;
      final imgPath = '$_houseRoot/${info['imagePath']}';
      final w = (info['width'] as int).toDouble();
      final h = (info['height'] as int).toDouble();
      final img = (await _engine.assets.loadImage(imgPath)).image!;

      housePages.add(
        SpriteAtlasPage(
          index: i,
          imagePath: imgPath,
          size: Size(w, h),
          image: img,
        ),
      );
      houseRegions[key] = SpriteRegion(
        name: key,
        pageIndex: i,
        frame: Rect.fromLTWH(0, 0, w, h),
        sourceSize: Size(w, h),
      );
    }

    _houseAtlas = SpriteAtlas(
      name: 'houses',
      pages: housePages,
      regions: houseRegions,
    );

    // ── Character02: single-page idle atlas ───────────────────────────────
    final c02Json =
        (await _engine.assets.loadJson('$_char02Root/info.json')).data
            as Map<String, dynamic>;
    final sheet02 = c02Json['spriteSheet'] as Map<String, dynamic>;
    final idleInfo = sheet02['idle'] as Map<String, dynamic>;
    final idlePath = '$_char02Root/${idleInfo['imagePath']}';
    final idleImg = (await _engine.assets.loadImage(idlePath)).image!;

    final fw02 = idleInfo['frameWidth'] as int;
    final fh02 = idleInfo['frameHeight'] as int;
    final fc02 = idleInfo['frameCount'] as int;

    final idlePage = SpriteAtlasPage(
      index: 0,
      imagePath: idlePath,
      size: Size(idleImg.width.toDouble(), idleImg.height.toDouble()),
      image: idleImg,
    );
    final idleRegions = <String, SpriteRegion>{};
    final idleFrames = <AtlasFrame>[];
    for (int i = 0; i < fc02; i++) {
      final rn = 'idle_$i';
      idleRegions[rn] = SpriteRegion(
        name: rn,
        pageIndex: 0,
        frame: Rect.fromLTWH(
          (i * fw02).toDouble(),
          0,
          fw02.toDouble(),
          fh02.toDouble(),
        ),
        sourceSize: Size(fw02.toDouble(), fh02.toDouble()),
      );
      idleFrames.add(AtlasFrame(regionName: rn, duration: 0.1));
    }
    _char02Atlas = SpriteAtlas(
      name: 'character02_idle',
      pages: [idlePage],
      regions: idleRegions,
      clips: {
        'idle': AtlasAnimationClip(
          name: 'idle',
          frames: idleFrames,
          loop: true,
        ),
      },
    );

    // ── Character03: 8-page multi-direction atlas ─────────────────────────
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

  void _buildDemo(_SpriteDemo demo) {
    if (_houseAtlas == null || _char02Atlas == null || _char03Atlas == null) {
      return;
    }

    _demo = demo;
    _statusMessage = '';

    _world.destroyAllEntities();
    _world.clearSystems();

    _engine.rendering.camera
      ..viewportSize = _readViewportSize()
      ..position = Offset.zero
      ..rotation = 0
      ..zoom = 1;

    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));

    switch (demo) {
      case _SpriteDemo.environment:
        _buildEnvironmentDemo();
      case _SpriteDemo.atlasInspector:
        _buildAtlasInspectorDemo();
      case _SpriteDemo.characters:
        _buildCharactersDemo();
    }

    if (mounted) setState(() {});
  }

  // ── Environment demo ──────────────────────────────────────────────────────

  void _buildEnvironmentDemo() {
    final atlas = _houseAtlas!;
    _spawnNatureBackdrop();

    const spacing = 420.0;
    final names = atlas.regionNames.toList()..sort();
    final startX = -((names.length - 1) * spacing) / 2;

    for (int i = 0; i < names.length; i++) {
      final name = names[i];
      final region = atlas.getRegion(name)!;
      final renderH = region.sourceSize.height * _envScale;
      final pos = Offset(startX + i * spacing, 0);

      final sprite = atlas.createSprite(name, scale: _envScale, layer: 8);
      sprite.position = pos;

      _world.createEntityWithComponents([
        TransformComponent(position: pos),
        RenderableComponent(syncTransform: true, renderable: sprite),
      ], name: name);

      // Label below
      _world.createEntityWithComponents([
        TransformComponent(position: Offset(pos.dx, pos.dy + renderH / 2 + 20)),
        RenderableComponent(
          renderable: TextRenderable(
            text:
                '$name  •  ${region.sourceSize.width.toInt()}x${region.sourceSize.height.toInt()}',
            textStyle: const TextStyle(
              color: Color(0xFFF0F5E9),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            layer: 20,
          ),
        ),
      ], name: '${name}_label');
    }

    // Credit
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -220)),
      RenderableComponent(
        renderable: TextRenderable(
          text: 'artist: $_houseArtist  •  source: $_houseSource',
          textStyle: const TextStyle(
            color: Color(0xFF9DD9D2),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          layer: 30,
        ),
      ),
    ], name: 'credit');

    _statusMessage =
        'atlas: ${atlas.regionCount} regions · ${atlas.pages.length} pages  '
        '|  scale: ${_envScale.toStringAsFixed(2)}x';
  }

  void _spawnNatureBackdrop() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          onRender: (canvas, _) {
            final gridPaint = Paint()
              ..color = const Color(0xFF1E2A1F).withValues(alpha: 0.30)
              ..strokeWidth = 1;
            for (double x = -1000; x <= 1000; x += 80) {
              canvas.drawLine(Offset(x, -700), Offset(x, 700), gridPaint);
            }
            for (double y = -700; y <= 700; y += 80) {
              canvas.drawLine(Offset(-1000, y), Offset(1000, y), gridPaint);
            }
            canvas.drawRect(
              const Rect.fromLTRB(-1000, 60, 1000, 280),
              Paint()..color = const Color(0xFF2B3D2E).withValues(alpha: 0.40),
            );
          },
        ),
      ),
    ], name: 'backdrop');
  }

  // ── Atlas Inspector demo ──────────────────────────────────────────────────

  void _buildAtlasInspectorDemo() {
    final atlas = _char02Atlas!;
    final page = atlas.pages[0];
    final img = page.image!;
    final scale = _inspectorScale;

    final colors = [
      const Color(0xFF00E5FF),
      const Color(0xFFFFEA00),
      const Color(0xFF69FF47),
      const Color(0xFFFF6D00),
    ];

    // Atlas sheet + region overlays
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: 6,
          onRender: (canvas, _) {
            final drawW = img.width * scale;
            final drawH = img.height * scale;
            final drawLeft = -drawW / 2;
            final drawTop = -drawH / 2;

            // Draw the raw texture
            canvas.drawImageRect(
              img,
              Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
              Rect.fromLTWH(drawLeft, drawTop, drawW, drawH),
              Paint(),
            );

            // Overlay every region
            final regionList = atlas.regionNames.toList();
            for (int idx = 0; idx < regionList.length; idx++) {
              final rn = regionList[idx];
              final region = atlas.getRegion(rn)!;
              final color = colors[idx % colors.length];

              final scaledRect = Rect.fromLTWH(
                drawLeft + region.frame.left * scale,
                drawTop + region.frame.top * scale,
                region.frame.width * scale,
                region.frame.height * scale,
              );

              // Fill (very subtle)
              canvas.drawRect(
                scaledRect,
                Paint()..color = color.withValues(alpha: 0.08),
              );
              // Border
              canvas.drawRect(
                scaledRect,
                Paint()
                  ..color = color.withValues(alpha: 0.85)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5,
              );

              // Frame index label
              final tp = TextPainter(
                text: TextSpan(
                  text: '$idx',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout();
              tp.paint(canvas, Offset(scaledRect.left + 3, scaledRect.top + 2));
            }
          },
        ),
      ),
    ], name: 'inspector');

    _statusMessage =
        'texture: ${img.width}x${img.height}px  |  '
        '${atlas.regionCount} regions  |  '
        '${atlas.regionNames.first} .. ${atlas.regionNames.last}  |  '
        'scale: ${scale.toStringAsFixed(1)}x';
  }

  // ── Characters demo ───────────────────────────────────────────────────────

  void _buildCharactersDemo() {
    final atlas = _char03Atlas!;
    final clips = atlas.clipNames.toList()..sort();

    // Dark backdrop
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          onRender: (canvas, _) {
            final gp = Paint()
              ..color = const Color(0xFF1A2E40).withValues(alpha: 0.35)
              ..strokeWidth = 1;
            for (double x = -900; x <= 900; x += 72) {
              canvas.drawLine(Offset(x, -700), Offset(x, 700), gp);
            }
            for (double y = -700; y <= 700; y += 72) {
              canvas.drawLine(Offset(-900, y), Offset(900, y), gp);
            }
          },
        ),
      ),
    ], name: 'backdrop');

    // 2-column grid; center the grid
    const cols = 4;
    const sx = 180.0;
    const sy = 170.0;
    const rows = 2;
    final startX = -(cols - 1) * sx / 2;
    final startY = -(rows - 1) * sy / 2 - 20;

    for (int i = 0; i < clips.length && i < cols * rows; i++) {
      final clipName = clips[i];
      final firstRegion = atlas.requireClip(clipName).frames.first.regionName;
      final sprite = atlas.createSprite(
        firstRegion,
        scale: _charScale,
        layer: 8,
      );
      final col = i % cols;
      final row = i ~/ cols;
      final pos = Offset(startX + col * sx, startY + row * sy);
      sprite.position = pos;

      _world.createEntityWithComponents([
        TransformComponent(position: pos),
        RenderableComponent(syncTransform: true, renderable: sprite),
      ], name: 'char-$clipName');

      // Label
      final region = atlas.getRegion(firstRegion)!;
      _world.createEntityWithComponents([
        TransformComponent(
          position: Offset(
            pos.dx,
            pos.dy + region.sourceSize.height * _charScale / 2 + 14,
          ),
        ),
        RenderableComponent(
          renderable: TextRenderable(
            text: clipName,
            textStyle: const TextStyle(
              color: Color(0xFFFFB74D),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            layer: 20,
          ),
        ),
      ], name: 'label-$clipName');
    }

    _statusMessage =
        'char03 atlas: ${atlas.pages.length} pages · '
        '${atlas.regionCount} regions · ${clips.length} clips  |  '
        'showing first frame of each clip';
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
    final h = _houseAtlas;
    final c2 = _char02Atlas;
    final c3 = _char03Atlas;
    if (h == null || c2 == null || c3 == null) return 'loading...';
    return 'houses ${h.regionCount} regions · ${h.pages.length} pages'
        '  |  char02 ${c2.regionCount} regions  '
        '|  char03 ${c3.regionCount} regions · ${c3.pages.length} pages';
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
                'SpriteAtlas  .  SpriteAtlasPage  .  SpriteRegion',
                style: TextStyle(color: Color(0xFF4DD0E1), fontSize: 10),
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
              itemCount: _SpriteDemo.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final d = _SpriteDemo.values[i];
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
      case _SpriteDemo.environment:
        return _buildEnvControls();
      case _SpriteDemo.atlasInspector:
        return _buildInspectorControls();
      case _SpriteDemo.characters:
        return _buildCharacterControls();
    }
  }

  Widget _buildEnvControls() {
    return Row(
      children: [
        const Text(
          'Scale:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Expanded(
          child: Slider(
            value: _envScale,
            min: 0.25,
            max: 1.0,
            divisions: 15,
            label: '${_envScale.toStringAsFixed(2)}x',
            onChanged: (v) => setState(() => _envScale = v),
            onChangeEnd: (_) => _buildDemo(_demo),
          ),
        ),
        _actionButton(
          'Respawn',
          const Color(0xFF81C784),
          () => _buildDemo(_demo),
        ),
        const SizedBox(width: 12),
        Text(
          '${_houseAtlas?.regionCount ?? 0} sprites  •  ${_houseAtlas?.pages.length ?? 0} atlas pages',
          style: const TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildInspectorControls() {
    return Row(
      children: [
        const Text(
          'Zoom:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Expanded(
          child: Slider(
            value: _inspectorScale,
            min: 1.0,
            max: 8.0,
            divisions: 14,
            label: '${_inspectorScale.toStringAsFixed(1)}x',
            onChanged: (v) => setState(() => _inspectorScale = v),
            onChangeEnd: (_) => _buildDemo(_demo),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_char02Atlas?.regionCount ?? 0} regions  •  '
          '${_char02Atlas?.pages.firstOrNull?.image?.width ?? '?'}x'
          '${_char02Atlas?.pages.firstOrNull?.image?.height ?? '?'}px texture',
          style: const TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCharacterControls() {
    return Row(
      children: [
        const Text(
          'Scale:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Expanded(
          child: Slider(
            value: _charScale,
            min: 1.0,
            max: 4.0,
            divisions: 12,
            label: '${_charScale.toStringAsFixed(1)}x',
            onChanged: (v) => setState(() => _charScale = v),
            onChangeEnd: (_) => _buildDemo(_demo),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_char03Atlas?.pages.length ?? 0} pages  •  ${_char03Atlas?.clipNames.length ?? 0} direction clips',
          style: const TextStyle(color: Colors.white30, fontSize: 11),
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

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  autoScroll,
  cameraFollow,
  depthLayers,
  tintEffect;

  String get label => switch (this) {
    autoScroll => 'Auto-Scroll',
    cameraFollow => 'Camera Follow',
    depthLayers => 'Depth Layers',
    tintEffect => 'Tint Effect',
  };

  IconData get icon => switch (this) {
    autoScroll => Icons.swap_horiz,
    cameraFollow => Icons.person_pin_circle,
    depthLayers => Icons.layers,
    tintEffect => Icons.palette,
  };

  Color get accentColor => switch (this) {
    autoScroll => const Color(0xFF26C6DA),
    cameraFollow => const Color(0xFF66BB6A),
    depthLayers => const Color(0xFFFFCA28),
    tintEffect => const Color(0xFFAB47BC),
  };

  String get description => switch (this) {
    autoScroll =>
      'Each layer auto-scrolls via velocityX. Back layers move slowest, '
          'front layers fastest — matching their scroll factor.',
    cameraFollow =>
      'engine.parallax.update(dt, camera.position) feeds camera movement into '
          'each layer scroll offset, producing the depth illusion.',
    depthLayers =>
      'Toggle individual layers on and off to see how the scene is built '
          'from back to front. Opacity is set to 0 to hide a layer.',
    tintEffect =>
      'layer.tint applies a ColorFilter.mode(color, BlendMode.modulate) to '
          'each layer — useful for day/night grading or environmental effects.',
  };

  String get codeSnippet => switch (this) {
    autoScroll =>
      '// Velocity-based auto-scroll (independent of camera):\n'
          'final bg = ParallaxBackground(layers: [\n'
          '  ParallaxLayer(\n'
          '    image: backTreesImg,\n'
          '    scrollFactorX: 0.10,\n'
          '    velocityX: speed * 0.10, // slowest\n'
          '  ),\n'
          '  ParallaxLayer(\n'
          '    image: frontTreesImg,\n'
          '    scrollFactorX: 0.80,\n'
          '    velocityX: speed * 0.80, // fastest\n'
          '  ),\n'
          ']);\n'
          'engine.parallax.addBackground(bg);',
    cameraFollow =>
      '// Camera-driven parallax — call each frame:\n'
          'engine.parallax.update(\n'
          '  deltaTime,\n'
          '  engine.rendering.camera.position,\n'
          ');\n\n'
          '// Each layer offsets by:\n'
          '// scrollX = camera.x * scrollFactorX + autoScrollX\n'
          '// → factor 0.0 = fixed sky\n'
          '// → factor 1.0 = scrolls with camera (foreground)',
    depthLayers =>
      '// Hide a layer by zeroing its opacity:\n'
          'layer.opacity = 0.0; // invisible\n'
          'layer.opacity = 1.0; // fully visible\n\n'
          '// Layers are rendered back → front:\n'
          '// index 0 = Back Trees  (factor 0.10)\n'
          '// index 1 = Mid Trees   (factor 0.35)\n'
          '// index 2 = Lights      (factor 0.55)\n'
          '// index 3 = Front Trees (factor 0.80)',
    tintEffect =>
      '// Apply a tint to a layer:\n'
          'layer.tint = const Color(0xFF2196F3); // blue\n\n'
          '// Remove the tint:\n'
          'layer.tint = null;\n\n'
          '// Internally uses ColorFilter.mode:\n'
          'paint.colorFilter = ColorFilter.mode(\n'
          '  layer.tint!.withValues(alpha: opacity),\n'
          '  BlendMode.modulate,\n'
          ');',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS component + system for camera-follow demo
// ─────────────────────────────────────────────────────────────────────────────

class _BounceComponent extends Component {
  _BounceComponent({
    required this.position,
    required this.velocity,
    required this.bounds,
  });
  Offset position;
  Offset velocity;
  final Rect bounds;
}

class _BounceSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _BounceComponent];

  @override
  void update(double dt) {
    for (final entity in entities) {
      if (!entity.isActive) continue;
      final b = entity.getComponent<_BounceComponent>()!;
      b.position += b.velocity * dt;
      if (b.position.dx <= b.bounds.left || b.position.dx >= b.bounds.right) {
        b.velocity = Offset(-b.velocity.dx, b.velocity.dy);
        b.position = Offset(
          b.position.dx.clamp(b.bounds.left, b.bounds.right),
          b.position.dy,
        );
      }
      if (b.position.dy <= b.bounds.top || b.position.dy >= b.bounds.bottom) {
        b.velocity = Offset(b.velocity.dx, -b.velocity.dy);
        b.position = Offset(
          b.position.dx,
          b.position.dy.clamp(b.bounds.top, b.bounds.bottom),
        );
      }
      entity.getComponent<TransformComponent>()!.position = b.position;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ParallaxSystemScreen extends StatefulWidget {
  const ParallaxSystemScreen({super.key});

  @override
  State<ParallaxSystemScreen> createState() => _ParallaxSystemScreenState();
}

class _ParallaxSystemScreenState extends State<ParallaxSystemScreen>
    with SingleTickerProviderStateMixin {
  // ── Engine ───────────────────────────────────────────────────────────────
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;

  // ── Loading ───────────────────────────────────────────────────────────────
  bool _loading = true;
  final List<_LayerImages> _layerImages = [];
  String _artist = '';
  String _source = '';

  // ── State ─────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.autoScroll;
  String _statusMessage = '';
  ParallaxBackground? _parallaxBg;

  // ── Per-demo controls ─────────────────────────────────────────────────────
  double _scrollSpeed = 40.0;
  final List<bool> _layerVisible = [true, true, true, true];
  _BounceComponent? _playerMover;

  // ── Tint presets ─────────────────────────────────────────────────────────
  int _tintPreset = 0;
  static const List<(String, List<Color?>)> _tintPresets = [
    ('None', [null, null, null, null]),
    (
      'Depth',
      [
        Color(0xFF1A237E),
        Color(0xFF2E7D32),
        Color(0xFFF9A825),
        Color(0xFF1B5E20),
      ],
    ),
    (
      'Dusk',
      [
        Color(0xFF4A148C),
        Color(0xFF880E4F),
        Color(0xFFE65100),
        Color(0xFF212121),
      ],
    ),
    (
      'Dawn',
      [
        Color(0xFF01579B),
        Color(0xFF006064),
        Color(0xFFFFF9C4),
        Color(0xFF1B5E20),
      ],
    ),
  ];

  // ── Asset paths ───────────────────────────────────────────────────────────
  static const String _root = 'assets/sprites/environment/parallax';

  static const List<_LayerDef> _layerDefs = [
    _LayerDef('parallax-forest-back-trees.png', 'Back Trees', 0.10),
    _LayerDef('parallax-forest-middle-trees.png', 'Mid Trees', 0.35),
    _LayerDef('parallax-forest-lights.png', 'Lights', 0.55),
    _LayerDef('parallax-forest-front-trees.png', 'Front Trees', 0.80),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAssets());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.parallax.clear();
    _engine.rendering.onRenderBackground = _engine.parallax.render;
    _world.clearSystems();
    _world.destroyAllEntities();
    _engine.rendering.camera
      ..setPosition(Offset.zero)
      ..setZoom(1.0)
      ..smoothing = false;
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

    if (_demo == _Demo.cameraFollow && _playerMover != null) {
      _engine.rendering.camera.follow(_playerMover!.position, smooth: true);
      _engine.rendering.camera.update(dt);
    }

    _engine.parallax.update(dt, _engine.rendering.camera.position);

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Asset loading (once)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadAssets() async {
    final jsonAsset = await _engine.assets.loadJson('$_root/info.json');
    final parsed = jsonAsset.data as Map<String, dynamic>;
    final credits = parsed['credits'] as Map<String, dynamic>?;
    _artist = (credits?['artist'] as String?) ?? '';
    _source = (credits?['source'] as String?) ?? '';

    for (final def in _layerDefs) {
      final image = await Sprite.loadImageFromAsset('$_root/${def.file}');
      _layerImages.add(_LayerImages(image: image, def: def));
    }

    if (!mounted) return;
    setState(() => _loading = false);
    _buildDemo(_demo);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo construction
  // ─────────────────────────────────────────────────────────────────────────

  void _buildDemo(_Demo demo) {
    if (_loading) return;
    _demo = demo;
    _statusMessage = '';
    _playerMover = null;
    _tintPreset = 0;
    _layerVisible.fillRange(0, 4, true);

    _engine.rendering.camera
      ..setPosition(Offset.zero)
      ..setZoom(1.0)
      ..smoothing = false;

    _world.clearSystems();
    _world.destroyAllEntities();

    _engine.rendering.onRenderBackground = _engine.parallax.render;
    _engine.parallax.clear();
    _parallaxBg = _buildParallaxBg();
    _engine.parallax.addBackground(_parallaxBg!);

    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));

    switch (demo) {
      case _Demo.autoScroll:
        _setupAutoScroll();
      case _Demo.cameraFollow:
        _setupCameraFollow();
      case _Demo.depthLayers:
        _setupDepthLayers();
      case _Demo.tintEffect:
        _setupTintEffect();
    }

    if (mounted) setState(() {});
  }

  ParallaxBackground _buildParallaxBg() {
    return ParallaxBackground(
      layers: List.generate(_layerImages.length, (i) {
        final li = _layerImages[i];
        return ParallaxLayer(
          image: li.image,
          scrollFactorX: li.def.scrollFactor,
          scrollFactorY: 0.0,
          scale: 1.0,
          repeat: true,
        );
      }),
    );
  }

  // ── Auto-Scroll ──────────────────────────────────────────────────────────

  void _setupAutoScroll() {
    _applyScrollSpeed();
    _statusMessage = 'Back layer scrolls slowest — front layer fastest';
  }

  void _applyScrollSpeed() {
    if (_parallaxBg == null) return;
    for (int i = 0; i < _parallaxBg!.layers.length; i++) {
      _parallaxBg!.layers[i].velocityX =
          _scrollSpeed * _layerImages[i].def.scrollFactor;
    }
  }

  // ── Camera Follow ────────────────────────────────────────────────────────

  void _setupCameraFollow() {
    _engine.rendering.camera.smoothing = true;
    _engine.rendering.camera.smoothingFactor = 0.06;

    _world.addSystem(_BounceSystem()..priority = 80);

    final mover = _BounceComponent(
      position: Offset.zero,
      velocity: const Offset(160, 0),
      bounds: const Rect.fromLTWH(-600, -60, 1200, 120),
    );
    _playerMover = mover;

    _world.createEntityWithComponents([
      TransformComponent(),
      mover,
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 10,
          getBoundsCallback: () =>
              Rect.fromCenter(center: Offset.zero, width: 80, height: 80),
          onRender: (canvas, _) {
            canvas.drawCircle(
              Offset.zero,
              26,
              Paint()
                ..color = const Color(0xFF66BB6A).withValues(alpha: 0.30)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
            );
            canvas.drawCircle(
              Offset.zero,
              16,
              Paint()..color = const Color(0xFF66BB6A),
            );
            canvas.drawCircle(
              Offset.zero,
              16,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.55)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
            canvas.drawCircle(
              Offset.zero,
              5,
              Paint()..color = Colors.white.withValues(alpha: 0.85),
            );
          },
        ),
      ),
    ]);

    _statusMessage = 'Camera follows the character — parallax depth responds';
  }

  // ── Depth Layers ─────────────────────────────────────────────────────────

  void _setupDepthLayers() {
    _applyScrollSpeed();
    _statusMessage = 'Toggle layers to understand depth composition';
  }

  void _setLayerVisible(int index, bool visible) {
    _layerVisible[index] = visible;
    if (_parallaxBg != null) {
      _parallaxBg!.layers[index].opacity = visible ? 1.0 : 0.0;
    }
    setState(() {});
  }

  // ── Tint Effect ──────────────────────────────────────────────────────────

  void _setupTintEffect() {
    _applyScrollSpeed();
    _applyTintPreset(0);
    _statusMessage = 'Select a tint preset to grade layer colours';
  }

  void _applyTintPreset(int index) {
    _tintPreset = index;
    if (_parallaxBg == null) return;
    final tints = _tintPresets[index].$2;
    for (int i = 0; i < _parallaxBg!.layers.length; i++) {
      _parallaxBg!.layers[i].tint = i < tints.length ? tints[i] : null;
    }
    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats
  // ─────────────────────────────────────────────────────────────────────────

  String get _statsLine {
    if (_loading) return 'Loading assets…';
    final cam = _engine.rendering.camera;
    final pos = cam.position;
    return 'layers ${_layerDefs.length}'
        '  •  cam (${pos.dx.toStringAsFixed(0)}, ${pos.dy.toStringAsFixed(0)})'
        '  •  zoom ${cam.zoom.toStringAsFixed(2)}'
        '  •  scroll ${_scrollSpeed.toStringAsFixed(0)} px/s'
        '  •  artist: $_artist';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Column(
        children: [
          _buildHeader(),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
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

  // ── Header ───────────────────────────────────────────────────────────────

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
                'ParallaxSystem  ·  ParallaxBackground  ·  ParallaxLayer',
                style: TextStyle(color: Color(0xFF26C6DA), fontSize: 10),
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

  // ── Canvas ───────────────────────────────────────────────────────────────

  Widget _buildCanvas() {
    return GameCameraControls(
      camera: _engine.rendering.camera,
      enablePan: true,
      enablePinch: true,
      showZoomLevel: true,
      child: GameWidget(engine: _engine, showFPS: true, showDebug: false),
    );
  }

  // ── Demo selector ─────────────────────────────────────────────────────────

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

  // ── Control panel ─────────────────────────────────────────────────────────

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0xFF060D18),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: _buildDemoControls(),
    );
  }

  Widget _buildDemoControls() => switch (_demo) {
    _Demo.autoScroll => _buildAutoScrollControls(),
    _Demo.cameraFollow => _buildCameraFollowControls(),
    _Demo.depthLayers => _buildDepthLayersControls(),
    _Demo.tintEffect => _buildTintEffectControls(),
  };

  Widget _buildAutoScrollControls() {
    return Row(
      children: [
        const Text(
          'Speed:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF26C6DA),
              thumbColor: const Color(0xFF26C6DA),
              inactiveTrackColor: const Color(0xFF1E2E40),
              overlayColor: const Color(0xFF26C6DA).withValues(alpha: 0.15),
            ),
            child: Slider(
              value: _scrollSpeed,
              min: 0,
              max: 200,
              divisions: 20,
              label: '${_scrollSpeed.toStringAsFixed(0)} px/s',
              onChanged: (v) {
                setState(() => _scrollSpeed = v);
                _applyScrollSpeed();
              },
            ),
          ),
        ),
        _actionButton('Reset', const Color(0xFF26C6DA), () {
          setState(() => _scrollSpeed = 40.0);
          _applyScrollSpeed();
        }),
      ],
    );
  }

  Widget _buildCameraFollowControls() {
    return Row(
      children: [
        const Text(
          'Drag to pan  ·  Pinch/scroll to zoom  ·  Camera follows the character',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const Spacer(),
        _actionButton('Reset Camera', const Color(0xFF66BB6A), () {
          _engine.rendering.camera
            ..setPosition(Offset.zero)
            ..setZoom(1.0);
        }),
      ],
    );
  }

  Widget _buildDepthLayersControls() {
    return Row(
      children: [
        const Text(
          'Layers:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 10),
        for (int i = 0; i < _layerDefs.length; i++) ...[
          _layerToggleButton(i),
          const SizedBox(width: 6),
        ],
        const Spacer(),
        _actionButton('Show All', const Color(0xFFFFCA28), () {
          for (int i = 0; i < _layerDefs.length; i++) {
            _setLayerVisible(i, true);
          }
        }),
      ],
    );
  }

  Widget _layerToggleButton(int index) {
    final visible = _layerVisible[index];
    final name = _layerDefs[index].label;
    const color = Color(0xFFFFCA28);
    return GestureDetector(
      onTap: () => _setLayerVisible(index, !visible),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: visible
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF111C2A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: visible
                ? color.withValues(alpha: 0.55)
                : const Color(0xFF1A2535),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              visible ? Icons.visibility : Icons.visibility_off,
              size: 12,
              color: visible ? color : Colors.white24,
            ),
            const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                color: visible ? Colors.white : Colors.white30,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTintEffectControls() {
    return Row(
      children: [
        const Text(
          'Preset:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 10),
        for (int i = 0; i < _tintPresets.length; i++) ...[
          _actionButton(
            _tintPresets[i].$1,
            const Color(0xFFAB47BC),
            () => _applyTintPreset(i),
            selected: _tintPreset == i,
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _actionButton(
    String label,
    Color color,
    VoidCallback? onTap, {
    bool selected = false,
  }) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.25)
              : active
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF111C2A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active
                ? color.withValues(alpha: selected ? 0.9 : 0.55)
                : const Color(0xFF1A2535),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white30,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Code card ─────────────────────────────────────────────────────────────

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
                  'just_game_engine · ParallaxSystem API',
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

// ─────────────────────────────────────────────────────────────────────────────
// Private data helpers
// ─────────────────────────────────────────────────────────────────────────────

class _LayerDef {
  const _LayerDef(this.file, this.label, this.scrollFactor);
  final String file;
  final String label;
  final double scrollFactor;
}

class _LayerImages {
  const _LayerImages({required this.image, required this.def});
  final ui.Image image;
  final _LayerDef def;
}

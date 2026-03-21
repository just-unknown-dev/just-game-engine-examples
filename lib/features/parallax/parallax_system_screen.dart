import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

class ParallaxSystemScreen extends StatefulWidget {
  const ParallaxSystemScreen({super.key});

  @override
  State<ParallaxSystemScreen> createState() => _ParallaxSystemScreenState();
}

class _ParallaxSystemScreenState extends State<ParallaxSystemScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  final GlobalKey _gameWidgetKey = GlobalKey();

  Duration _lastTickTime = Duration.zero;

  bool _loading = true;
  double _autoScrollSpeed = 30.0;
  double _cameraX = 0.0;

  String _artist = '';
  String _source = '';

  ParallaxBackground? _parallaxBg;
  final List<_LayerMeta> _layerMetas = [];

  static const String _root = 'assets/sprites/environment/parallax';

  // Layer definitions: ordered back → front with increasing scroll factor
  static const List<_LayerDef> _layerDefs = [
    _LayerDef('parallax-forest-back-trees.png', 'Back Trees', 0.1),
    _LayerDef('parallax-forest-middle-trees.png', 'Middle Trees', 0.35),
    _LayerDef('parallax-forest-lights.png', 'Lights', 0.55),
    _LayerDef('parallax-forest-front-trees.png', 'Front Trees', 0.8),
  ];

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;

    _ticker = createTicker(_onTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeShowcase();
    });
  }

  @override
  void dispose() {
    _engine.parallax.clear();
    _ticker.dispose();
    _world.destroyAllEntities();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }

    final dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    // Advance parallax auto-scroll and camera-driven offsets
    _engine.parallax.update(dt, _engine.rendering.camera.position);
    _engine.world.update(dt);

    if (mounted) setState(() {});
  }

  // ── Initialization ────────────────────────────────────────────────────

  Future<void> _initializeShowcase() async {
    await _loadParallaxAssets();
    _buildShowcase();
  }

  Future<void> _loadParallaxAssets() async {
    setState(() => _loading = true);

    // Load credits
    final jsonAsset = await _engine.assets.loadJson('$_root/info.json');
    final parsed = jsonAsset.data as Map<String, dynamic>;
    final credits = parsed['credits'] as Map<String, dynamic>?;
    _artist = (credits?['artist'] as String?) ?? '';
    _source = (credits?['source'] as String?) ?? '';

    // Load layer images
    final layers = <ParallaxLayer>[];
    _layerMetas.clear();

    for (final def in _layerDefs) {
      final image = await Sprite.loadImageFromAsset('$_root/${def.file}');

      layers.add(
        ParallaxLayer(
          image: image,
          scrollFactorX: def.scrollFactor,
          scrollFactorY: 0.0, // horizontal-only parallax
          velocityX: _autoScrollSpeed * def.scrollFactor,
          scale: 1.0,
          repeat: true,
        ),
      );

      _layerMetas.add(
        _LayerMeta(
          name: def.label,
          file: def.file,
          scrollFactor: def.scrollFactor,
          width: image.width,
          height: image.height,
        ),
      );
    }

    // Register with the engine's parallax subsystem
    _engine.parallax.clear();
    _parallaxBg = ParallaxBackground(layers: layers);
    _engine.parallax.addBackground(_parallaxBg!);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _buildShowcase() {
    if (_loading) return;

    final camera = _engine.rendering.camera;
    camera.position = Offset.zero;
    camera.rotation = 0;
    camera.zoom = 1;

    // Override the default background callback so parallax respects camera zoom.
    _engine.rendering.onRenderBackground = (Canvas canvas, Size size) {
      final zoom = camera.zoom;
      if (zoom != 1.0) {
        canvas.save();
        final cx = size.width / 2;
        final cy = size.height / 2;
        canvas.translate(cx, cy);
        canvas.scale(zoom);
        canvas.translate(-cx, -cy);
        _engine.parallax.render(canvas, size);
        canvas.restore();
      } else {
        _engine.parallax.render(canvas, size);
      }
    };

    _clearWorld();
    _world.addSystem(_CameraAwareRenderSystem(camera));
    _createLabels();

    setState(() {});
  }

  void _updateAutoScroll() {
    if (_parallaxBg == null) return;
    for (int i = 0; i < _parallaxBg!.layers.length; i++) {
      final layer = _parallaxBg!.layers[i];
      layer.velocityX = _autoScrollSpeed * layer.scrollFactorX;
    }
  }

  void _updateCameraX(double value) {
    _cameraX = value;
    _engine.rendering.camera.position = Offset(_cameraX, 0);
  }

  void _clearWorld() {
    final existingSystems = List<System>.from(_world.systems);
    for (final system in existingSystems) {
      _world.removeSystem(system);
    }
    _world.destroyAllEntities();
  }

  void _createLabels() {
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -200)),
      RenderableComponent(
        renderable: TextRenderable(
          text: 'Parallax Background Showcase',
          textStyle: const TextStyle(
            color: Color(0xFFF8F4EC),
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
          layer: 30,
        ),
      ),
    ], name: 'title');

    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -170)),
      RenderableComponent(
        renderable: TextRenderable(
          text:
              'Layers: ${_layerMetas.length}   •   '
              'Auto-scroll: ${_autoScrollSpeed.toStringAsFixed(0)} px/s',
          textStyle: const TextStyle(
            color: Color(0xFFB9D8A7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          layer: 30,
        ),
      ),
    ], name: 'meta');

    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -140)),
      RenderableComponent(
        renderable: TextRenderable(
          text: 'Credit: $_artist   •   Source: $_source',
          textStyle: const TextStyle(
            color: Color(0xFF9DD9D2),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          layer: 30,
        ),
      ),
    ], name: 'credit');

    // Layer info labels
    for (int i = 0; i < _layerMetas.length; i++) {
      final meta = _layerMetas[i];
      _world.createEntityWithComponents([
        TransformComponent(position: Offset(0, 140.0 + i * 24.0)),
        RenderableComponent(
          renderable: TextRenderable(
            text:
                '${meta.name}  •  ${meta.width}x${meta.height}  •  '
                'scroll: ${meta.scrollFactor.toStringAsFixed(2)}',
            textStyle: const TextStyle(
              color: Color(0xFFD4EAC8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            layer: 30,
          ),
        ),
      ], name: 'layer-label-$i');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xFF0F1A12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parallax System Showcase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _loading
                    ? 'Loading parallax layers...'
                    : 'Layers: ${_layerMetas.length}   •   '
                          'Camera X: ${_cameraX.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Auto-scroll',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  Expanded(
                    child: Slider(
                      value: _autoScrollSpeed,
                      min: 0,
                      max: 200,
                      divisions: 20,
                      label: '${_autoScrollSpeed.toStringAsFixed(0)} px/s',
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() => _autoScrollSpeed = value);
                              _updateAutoScroll();
                            },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Camera X',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  Expanded(
                    child: Slider(
                      value: _cameraX,
                      min: -800,
                      max: 800,
                      divisions: 32,
                      label: _cameraX.toStringAsFixed(0),
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() => _updateCameraX(value));
                            },
                    ),
                  ),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : () {
                            _updateCameraX(0);
                            _buildShowcase();
                          },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : CameraZoomControls(
                  camera: _engine.rendering.camera,
                  child: GameWidget(
                    key: _gameWidgetKey,
                    engine: _engine,
                    showFPS: true,
                    showDebug: true,
                  ),
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private helpers
// ═══════════════════════════════════════════════════════════════════════════

class _LayerDef {
  const _LayerDef(this.file, this.label, this.scrollFactor);
  final String file;
  final String label;
  final double scrollFactor;
}

class _LayerMeta {
  const _LayerMeta({
    required this.name,
    required this.file,
    required this.scrollFactor,
    required this.width,
    required this.height,
  });
  final String name;
  final String file;
  final double scrollFactor;
  final int width;
  final int height;
}

class _CameraAwareRenderSystem extends System {
  _CameraAwareRenderSystem(this.camera);
  final Camera camera;

  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    RenderableComponent,
  ];

  @override
  void render(Canvas canvas, Size size) {
    camera.viewportSize = size;
    canvas.save();
    camera.applyTransform(canvas, size);

    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final renderComp = entity.getComponent<RenderableComponent>()!;

      if (renderComp.syncTransform) {
        renderComp.renderable.position = transform.position;
        renderComp.renderable.rotation = transform.rotation;
        renderComp.renderable.scale = transform.scale;
      }

      if (renderComp.renderable.visible) {
        renderComp.renderable.render(canvas, size);
      }
    });

    canvas.restore();
  }
}

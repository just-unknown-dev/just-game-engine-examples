import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

class SpriteSystemScreen extends StatefulWidget {
  const SpriteSystemScreen({super.key});

  @override
  State<SpriteSystemScreen> createState() => _SpriteSystemScreenState();
}

class _SpriteSystemScreenState extends State<SpriteSystemScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  final GlobalKey _gameWidgetKey = GlobalKey();

  Duration _lastTickTime = Duration.zero;
  Size _viewportSize = Size.zero;

  bool _loading = true;
  double _displayScale = 0.45;

  String _artist = '';
  String _source = '';
  List<_HouseSpriteMeta> _houseSprites = const [];
  final Map<String, ui.Image> _loadedImages = {};

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
    _ticker.dispose();
    _world.destroyAllEntities();
    super.dispose();
  }

  Future<void> _initializeShowcase() async {
    await _loadHouseAssetsFromInfo();
    _rebuildShowcase();
  }

  Future<void> _loadHouseAssetsFromInfo() async {
    setState(() {
      _loading = true;
    });

    final jsonAsset = await _engine.assets.loadJson(
      'assets/sprites/environment/house/info.json',
    );
    final parsed = jsonAsset.data as Map<String, dynamic>;

    final credits = parsed['credits'] as Map<String, dynamic>?;
    _artist = (credits?['artist'] as String?) ?? '';
    _source = (credits?['source'] as String?) ?? '';

    final spritesMap = parsed['sprites'] as Map<String, dynamic>? ?? const {};
    final orderedNames = spritesMap.keys.toList()..sort();

    final metas = <_HouseSpriteMeta>[];
    for (final name in orderedNames) {
      final info = spritesMap[name] as Map<String, dynamic>?;
      if (info == null) continue;

      final imagePath = info['imagePath'] as String?;
      final width = info['width'] as int?;
      final height = info['height'] as int?;
      if (imagePath == null || width == null || height == null) continue;

      final assetPath = 'assets/sprites/environment/house/$imagePath';
      final image = await Sprite.loadImageFromAsset(assetPath);
      _loadedImages[name] = image;

      metas.add(
        _HouseSpriteMeta(
          name: name,
          assetPath: assetPath,
          width: width,
          height: height,
        ),
      );
    }

    _houseSprites = metas;

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }

    final dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    _engine.world.update(dt);

    if (mounted) {
      setState(() {});
    }
  }

  Size _readViewportSize() {
    final renderObject = _gameWidgetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return MediaQuery.sizeOf(context);
  }

  void _clearWorld() {
    final existingSystems = List<System>.from(_world.systems);
    for (final system in existingSystems) {
      _world.removeSystem(system);
    }
    _world.destroyAllEntities();
  }

  void _rebuildShowcase() {
    if (_loading || _houseSprites.isEmpty) return;

    _viewportSize = _readViewportSize();
    if (_viewportSize == Size.zero) return;

    _engine.rendering.camera.viewportSize = _viewportSize;
    _engine.rendering.camera.position = Offset.zero;
    _engine.rendering.camera.rotation = 0;
    _engine.rendering.camera.zoom = 1;

    _clearWorld();

    _world.addSystem(_CameraAwareRenderSystem(_engine.rendering.camera));

    _createBackdrop();
    _createHouseSprites();
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
            final gridPaint = Paint()
              ..color = const Color(0xFF1E2A1F).withValues(alpha: 0.30)
              ..strokeWidth = 1;

            for (double x = -1000; x <= 1000; x += 80) {
              canvas.drawLine(Offset(x, -700), Offset(x, 700), gridPaint);
            }
            for (double y = -700; y <= 700; y += 80) {
              canvas.drawLine(Offset(-1000, y), Offset(1000, y), gridPaint);
            }

            final floorPaint = Paint()
              ..color = const Color(0xFF2B3D2E).withValues(alpha: 0.40);
            canvas.drawRect(
              Rect.fromCenter(
                center: const Offset(0, 130),
                width: 1400,
                height: 220,
              ),
              floorPaint,
            );
          },
        ),
      ),
    ], name: 'backdrop');
  }

  void _createHouseSprites() {
    if (_houseSprites.length < 3) return;

    final spacing = 420.0;
    final startX = -spacing;

    for (int i = 0; i < _houseSprites.length; i++) {
      final meta = _houseSprites[i];
      final image = _loadedImages[meta.name];
      if (image == null) continue;

      final renderWidth = meta.width * _displayScale;
      final renderHeight = meta.height * _displayScale;

      _world.createEntityWithComponents([
        TransformComponent(position: Offset(startX + i * spacing, 0)),
        RenderableComponent(
          renderable: Sprite(
            image: image,
            sourceRect: Rect.fromLTWH(
              0,
              0,
              meta.width.toDouble(),
              meta.height.toDouble(),
            ),
            renderSize: Size(renderWidth, renderHeight),
            layer: 8,
          ),
        ),
      ], name: meta.name);

      _world.createEntityWithComponents([
        TransformComponent(position: Offset(startX + i * spacing, 260)),
        RenderableComponent(
          renderable: TextRenderable(
            text: '${meta.name}  •  ${meta.width}x${meta.height}',
            textStyle: const TextStyle(
              color: Color(0xFFF0F5E9),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            layer: 20,
          ),
        ),
      ], name: '${meta.name}-label');
    }
  }

  void _createSceneLabels() {
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -220)),
      RenderableComponent(
        renderable: TextRenderable(
          text:
              'Sprites: ${_houseSprites.length}   •   Scale: ${_displayScale.toStringAsFixed(2)}x',
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
      TransformComponent(position: const Offset(0, -190)),
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xFF142019),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sprite System Showcase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _loading
                    ? 'Loading house sprites from info.json...'
                    : 'Loaded houses: ${_houseSprites.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Scale', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _displayScale,
                      min: 0.30,
                      max: 1.20,
                      divisions: 18,
                      label: '${_displayScale.toStringAsFixed(2)}x',
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() {
                                _displayScale = value;
                              });
                            },
                      onChangeEnd: _loading ? null : (_) => _rebuildShowcase(),
                    ),
                  ),
                  FilledButton(
                    onPressed: _loading ? null : _rebuildShowcase,
                    child: const Text('Respawn'),
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

class _HouseSpriteMeta {
  const _HouseSpriteMeta({
    required this.name,
    required this.assetPath,
    required this.width,
    required this.height,
  });

  final String name;
  final String assetPath;
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

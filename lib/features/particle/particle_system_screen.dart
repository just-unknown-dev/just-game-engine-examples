import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

enum _EffectType {
  fire,
  smoke,
  sparkle,
  rain,
  snow;

  String get label => switch (this) {
    fire => 'Fire',
    smoke => 'Smoke',
    sparkle => 'Sparkle',
    rain => 'Rain',
    snow => 'Snow',
  };

  IconData get icon => switch (this) {
    fire => Icons.local_fire_department,
    smoke => Icons.cloud,
    sparkle => Icons.auto_awesome,
    rain => Icons.water_drop,
    snow => Icons.ac_unit,
  };

  Color get chipColor => switch (this) {
    fire => const Color(0xFFFF6B35),
    smoke => const Color(0xFF9E9E9E),
    sparkle => const Color(0xFFFFD700),
    rain => const Color(0xFF64B5F6),
    snow => const Color(0xFFE0F7FA),
  };
}

class ParticleSystemScreen extends StatefulWidget {
  const ParticleSystemScreen({super.key});

  @override
  State<ParticleSystemScreen> createState() => _ParticleSystemScreenState();
}

class _ParticleSystemScreenState extends State<ParticleSystemScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  final GlobalKey _gameWidgetKey = GlobalKey();
  final math.Random _random = math.Random();

  Duration _lastTickTime = Duration.zero;
  Size _viewportSize = Size.zero;

  Set<_EffectType> _activeEffects = _EffectType.values.toSet();
  double _emissionRate = 1.0;

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
    _engine.world.update(dt);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world.destroyAllEntities();
    super.dispose();
  }

  Size _readViewportSize() {
    final renderObject = _gameWidgetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return MediaQuery.sizeOf(context);
  }

  void _clearWorld() {
    final systems = List<System>.from(_world.systems);
    for (final s in systems) {
      _world.removeSystem(s);
    }
    _world.destroyAllEntities();
  }

  void _rebuildShowcase() {
    _viewportSize = _readViewportSize();
    if (_viewportSize == Size.zero) return;

    _engine.rendering.camera.viewportSize = _viewportSize;
    _engine.rendering.camera.position = Offset.zero;
    _engine.rendering.camera.rotation = 0;
    _engine.rendering.camera.zoom = 1;

    _clearWorld();

    _world.addSystem(_ParticleEmitterSystem()..priority = 90);
    _world.addSystem(_AutoDestroySystem()..priority = 80);
    _world.addSystem(_CameraAwareRenderSystem(_engine.rendering.camera));

    _createBackdrop();
    _createParticleEffects();
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
              ..color = const Color(0xFF1A1033).withValues(alpha: 0.30)
              ..strokeWidth = 1;
            for (double x = -1000; x <= 1000; x += 80) {
              canvas.drawLine(Offset(x, -700), Offset(x, 700), gridPaint);
            }
            for (double y = -700; y <= 700; y += 80) {
              canvas.drawLine(Offset(-1000, y), Offset(1000, y), gridPaint);
            }
          },
        ),
      ),
    ], name: 'backdrop');
  }

  // World-space emitter positions.
  // Fire/smoke/sparkle emit upward from y=80; rain/snow emit downward from y=-220.
  static const _effectPositions = <_EffectType, Offset>{
    _EffectType.fire: Offset(-320, 80),
    _EffectType.smoke: Offset(-160, 80),
    _EffectType.sparkle: Offset(0, 0),
    _EffectType.rain: Offset(160, -220),
    _EffectType.snow: Offset(320, -220),
  };

  ParticleEmitter _buildEmitter(_EffectType type) {
    final pos = _effectPositions[type]!;
    final emitter = switch (type) {
      _EffectType.fire => ParticleEffects.fire(position: pos),
      _EffectType.smoke => ParticleEffects.smoke(position: pos),
      _EffectType.sparkle => ParticleEffects.sparkle(position: pos),
      _EffectType.rain => ParticleEffects.rain(position: pos),
      _EffectType.snow => ParticleEffects.snow(position: pos),
    };
    emitter.emissionRate *= _emissionRate;
    return emitter;
  }

  void _createParticleEffects() {
    for (final type in _activeEffects) {
      final emitter = _buildEmitter(type);
      _world.createEntityWithComponents([
        TransformComponent(position: _effectPositions[type]!),
        RenderableComponent(renderable: emitter),
        _ParticleEmitterComponent(emitter: emitter),
      ], name: type.name);
    }
  }

  void _createSceneLabels() {
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -278)),
      RenderableComponent(
        renderable: TextRenderable(
          text: 'Tap in the scene to spawn explosions',
          textStyle: const TextStyle(
            color: Color(0xFFCEB8FF),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          layer: 30,
        ),
      ),
    ], name: 'hint');

    for (final type in _activeEffects) {
      final pos = _effectPositions[type]!;
      final emitsDown = type == _EffectType.rain || type == _EffectType.snow;
      final labelY = emitsDown ? pos.dy - 30 : pos.dy + 120;

      _world.createEntityWithComponents([
        TransformComponent(position: Offset(pos.dx, labelY)),
        RenderableComponent(
          renderable: TextRenderable(
            text: type.label,
            textStyle: const TextStyle(
              color: Color(0xFFEADDFF),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            layer: 30,
          ),
        ),
      ], name: '${type.name}-label');
    }
  }

  int get _totalParticleCount {
    int count = 0;
    for (final entity in _world.query([_ParticleEmitterComponent])) {
      count += entity
          .getComponent<_ParticleEmitterComponent>()!
          .emitter
          .particleCount;
    }
    return count;
  }

  void _spawnExplosion(Offset worldPos) {
    const explosionColors = [
      Colors.orange,
      Colors.red,
      Colors.yellow,
      Colors.deepOrange,
      Colors.purple,
      Colors.cyanAccent,
    ];
    final color = explosionColors[_random.nextInt(explosionColors.length)];
    final emitter = ParticleEffects.explosion(
      position: worldPos,
      color: color,
      particleCount: 60 + _random.nextInt(60),
    );
    _world.createEntityWithComponents([
      TransformComponent(position: worldPos),
      RenderableComponent(renderable: emitter),
      _ParticleEmitterComponent(emitter: emitter),
      _AutoDestroyComponent(lifetime: 2.0),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xFF110D22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Particle System Showcase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Active particles: $_totalParticleCount   |   Effects: ${_activeEffects.length} / ${_EffectType.values.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _EffectType.values.map((type) {
                  final active = _activeEffects.contains(type);
                  return FilterChip(
                    avatar: Icon(type.icon, size: 16),
                    label: Text(type.label),
                    selected: active,
                    selectedColor: type.chipColor.withValues(alpha: 0.25),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _activeEffects.add(type);
                        } else {
                          _activeEffects.remove(type);
                        }
                      });
                      _rebuildShowcase();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'Emission Rate',
                    style: TextStyle(color: Colors.white),
                  ),
                  Expanded(
                    child: Slider(
                      value: _emissionRate,
                      min: 0.2,
                      max: 3.0,
                      divisions: 28,
                      label: '${_emissionRate.toStringAsFixed(1)}x',
                      onChanged: (value) {
                        setState(() {
                          _emissionRate = value;
                        });
                      },
                      onChangeEnd: (_) => _rebuildShowcase(),
                    ),
                  ),
                  FilledButton(
                    onPressed: _rebuildShowcase,
                    child: const Text('Respawn'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: CameraZoomControls(
            camera: _engine.rendering.camera,
            child: Listener(
              onPointerDown: (event) {
                final worldPos = _engine.rendering.camera.screenToWorld(
                  event.localPosition,
                );
                _spawnExplosion(worldPos);
              },
              child: GameWidget(
                key: _gameWidgetKey,
                engine: _engine,
                showFPS: true,
                showDebug: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ParticleEmitterComponent extends Component {
  _ParticleEmitterComponent({required this.emitter});
  final ParticleEmitter emitter;
}

class _AutoDestroyComponent extends Component {
  _AutoDestroyComponent({required this.lifetime});
  final double lifetime;
  double age = 0;
}

class _ParticleEmitterSystem extends System {
  @override
  List<Type> get requiredComponents => [_ParticleEmitterComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final comp = entity.getComponent<_ParticleEmitterComponent>()!;
      comp.emitter.update(dt);
    });
  }
}

class _AutoDestroySystem extends System {
  @override
  List<Type> get requiredComponents => [_AutoDestroyComponent];

  @override
  void update(double dt) {
    final toDestroy = <Entity>[];
    forEach((entity) {
      final comp = entity.getComponent<_AutoDestroyComponent>()!;
      comp.age += dt;
      if (comp.age >= comp.lifetime) {
        toDestroy.add(entity);
      }
    });
    for (final entity in toDestroy) {
      world.destroyEntity(entity);
    }
  }
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

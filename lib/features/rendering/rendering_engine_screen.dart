import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

class RenderingEngineScreen extends StatefulWidget {
  const RenderingEngineScreen({super.key});

  @override
  State<RenderingEngineScreen> createState() => _RenderingEngineScreenState();
}

class _RenderingEngineScreenState extends State<RenderingEngineScreen> {
  late final Engine _engine;
  late final World _world;
  final GlobalKey _gameWidgetKey = GlobalKey();

  Size _gameWidgetSize = Size.zero;
  Offset _sceneCenter = Offset.zero;

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRenderingDemo();
    });
  }

  @override
  void dispose() {
    _engine.stop();
    super.dispose();
  }

  void _setupRenderingDemo() {
    _gameWidgetSize = _getGameWidgetSize();
    if (_gameWidgetSize != Size.zero) {
      _engine.rendering.camera.viewportSize = _gameWidgetSize;
    }

    _world.destroyAllEntities();
    _engine.rendering.camera.position = Offset.zero;
    _engine.rendering.camera.rotation = 0;
    _engine.rendering.camera.zoom = 1;
    _sceneCenter = Offset.zero;

    _world.addSystem(_SpinSystem()..priority = 80);
    _world.addSystem(_FloatSystem()..priority = 75);
    _world.addSystem(_PulseScaleSystem()..priority = 70);
    _world.addSystem(_OrbitChildSystem()..priority = 65);
    _world.addSystem(HierarchySystem()..priority = 60);
    _world.addSystem(_EmitterSystem()..priority = 55);
    _world.addSystem(_RaySweepSystem()..priority = 50);
    _world.addSystem(_CameraAwareRenderSystem(_engine.rendering.camera));

    _createBackdrop();
    _createTitle();
    _createLayeredRectangles();
    _createCircleBeacon();
    _createLineFan();
    _createCustomStar();
    _createHierarchyShowcase();
    _createParticles();
    _createRays();
  }

  Size _getGameWidgetSize() {
    final renderObject = _gameWidgetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return Size.zero;
  }

  Offset _scenePoint(Offset offset) => _sceneCenter + offset;

  void _createBackdrop() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          position: _sceneCenter,
          layer: -50,
          onRender: (canvas, size) {
            final gridPaint = Paint()
              ..color = const Color(0xFF173042).withValues(alpha: 0.45)
              ..strokeWidth = 1;

            for (double x = -900; x <= 900; x += 60) {
              canvas.drawLine(Offset(x, -700), Offset(x, 700), gridPaint);
            }
            for (double y = -700; y <= 700; y += 60) {
              canvas.drawLine(Offset(-900, y), Offset(900, y), gridPaint);
            }

            final ringPaint = Paint()
              ..color = const Color(0xFF5FD1FF).withValues(alpha: 0.12)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2;

            for (double radius = 120; radius <= 480; radius += 120) {
              canvas.drawCircle(Offset.zero, radius, ringPaint);
            }
          },
        ),
      ),
    ], name: 'backdrop');
  }

  void _createTitle() {
    _spawnText(
      text:
          'Rectangles, circles, lines, text, custom draw, particles, rays, hierarchy',
      position: _scenePoint(const Offset(0, -232)),
      layer: 40,
      textStyle: const TextStyle(color: Color(0xFFADC4D4), fontSize: 13),
    );
  }

  void _createLayeredRectangles() {
    final anchor = _scenePoint(const Offset(-250, -40));
    final colors = <Color>[
      const Color(0xFFE4572E),
      const Color(0xFF17BEBB),
      const Color(0xFFF4D35E),
    ];

    for (int index = 0; index < colors.length; index++) {
      _world.createEntityWithComponents([
        TransformComponent(
          position: Offset(anchor.dx + index * 36, anchor.dy + index * 18),
          rotation: -0.18 + (index * 0.12),
          scale: 1.0 + index * 0.04,
        ),
        RenderableComponent(
          renderable: RectangleRenderable(
            size: const Size(170, 110),
            fillColor: colors[index].withValues(alpha: 0.72),
            strokeColor: Colors.white.withValues(alpha: 0.55),
            strokeWidth: 3,
            layer: 4,
            zOrder: index,
          ),
        ),
        _SpinComponent(speed: 0.08 + index * 0.04),
        _PulseScaleComponent(
          minScale: 0.94,
          maxScale: 1.08,
          speed: 1.4 + index * 0.3,
          phase: index * 0.8,
        ),
      ], name: 'layered-rect-$index');
    }

    _spawnText(
      text: 'RectangleRenderable\nlayer + zOrder',
      position: _scenePoint(const Offset(-250, 86)),
      layer: 30,
      textStyle: const TextStyle(
        color: Color(0xFFF8F4EC),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _createCircleBeacon() {
    _world.createEntityWithComponents([
      TransformComponent(
        position: _scenePoint(const Offset(250, -40)),
        scale: 1.0,
      ),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: 52,
          fillColor: const Color(0xFF2E294E).withValues(alpha: 0.25),
          strokeColor: const Color(0xFF7FE3FF),
          strokeWidth: 5,
          layer: 5,
        ),
      ),
      _PulseScaleComponent(minScale: 0.88, maxScale: 1.18, speed: 2.3),
    ], name: 'circle-beacon');

    _world.createEntityWithComponents([
      TransformComponent(
        position: _scenePoint(const Offset(250, -40)),
        scale: 1.0,
      ),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: 18,
          fillColor: const Color(0xFF7FE3FF),
          strokeColor: Colors.white.withValues(alpha: 0.8),
          strokeWidth: 3,
          layer: 6,
        ),
      ),
      _FloatComponent(
        origin: _scenePoint(const Offset(250, -40)),
        amplitudeX: 14,
        amplitudeY: 10,
        speed: 1.6,
      ),
    ], name: 'circle-core');

    _spawnText(
      text: 'CircleRenderable\npulse + float',
      position: _scenePoint(const Offset(250, 86)),
      layer: 30,
      textStyle: const TextStyle(
        color: Color(0xFFF8F4EC),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _createLineFan() {
    final origin = _scenePoint(const Offset(-320, 200));
    for (int index = 0; index < 7; index++) {
      _world.createEntityWithComponents([
        TransformComponent(position: origin, rotation: -0.9 + (index * 0.3)),
        RenderableComponent(
          renderable: LineRenderable(
            endPoint: Offset(180 - (index * 12), 0),
            color: Color.lerp(
              const Color(0xFFF4D35E),
              const Color(0xFFE4572E),
              index / 6,
            )!,
            width: 4 - (index * 0.3),
            layer: 3,
          ),
        ),
        _SpinComponent(speed: 0.16 + index * 0.015),
      ], name: 'line-fan-$index');
    }

    _spawnText(
      text: 'LineRenderable\nrotating fan',
      position: _scenePoint(const Offset(-320, 290)),
      layer: 30,
      textStyle: const TextStyle(
        color: Color(0xFFF8F4EC),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _createCustomStar() {
    _world.createEntityWithComponents([
      TransformComponent(
        position: _scenePoint(const Offset(0, 180)),
        scale: 1.0,
      ),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 7,
          onRender: (canvas, size) {
            final glowPaint = Paint()
              ..color = const Color(0xFF7FE3FF).withValues(alpha: 0.18)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
            canvas.drawCircle(Offset.zero, 64, glowPaint);

            final path = Path();
            const points = 10;
            for (int i = 0; i < points; i++) {
              final radius = i.isEven ? 64.0 : 28.0;
              final angle = (-math.pi / 2) + (i * math.pi / 5);
              final point = Offset(
                math.cos(angle) * radius,
                math.sin(angle) * radius,
              );
              if (i == 0) {
                path.moveTo(point.dx, point.dy);
              } else {
                path.lineTo(point.dx, point.dy);
              }
            }
            path.close();

            final fillPaint = Paint()
              ..shader = const LinearGradient(
                colors: [Color(0xFF17BEBB), Color(0xFF7FE3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(const Rect.fromLTWH(-64, -64, 128, 128));
            canvas.drawPath(path, fillPaint);

            final strokePaint = Paint()
              ..color = Colors.white.withValues(alpha: 0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3;
            canvas.drawPath(path, strokePaint);
          },
        ),
      ),
      _SpinComponent(speed: -0.22),
      _PulseScaleComponent(minScale: 0.9, maxScale: 1.1, speed: 1.8),
    ], name: 'custom-star');

    _spawnText(
      text: 'CustomRenderable\nshader + path',
      position: _scenePoint(const Offset(0, 286)),
      layer: 30,
      textStyle: const TextStyle(
        color: Color(0xFFF8F4EC),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _createHierarchyShowcase() {
    final parent = _world.createEntityWithComponents([
      TransformComponent(position: _scenePoint(const Offset(320, 170))),
      ChildrenComponent(),
      RenderableComponent(
        renderable: RectangleRenderable(
          size: const Size(72, 72),
          fillColor: const Color(0xFF2E294E).withValues(alpha: 0.82),
          strokeColor: const Color(0xFFF8F4EC).withValues(alpha: 0.65),
          strokeWidth: 3,
          layer: 6,
        ),
      ),
      _SpinComponent(speed: 0.24),
    ], name: 'hierarchy-parent');

    final children = parent.getComponent<ChildrenComponent>()!;
    for (int index = 0; index < 3; index++) {
      final child = _world.createEntityWithComponents([
        TransformComponent(),
        ParentComponent(parentId: parent.id),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: 14 + index * 4,
            fillColor: [
              const Color(0xFFE4572E),
              const Color(0xFFF4D35E),
              const Color(0xFF17BEBB),
            ][index],
            strokeColor: Colors.white.withValues(alpha: 0.7),
            strokeWidth: 2,
            layer: 7,
            zOrder: index,
          ),
        ),
        _OrbitChildComponent(
          radius: 70 + index * 24,
          speed: 0.9 + index * 0.35,
          phase: index * (math.pi / 1.5),
        ),
      ], name: 'orbit-child-$index');
      children.addChild(child.id);
    }

    _spawnText(
      text: 'Hierarchy + RenderableComponent',
      position: _scenePoint(const Offset(320, 270)),
      layer: 30,
      textStyle: const TextStyle(
        color: Color(0xFFF8F4EC),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _createParticles() {
    _world.createEntityWithComponents([
      TransformComponent(position: _scenePoint(const Offset(-70, 20))),
      RenderableComponent(
        syncTransform: false,
        renderable: ParticleEmitter(
          position: _scenePoint(const Offset(-70, 20)),
          maxParticles: 180,
          emissionRate: 24,
          particleLifetime: 1.5,
          startSize: 10,
          endSize: 1,
          startColor: const Color(0xFFF4D35E),
          endColor: const Color(0x00F4D35E),
          speed: 30,
          speedVariation: 18,
          gravity: const Offset(0, -8),
          emissionAngle: -math.pi / 2,
          emissionSpread: math.pi / 1.6,
          layer: 2,
          zOrder: 20,
        ),
      ),
      _EmitterMotionComponent(
        position: _scenePoint(const Offset(-70, 20)),
        minRate: 12,
        maxRate: 36,
        speed: 1.6,
      ),
    ], name: 'particle-emitter');

    _spawnText(
      text: 'ParticleEmitter',
      position: _scenePoint(const Offset(-70, 102)),
      layer: 30,
      textStyle: const TextStyle(
        color: Color(0xFFF8F4EC),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _createRays() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: RayRenderable(
          start: _scenePoint(const Offset(-40, -160)),
          end: _scenePoint(const Offset(120, -60)),
          color: const Color(0xFF7FE3FF),
          width: 4,
          glowWidthMultiplier: 6,
          glowBlurSigma: 8,
          lifetime: 0,
          layer: 8,
          zOrder: 50,
        ),
      ),
      _RaySweepComponent(
        anchor: _scenePoint(const Offset(40, -110)),
        length: 200,
        radius: 28,
        speed: 1.4,
      ),
    ], name: 'ray-sweep');

    _spawnText(
      text: 'RayRenderable',
      position: _scenePoint(const Offset(56, -192)),
      layer: 30,
      textStyle: const TextStyle(
        color: Color(0xFFF8F4EC),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _spawnText({
    required String text,
    required Offset position,
    required int layer,
    required TextStyle textStyle,
  }) {
    _world.createEntityWithComponents([
      TransformComponent(position: position),
      RenderableComponent(
        renderable: TextRenderable(
          text: text,
          textStyle: textStyle,
          layer: layer,
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: const Color(0xFF101925),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rendering Engine Showcase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Entities: ${_world.entities.length}   |   '
                'Systems: ${_world.systems.length}   |   '
                'Renderables: Rectangle, Circle, Line, Text, Custom, Particles, Rays',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _setupRenderingDemo,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Scene'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: CameraZoomControls(
            camera: _engine.rendering.camera,
            child: GameWidget(
              key: _gameWidgetKey,
              engine: _engine,
              showDebug: true,
              showFPS: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _SpinComponent extends Component {
  final double speed;

  _SpinComponent({required this.speed});
}

class _FloatComponent extends Component {
  final Offset origin;
  final double amplitudeX;
  final double amplitudeY;
  final double speed;
  double time = 0;

  _FloatComponent({
    required this.origin,
    required this.amplitudeX,
    required this.amplitudeY,
    required this.speed,
  });
}

class _PulseScaleComponent extends Component {
  final double minScale;
  final double maxScale;
  final double speed;
  final double phase;
  double time = 0;

  _PulseScaleComponent({
    required this.minScale,
    required this.maxScale,
    required this.speed,
    this.phase = 0,
  });
}

class _OrbitChildComponent extends Component {
  final double radius;
  final double speed;
  final double phase;
  double angle = 0;

  _OrbitChildComponent({
    required this.radius,
    required this.speed,
    this.phase = 0,
  }) : angle = phase;
}

class _EmitterMotionComponent extends Component {
  final Offset position;
  final double minRate;
  final double maxRate;
  final double speed;
  double time = 0;

  _EmitterMotionComponent({
    required this.position,
    required this.minRate,
    required this.maxRate,
    required this.speed,
  });
}

class _RaySweepComponent extends Component {
  final Offset anchor;
  final double length;
  final double radius;
  final double speed;
  double time = 0;

  _RaySweepComponent({
    required this.anchor,
    required this.length,
    required this.radius,
    required this.speed,
  });
}

class _SpinSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _SpinComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final spin = entity.getComponent<_SpinComponent>()!;
      transform.rotation += spin.speed * dt;
    });
  }
}

class _FloatSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _FloatComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final motion = entity.getComponent<_FloatComponent>()!;
      motion.time += dt;
      final angle = motion.time * motion.speed;
      transform.position = Offset(
        motion.origin.dx + math.cos(angle) * motion.amplitudeX,
        motion.origin.dy + math.sin(angle * 1.3) * motion.amplitudeY,
      );
    });
  }
}

class _PulseScaleSystem extends System {
  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    _PulseScaleComponent,
  ];

  @override
  void update(double dt) {
    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final pulse = entity.getComponent<_PulseScaleComponent>()!;
      pulse.time += dt;
      final wave = (math.sin(pulse.phase + (pulse.time * pulse.speed)) + 1) / 2;
      transform.scale =
          pulse.minScale + (pulse.maxScale - pulse.minScale) * wave;
    });
  }
}

class _OrbitChildSystem extends System {
  @override
  List<Type> get requiredComponents => [ParentComponent, _OrbitChildComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final parent = entity.getComponent<ParentComponent>()!;
      final orbit = entity.getComponent<_OrbitChildComponent>()!;
      orbit.angle += orbit.speed * dt;
      parent.localOffset = Offset(
        math.cos(orbit.angle) * orbit.radius,
        math.sin(orbit.angle) * orbit.radius,
      );
      parent.localRotation = orbit.angle;
    });
  }
}

class _EmitterSystem extends System {
  @override
  List<Type> get requiredComponents => [
    RenderableComponent,
    _EmitterMotionComponent,
  ];

  @override
  void update(double dt) {
    forEach((entity) {
      final renderComp = entity.getComponent<RenderableComponent>()!;
      final motion = entity.getComponent<_EmitterMotionComponent>()!;
      final emitter = renderComp.renderable as ParticleEmitter;

      motion.time += dt;
      final wave = (math.sin(motion.time * motion.speed) + 1) / 2;
      emitter.position = motion.position;
      emitter.emissionRate =
          motion.minRate + (motion.maxRate - motion.minRate) * wave;
      emitter.update(dt);
    });
  }
}

class _RaySweepSystem extends System {
  @override
  List<Type> get requiredComponents => [
    RenderableComponent,
    _RaySweepComponent,
  ];

  @override
  void update(double dt) {
    forEach((entity) {
      final renderComp = entity.getComponent<RenderableComponent>()!;
      final sweep = entity.getComponent<_RaySweepComponent>()!;
      final ray = renderComp.renderable as RayRenderable;

      sweep.time += dt;
      final angle = sweep.time * sweep.speed;
      final start =
          sweep.anchor +
          Offset(
            math.cos(angle) * sweep.radius,
            math.sin(angle * 1.4) * sweep.radius,
          );
      final end =
          start +
          Offset(
            math.cos(angle + 0.45) * sweep.length,
            math.sin(angle + 0.45) * sweep.length,
          );

      ray.start = start;
      ray.end = end;
    });
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

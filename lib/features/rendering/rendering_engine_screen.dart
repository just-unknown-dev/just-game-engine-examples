import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  primitives,
  layers,
  particles,
  hierarchy,
  custom;

  String get label => switch (this) {
    primitives => 'Primitives',
    layers => 'Layers & Z-Order',
    particles => 'Particles',
    hierarchy => 'Hierarchy',
    custom => 'Custom Draw',
  };

  IconData get icon => switch (this) {
    primitives => Icons.category,
    layers => Icons.layers,
    particles => Icons.blur_on,
    hierarchy => Icons.account_tree,
    custom => Icons.draw,
  };

  Color get accentColor => switch (this) {
    primitives => const Color(0xFF29B6F6),
    layers => const Color(0xFFFFCA28),
    particles => const Color(0xFFFF7043),
    hierarchy => const Color(0xFFAB47BC),
    custom => const Color(0xFF66BB6A),
  };

  String get description => switch (this) {
    primitives =>
      'RectangleRenderable, CircleRenderable, LineRenderable, TextRenderable. '
          'Each carries position, rotation, scale, layer and zOrder.',
    layers =>
      'Renderables are sorted by layer (canvas draw order) then zOrder (tie-break). '
          'Higher layer = drawn on top. zOrder breaks ties within the same layer.',
    particles =>
      'ParticleEmitter spawns particles with configurable lifetime, start/end size, '
          'color gradient, speed, gravity, emission spread and rate.',
    hierarchy =>
      'HierarchySystem propagates parent transforms to children. '
          'ParentComponent.localOffset/localRotation let children orbit a parent.',
    custom =>
      'CustomRenderable accepts an onRender callback and a getBoundsCallback. '
          'Use it for procedural paths, gradients, glow effects or any Canvas API call.',
  };

  String get codeSnippet => switch (this) {
    primitives =>
      '// Rectangle:\n'
          'RectangleRenderable(size: const Size(100, 60),\n'
          '  fillColor: Colors.blue, strokeColor: Colors.white,\n'
          '  strokeWidth: 2, layer: 5);\n\n'
          '// Circle:\n'
          'CircleRenderable(radius: 30, fillColor: Colors.teal, layer: 5);\n\n'
          '// Line:\n'
          'LineRenderable(endPoint: const Offset(120, 0),\n'
          '  color: Colors.orange, width: 3, layer: 5);\n\n'
          '// Text:\n'
          "TextRenderable(text: 'Hello', layer: 5,\n"
          '  textStyle: TextStyle(color: Colors.white, fontSize: 16));',
    layers =>
      '// Draw order = sort by layer, then zOrder:\n'
          'CircleRenderable(radius: 40, layer: 1, zOrder: 0);  // bottom\n'
          'RectangleRenderable(size: Size(80, 80), layer: 2, zOrder: 0); // mid\n'
          'CircleRenderable(radius: 20, layer: 3, zOrder: 0);  // top\n\n'
          '// Same layer, different zOrder:\n'
          'CircleRenderable(radius: 30, layer: 5, zOrder: 0);  // behind\n'
          'CircleRenderable(radius: 30, layer: 5, zOrder: 1);  // in front',
    particles =>
      'ParticleEmitter(\n'
          '  position: Offset(0, 0),\n'
          '  maxParticles: 200,\n'
          '  emissionRate: 30,\n'
          '  particleLifetime: 1.5,\n'
          '  startSize: 12, endSize: 0,\n'
          '  startColor: Colors.orange,\n'
          '  endColor: Colors.orange.withOpacity(0),\n'
          '  speed: 40, gravity: Offset(0, -10),\n'
          '  emissionAngle: -pi / 2, emissionSpread: pi / 1.5,\n'
          ');',
    hierarchy =>
      'final parent = world.createEntityWithComponents([\n'
          '  TransformComponent(), ChildrenComponent(),\n'
          '  RenderableComponent(renderable: CircleRenderable(radius: 24)),\n'
          ']);\n\n'
          'final child = world.createEntityWithComponents([\n'
          '  TransformComponent(),\n'
          '  ParentComponent(parentId: parent.id),\n'
          '  RenderableComponent(renderable: CircleRenderable(radius: 12)),\n'
          ']);\n'
          'parent.getComponent<ChildrenComponent>()!.addChild(child.id);\n\n'
          '// Reposition child relative to parent:\n'
          'child.getComponent<ParentComponent>()!.localOffset = Offset(60, 0);',
    custom =>
      'CustomRenderable(\n'
          '  layer: 8,\n'
          '  getBoundsCallback: () => Rect.fromCircle(\n'
          '    center: Offset.zero, radius: 64),\n'
          '  onRender: (canvas, size) {\n'
          '    // Glow:\n'
          '    canvas.drawCircle(Offset.zero, 50,\n'
          '      Paint()..maskFilter =\n'
          '        MaskFilter.blur(BlurStyle.normal, 16));\n'
          '    // Custom path:\n'
          '    final path = Path()..addOval(\n'
          '      Rect.fromCircle(center: Offset.zero, radius: 40));\n'
          '    canvas.drawPath(path, Paint()..color = Colors.teal);\n'
          '  },\n'
          ');',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SpinComponent extends Component {
  _SpinComponent({required this.speed});
  final double speed;
}

class _FloatComponent extends Component {
  _FloatComponent({
    required this.origin,
    required this.amplitudeX,
    required this.amplitudeY,
    required this.speed,
  });
  final Offset origin;
  final double amplitudeX;
  final double amplitudeY;
  final double speed;
  double time = 0;
}

class _PulseComponent extends Component {
  _PulseComponent({
    required this.minScale,
    required this.maxScale,
    required this.speed,
    this.phase = 0,
  });
  final double minScale;
  final double maxScale;
  final double speed;
  final double phase;
  double time = 0;
}

class _OrbitComponent extends Component {
  _OrbitComponent({
    required this.radius,
    required this.speed,
    required this.phase,
  }) : angle = phase;
  final double radius;
  final double speed;
  final double phase;
  double angle;
}

class _EmitterMotionComponent extends Component {
  _EmitterMotionComponent({
    required this.position,
    required this.minRate,
    required this.maxRate,
    required this.speed,
  });
  final Offset position;
  final double minRate;
  final double maxRate;
  final double speed;
  double time = 0;
}

class _OrbitChildComponent extends Component {
  _OrbitChildComponent({
    required this.radius,
    required this.speed,
    this.phase = 0,
  }) : angle = phase;
  final double radius;
  final double speed;
  final double phase;
  double angle;
}

class _SpinSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _SpinComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final s = entity.getComponent<_SpinComponent>()!;
      t.rotation += s.speed * dt;
    });
  }
}

class _FloatSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _FloatComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final m = entity.getComponent<_FloatComponent>()!;
      m.time += dt;
      final a = m.time * m.speed;
      t.position = Offset(
        m.origin.dx + math.cos(a) * m.amplitudeX,
        m.origin.dy + math.sin(a * 1.3) * m.amplitudeY,
      );
    });
  }
}

class _PulseSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _PulseComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final p = entity.getComponent<_PulseComponent>()!;
      p.time += dt;
      final wave = (math.sin(p.phase + p.time * p.speed) + 1) / 2;
      t.scale = p.minScale + (p.maxScale - p.minScale) * wave;
    });
  }
}

class _OrbitSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _OrbitComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final o = entity.getComponent<_OrbitComponent>()!;
      o.angle += o.speed * dt;
      t.position = Offset(
        math.cos(o.angle) * o.radius,
        math.sin(o.angle) * o.radius,
      );
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
      final rc = entity.getComponent<RenderableComponent>()!;
      final m = entity.getComponent<_EmitterMotionComponent>()!;
      final emitter = rc.renderable as ParticleEmitter;
      m.time += dt;
      final wave = (math.sin(m.time * m.speed) + 1) / 2;
      emitter.position = m.position;
      emitter.emissionRate = m.minRate + (m.maxRate - m.minRate) * wave;
      emitter.update(dt);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class RenderingEngineScreen extends StatefulWidget {
  const RenderingEngineScreen({super.key});

  @override
  State<RenderingEngineScreen> createState() => _RenderingEngineScreenState();
}

class _RenderingEngineScreenState extends State<RenderingEngineScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;

  _Demo _demo = _Demo.primitives;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildDemo(_demo));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world.destroyAllEntities();
    _world.clearSystems();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    _world.update(dt);
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo construction
  // ─────────────────────────────────────────────────────────────────────────

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';

    _world.destroyAllEntities();
    _world.clearSystems();
    _engine.rendering.camera.reset();

    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));
    _world.addSystem(_SpinSystem()..priority = 85);
    _world.addSystem(_FloatSystem()..priority = 82);
    _world.addSystem(_PulseSystem()..priority = 80);
    _world.addSystem(_OrbitSystem()..priority = 78);
    _world.addSystem(_OrbitChildSystem()..priority = 75);
    _world.addSystem(HierarchySystem()..priority = 70);
    _world.addSystem(_EmitterSystem()..priority = 65);

    _spawnGrid();

    switch (demo) {
      case _Demo.primitives:
        _buildPrimitives();
      case _Demo.layers:
        _buildLayers();
      case _Demo.particles:
        _buildParticles();
      case _Demo.hierarchy:
        _buildHierarchy();
      case _Demo.custom:
        _buildCustom();
    }

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared background grid
  // ─────────────────────────────────────────────────────────────────────────

  void _spawnGrid() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          getBoundsCallback: () => const Rect.fromLTWH(-900, -600, 1800, 1200),
          onRender: (canvas, _) {
            final gridPaint = Paint()
              ..color = const Color(0xFF1A2535)
              ..strokeWidth = 1.0;
            for (double x = -900; x <= 900; x += 80) {
              canvas.drawLine(Offset(x, -600), Offset(x, 600), gridPaint);
            }
            for (double y = -600; y <= 600; y += 80) {
              canvas.drawLine(Offset(-900, y), Offset(900, y), gridPaint);
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
  }

  void _spawnLabel(String text, Offset position, {Color? color}) {
    _world.createEntityWithComponents([
      TransformComponent(position: position),
      RenderableComponent(
        renderable: TextRenderable(
          text: text,
          textStyle: TextStyle(
            color: color ?? const Color(0xFFB0C8E0),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          layer: 30,
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Primitives
  // ─────────────────────────────────────────────────────────────────────────

  void _buildPrimitives() {
    // Rectangle cluster — top-left
    for (int i = 0; i < 3; i++) {
      _world.createEntityWithComponents([
        TransformComponent(
          position: Offset(-240 + i * 30, -60 + i * 16),
          rotation: -0.18 + i * 0.12,
        ),
        RenderableComponent(
          renderable: RectangleRenderable(
            size: const Size(150, 96),
            fillColor: [
              const Color(0xFFE4572E),
              const Color(0xFF17BEBB),
              const Color(0xFFF4D35E),
            ][i].withValues(alpha: 0.78),
            strokeColor: Colors.white.withValues(alpha: 0.5),
            strokeWidth: 2.5,
            layer: 5,
            zOrder: i,
          ),
        ),
        _SpinComponent(speed: 0.08 + i * 0.04),
        _PulseComponent(
          minScale: 0.94,
          maxScale: 1.08,
          speed: 1.4 + i * 0.3,
          phase: i * 0.8,
        ),
      ]);
    }
    _spawnLabel('RectangleRenderable', const Offset(-240, 96));

    // Circle beacon — top-right
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(230, -50)),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: 54,
          fillColor: const Color(0xFF2E294E).withValues(alpha: 0.25),
          strokeColor: const Color(0xFF7FE3FF),
          strokeWidth: 5,
          layer: 5,
        ),
      ),
      _PulseComponent(minScale: 0.88, maxScale: 1.18, speed: 2.2),
    ]);
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(230, -50)),
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
        origin: const Offset(230, -50),
        amplitudeX: 12,
        amplitudeY: 10,
        speed: 1.6,
      ),
    ]);
    _spawnLabel('CircleRenderable', const Offset(230, 82));

    // Line fan — bottom-left
    for (int i = 0; i < 7; i++) {
      _world.createEntityWithComponents([
        TransformComponent(
          position: const Offset(-300, 170),
          rotation: -0.9 + i * 0.3,
        ),
        RenderableComponent(
          renderable: LineRenderable(
            endPoint: Offset(170 - i * 10, 0),
            color: Color.lerp(
              const Color(0xFFF4D35E),
              const Color(0xFFE4572E),
              i / 6,
            )!,
            width: 4 - i * 0.3,
            layer: 4,
          ),
        ),
        _SpinComponent(speed: 0.15 + i * 0.014),
      ]);
    }
    _spawnLabel('LineRenderable', const Offset(-300, 265));

    // Text sample — bottom-right
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(230, 150)),
      RenderableComponent(
        renderable: TextRenderable(
          text: 'TextRenderable',
          textStyle: const TextStyle(
            color: Color(0xFF7FE3FF),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
          layer: 5,
        ),
      ),
      _PulseComponent(minScale: 0.95, maxScale: 1.05, speed: 1.6),
    ]);
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(230, 195)),
      RenderableComponent(
        renderable: TextRenderable(
          text: 'color, size, weight',
          textStyle: const TextStyle(
            color: Color(0xFF8BACC0),
            fontSize: 13,
          ),
          layer: 5,
        ),
      ),
    ]);

    _statusMessage = 'Rectangle, Circle, Line, Text renderables';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Layers & Z-Order
  // ─────────────────────────────────────────────────────────────────────────

  void _buildLayers() {
    final configs = [
      (Offset(-120, 0), const Color(0xFFFF5252), 1, 0, 'layer 1'),
      (Offset(0, 0), const Color(0xFFFFCA28), 2, 0, 'layer 2'),
      (Offset(120, 0), const Color(0xFF29B6F6), 3, 0, 'layer 3'),
    ];

    for (final (pos, color, layer, zOrder, lbl) in configs) {
      _world.createEntityWithComponents([
        TransformComponent(position: pos),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: 52,
            fillColor: color.withValues(alpha: 0.85),
            strokeColor: Colors.white.withValues(alpha: 0.5),
            strokeWidth: 2,
            layer: layer,
            zOrder: zOrder,
          ),
        ),
        _SpinComponent(speed: 0.0),
      ]);
      _spawnLabel(lbl, pos + const Offset(0, 72), color: color);
    }

    // Same-layer zOrder stack — below
    final cols = [
      const Color(0xFFAB47BC),
      const Color(0xFF66BB6A),
      const Color(0xFFFF7043),
    ];
    for (int i = 0; i < 3; i++) {
      _world.createEntityWithComponents([
        TransformComponent(position: Offset(-60 + i * 50, 180)),
        RenderableComponent(
          renderable: RectangleRenderable(
            size: const Size(100, 70),
            fillColor: cols[i].withValues(alpha: 0.82),
            strokeColor: Colors.white.withValues(alpha: 0.4),
            strokeWidth: 1.5,
            layer: 5,
            zOrder: i,
          ),
        ),
      ]);
    }
    _spawnLabel('same layer, zOrder 0/1/2', const Offset(0, 267));

    _statusMessage = 'Higher layer draws on top; zOrder breaks ties';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Particles
  // ─────────────────────────────────────────────────────────────────────────

  void _buildParticles() {
    // Fire emitter
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(-160, 60)),
      RenderableComponent(
        syncTransform: false,
        renderable: ParticleEmitter(
          position: const Offset(-160, 60),
          maxParticles: 200,
          emissionRate: 28,
          particleLifetime: 1.6,
          startSize: 12,
          endSize: 0,
          startColor: const Color(0xFFFFA040),
          endColor: const Color(0x00FF2020),
          speed: 35,
          speedVariation: 20,
          gravity: const Offset(0, -10),
          emissionAngle: -math.pi / 2,
          emissionSpread: math.pi / 1.8,
          layer: 5,
        ),
      ),
      _EmitterMotionComponent(
        position: const Offset(-160, 60),
        minRate: 15,
        maxRate: 38,
        speed: 1.4,
      ),
    ]);
    _spawnLabel('Fire emitter', const Offset(-160, 140));

    // Sparkle emitter
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(60, 30)),
      RenderableComponent(
        syncTransform: false,
        renderable: ParticleEmitter(
          position: const Offset(60, 30),
          maxParticles: 150,
          emissionRate: 20,
          particleLifetime: 2.0,
          startSize: 6,
          endSize: 0,
          startColor: const Color(0xFFCCEEFF),
          endColor: const Color(0x0040AAFF),
          speed: 50,
          speedVariation: 30,
          gravity: const Offset(0, 4),
          emissionAngle: 0,
          emissionSpread: math.pi * 2,
          layer: 5,
          zOrder: 5,
        ),
      ),
      _EmitterMotionComponent(
        position: const Offset(60, 30),
        minRate: 10,
        maxRate: 30,
        speed: 0.8,
      ),
    ]);
    _spawnLabel('Sparkle emitter', const Offset(60, 140));

    _statusMessage = 'EmissionRate, lifetime, color gradient, gravity';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hierarchy
  // ─────────────────────────────────────────────────────────────────────────

  void _buildHierarchy() {
    final rootColors = [
      const Color(0xFF29B6F6),
      const Color(0xFFFF7043),
      const Color(0xFF66BB6A),
    ];
    final offsets = [
      const Offset(-200, 0),
      const Offset(0, 0),
      const Offset(200, 0),
    ];

    for (int r = 0; r < 3; r++) {
      final color = rootColors[r];
      final offset = offsets[r];

      final parent = _world.createEntityWithComponents([
        TransformComponent(position: offset),
        ChildrenComponent(),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: 24,
            fillColor: color.withValues(alpha: 0.85),
            strokeColor: Colors.white.withValues(alpha: 0.6),
            strokeWidth: 2,
            layer: 6,
          ),
        ),
        _SpinComponent(speed: 0.28 + r * 0.1),
      ]);

      final childrenComp = parent.getComponent<ChildrenComponent>()!;
      final childCount = 2 + r;

      for (int c = 0; c < childCount; c++) {
        final childColor = Color.lerp(color, Colors.white, 0.4)!;
        final child = _world.createEntityWithComponents([
          TransformComponent(),
          ParentComponent(parentId: parent.id),
          RenderableComponent(
            renderable: CircleRenderable(
              radius: 10 + r * 2,
              fillColor: childColor.withValues(alpha: 0.9),
              strokeColor: Colors.white.withValues(alpha: 0.5),
              strokeWidth: 1.5,
              layer: 7,
            ),
          ),
          _OrbitChildComponent(
            radius: 55 + c * 22,
            speed: 1.0 + c * 0.4,
            phase: c * (math.pi * 2 / childCount),
          ),
        ]);
        childrenComp.addChild(child.id);
      }

      _spawnLabel('parent $r', offset + const Offset(0, 90), color: color);
    }

    _statusMessage = 'ParentComponent + ChildrenComponent + HierarchySystem';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Custom draw
  // ─────────────────────────────────────────────────────────────────────────

  void _buildCustom() {
    // Spinning star with gradient fill
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(-180, 0), scale: 1.0),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 7,
          getBoundsCallback: () => Rect.fromCircle(
            center: Offset.zero,
            radius: 80,
          ),
          onRender: (canvas, _) {
            canvas.drawCircle(
              Offset.zero,
              70,
              Paint()
                ..color = const Color(0xFF7FE3FF).withValues(alpha: 0.18)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
            );
            final path = Path();
            const pts = 10;
            for (int i = 0; i < pts; i++) {
              final r = i.isEven ? 64.0 : 28.0;
              final a = -math.pi / 2 + i * math.pi / 5;
              final p = Offset(math.cos(a) * r, math.sin(a) * r);
              if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
            }
            path.close();
            canvas.drawPath(
              path,
              Paint()
                ..shader = const LinearGradient(
                  colors: [Color(0xFF17BEBB), Color(0xFF7FE3FF)],
                ).createShader(const Rect.fromLTWH(-64, -64, 128, 128)),
            );
            canvas.drawPath(
              path,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5,
            );
          },
        ),
      ),
      _SpinComponent(speed: -0.22),
      _PulseComponent(minScale: 0.9, maxScale: 1.1, speed: 1.8),
    ]);
    _spawnLabel('gradient + path', const Offset(-180, 115));

    // Glow ring
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(80, 0)),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 7,
          getBoundsCallback: () => Rect.fromCircle(
            center: Offset.zero,
            radius: 80,
          ),
          onRender: (canvas, _) {
            for (double r = 60; r >= 20; r -= 8) {
              canvas.drawCircle(
                Offset.zero,
                r,
                Paint()
                  ..color = const Color(0xFFAB47BC)
                      .withValues(alpha: 0.08 + (60 - r) * 0.006)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
              );
            }
            canvas.drawCircle(
              Offset.zero,
              22,
              Paint()..color = const Color(0xFFCE93D8),
            );
            canvas.drawCircle(
              Offset.zero,
              22,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.6)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
          },
        ),
      ),
      _PulseComponent(minScale: 0.9, maxScale: 1.12, speed: 2.0),
    ]);
    _spawnLabel('glow rings', const Offset(80, 115));

    // Lissajous curve
    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -190)),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: 6,
          getBoundsCallback: () => Rect.fromCircle(
            center: Offset.zero,
            radius: 80,
          ),
          onRender: (canvas, _) {
            final paint = Paint()
              ..color = const Color(0xFF66BB6A).withValues(alpha: 0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round;
            final path = Path();
            for (int i = 0; i <= 360; i++) {
              final t = i * math.pi / 180;
              final x = 55 * math.sin(3 * t + math.pi / 4);
              final y = 55 * math.sin(2 * t);
              if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
            }
            canvas.drawPath(path, paint);
          },
        ),
      ),
    ]);
    _spawnLabel('Lissajous path', const Offset(0, -100));

    _statusMessage = 'onRender callback with full Canvas API access';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats line
  // ─────────────────────────────────────────────────────────────────────────

  String get _statsLine {
    return 'entities ${_world.entities.length}'
        '  systems ${_world.systems.length}'
        '  renderables ${_world.entities.where((e) => e.hasComponent<RenderableComponent>()).length}';
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
                'RenderingEngine  *  Renderable  *  RenderSystem',
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
    return GameCameraControls(
      camera: _engine.rendering.camera,
      enablePan: true,
      enablePinch: true,
      showZoomLevel: true,
      child: GameWidget(engine: _engine, showFPS: true, showDebug: false),
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

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0xFF060D18),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: _buildDemoControls(),
    );
  }

  Widget _buildDemoControls() {
    switch (_demo) {
      case _Demo.primitives:
      case _Demo.particles:
      case _Demo.custom:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Drag to pan  *  Scroll / pinch to zoom  *  Animating via ECS systems',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        );
      case _Demo.layers:
        return _buildLayersControls();
      case _Demo.hierarchy:
        return _buildHierarchyControls();
    }
  }

  Widget _buildLayersControls() {
    return Row(
      children: [
        const Text(
          'Layer order:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 8),
        _actionButton('Reset', const Color(0xFFFFCA28), () => _buildDemo(_Demo.layers)),
        const SizedBox(width: 12),
        const Text(
          'layer 1 < layer 2 < layer 3 in draw order',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildHierarchyControls() {
    return Row(
      children: [
        const Text(
          'HierarchySystem:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 8),
        _actionButton('Reset', const Color(0xFFAB47BC), () => _buildDemo(_Demo.hierarchy)),
        const SizedBox(width: 12),
        const Text(
          'children orbit parents via ParentComponent.localOffset',
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
          border: Border.all(
            color: _demo.accentColor.withValues(alpha: 0.35),
          ),
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
                  'just_game_engine  Rendering API',
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
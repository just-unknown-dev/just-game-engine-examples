part of 'core_rendering_screen.dart';

// The Rendering demos: primitives, layers, particles, hierarchy, custom
// drawing, and culling with the render stats.

const Map<_Demo, String> _renderingDescriptions = {
  _Demo.primitives:
      'Rectangle, Circle, Line and TextRenderable on entities via '
      'RenderableComponent, plus the ECS shape components (Circle, '
      'Rectangle, Polygon, Line, Capsule). World-space labels are '
      'TextRenderables — TextComponent left the engine in 2.0.',
  _Demo.layers:
      'RenderSystem sorts every entity by its LayerComponent (layer, then '
      'zOrder); an entity without one sorts by its renderable\'s own '
      'layer/zOrder. Equal keys keep creation order, so they never swap '
      'from frame to frame. Re-layer entities live with the buttons.',
  _Demo.particles:
      'Emitters are entities: ParticleEmitterComponent + ParticleSystemECS '
      '(not a default system). The emitter follows its entity\'s '
      'transform and RenderSystem draws it in layer order. One-shot '
      'bursts remove their entity with removeEntityWhenComplete.',
  _Demo.hierarchy:
      'Every World runs the transform hierarchy itself — no HierarchySystem. '
      'ParentComponent(localPosition, localRotation: EulerRotation) places '
      'a child in its parent\'s space; it turns and scales with the parent. '
      'Destroying a parent destroys its subtree; switching it off hides it.',
  _Demo.custom:
      'CustomRenderable accepts an onRender callback and a getBoundsCallback. '
      'Use it for procedural paths, gradients, glow effects or any Canvas '
      'API call — drawn in the RenderSystem\'s sorted pass.',
  _Demo.culling:
      '2,000 shapes over a 4000 × 3200 field. RenderSystem.cullOffscreen '
      'skips renderables whose bounds miss the view; batchShapes draws '
      'plain circles and rectangles in one drawVertices call. '
      'RenderingEngine.stats reports each frame. Zoom out to compare.',
};

const Map<_Demo, String> _renderingSnippets = {
  _Demo.primitives:
      '// Shape components draw themselves (they are RenderableComponents):\n'
      'world.createEntityWithComponents([\n'
      '  TransformComponent(position: Vector3(-320, -300, 0)),\n'
      '  CircleComponent(\n'
      '    radius: 36,\n'
      '    fillStyle: const ShapePaintStyle(color: Colors.blue),\n'
      '  ),\n'
      ']);\n'
      '// Also: RectangleComponent(width:, height:, cornerRadius:),\n'
      '// PolygonComponent(vertices:), LineComponent(start:, end:),\n'
      '// CapsuleComponent(width:, height:)\n\n'
      '// Any Renderable on an entity (angle, not rotation, in 2.x):\n'
      'world.createEntityWithComponents([\n'
      '  TransformComponent(position: Vector3(230, 150, 0), angle: 0.2),\n'
      '  RenderableComponent(\n'
      "    renderable: TextRenderable(text: 'Hello', layer: 5),\n"
      '  ),\n'
      ']);\n'
      '// RectangleRenderable(size:, fillColor:)\n'
      '// CircleRenderable(radius:, fillColor:)\n'
      '// LineRenderable(endPoint:, color:)',
  _Demo.layers:
      '// LayerComponent overrides the renderable\'s own layer/zOrder:\n'
      'final red = world.createEntityWithComponents([\n'
      '  TransformComponent(position: Vector3(-70, 0, 0)),\n'
      '  RenderableComponent(\n'
      '    renderable: CircleRenderable(radius: 52, fillColor: red),\n'
      '  ),\n'
      '  LayerComponent(layer: 1, zOrder: 0),\n'
      ']);\n\n'
      '// Re-layer at runtime — sorted again on the next frame:\n'
      'red.getComponent<LayerComponent>()!.layer = 10;\n\n'
      '// Equal (layer, zOrder): drawn in creation order, stably.\n'
      '// Conventions: LevelLayers.background (-200), main (0),\n'
      '// foreground (100).',
  _Demo.particles:
      'world.addSystem(ParticleSystemECS()); // not a default system\n\n'
      'world.createEntityWithComponents([\n'
      '  TransformComponent(position: Vector3(-160, 60, 0)),\n'
      '  ParticleEmitterComponent(\n'
      '    emitter: ParticleEmitter(\n'
      '      maxParticles: 200,\n'
      '      emissionRate: 28,\n'
      '      particleLifetime: 1.6,\n'
      '      startSize: 12, endSize: 0,\n'
      '      startColor: const Color(0xFFFFA040),\n'
      '      endColor: const Color(0x00FF2020),\n'
      '      speed: 35,\n'
      '      forces: const [GravityForce(Offset(0, -10))],\n'
      '      emissionAngle: -math.pi / 2,\n'
      '      emissionSpread: math.pi / 1.8,\n'
      '    ),\n'
      '  ),\n'
      '  LayerComponent(layer: 5),\n'
      ']);\n\n'
      '// A one-shot burst that cleans up after itself:\n'
      'ParticleEmitterComponent(\n'
      '  emitter: ParticleEffects.explosion(position: Vector3.zero()),\n'
      '  removeEntityWhenComplete: true,\n'
      ')',
  _Demo.hierarchy:
      'final sun = world.createEntityWithComponents([\n'
      '  TransformComponent(position: Vector3(-200, 0, 0)),\n'
      '  RenderableComponent(renderable: CircleRenderable(\n'
      '    radius: 24, fillColor: Colors.blue)),\n'
      ']);\n'
      'final planet = world.createEntityWithComponents([\n'
      '  TransformComponent(),\n'
      '  // The whole link — the world keeps sun\'s ChildrenComponent.\n'
      '  ParentComponent(\n'
      '    parentId: sun.id,\n'
      '    localPosition: Vector3(60, 0, 0),\n'
      '    localRotation: EulerRotation(0, 0, 0.5),\n'
      '  ),\n'
      '  RenderableComponent(renderable: CircleRenderable(\n'
      '    radius: 12, fillColor: Colors.white)),\n'
      ']);\n\n'
      '// Orbit in the parent\'s space (from a system):\n'
      'planet.getComponent<ParentComponent>()!\n'
      '  ..localPosition.setValues(x, y, 0)\n'
      '  ..localRotation.z = a;\n\n'
      'sun.isActive = false;     // hides the whole subtree\n'
      'world.destroyEntity(sun); // destroys planet and its moons too',
  _Demo.custom:
      'world.createEntityWithComponents([\n'
      '  TransformComponent(position: Vector3(-180, 0, 0)),\n'
      '  RenderableComponent(\n'
      '    renderable: CustomRenderable(\n'
      '      layer: 7,\n'
      '      getBoundsCallback: () =>\n'
      '          Rect.fromCircle(center: Offset.zero, radius: 64),\n'
      '      onRender: (canvas, size) {\n'
      '        // Glow:\n'
      '        canvas.drawCircle(Offset.zero, 50, Paint()\n'
      '          ..maskFilter =\n'
      '              const MaskFilter.blur(BlurStyle.normal, 16));\n'
      '        // Custom path:\n'
      '        final path = Path()..addOval(\n'
      '          Rect.fromCircle(center: Offset.zero, radius: 40));\n'
      '        canvas.drawPath(path, Paint()..color = Colors.teal);\n'
      '      },\n'
      '    ),\n'
      '  ),\n'
      ']);',
  _Demo.culling:
      '// The default RenderSystem (DefaultSystem.rendering) is opt-in:\n'
      'final render = world.getSystem<RenderSystem>()!;\n'
      'render.cullOffscreen = true; // skip what the view cannot see\n'
      'render.batchShapes = true;   // plain shapes, one draw call\n\n'
      '// Or build one yourself, wired to the engine\'s stats:\n'
      '// RenderSystem(camera: cam, cullOffscreen: true,\n'
      '//              statsSink: engine.rendering)\n\n'
      'final stats = engine.rendering.stats;\n'
      "stats['drawCalls']; stats['renderedObjects'];\n"
      "stats['culledObjects']; stats['lastRenderMs'];\n\n"
      '// Culling that also pauses far-away simulation:\n'
      '// world.addSystem(ViewCullingSystem(camera: cam));\n'
      '// entity.addComponent(CullStateComponent());',
};

// -----------------------------------------------------------------------------
// ECS helpers
// -----------------------------------------------------------------------------

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

/// Modulates a particle emitter's emission rate over time.
class _EmitterPulseComponent extends Component {
  _EmitterPulseComponent({
    required this.minRate,
    required this.maxRate,
    required this.speed,
  });
  final double minRate;
  final double maxRate;
  final double speed;
  double time = 0;
}

/// A child that orbits its parent by moving its local transform.
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
      t.angle += s.speed * dt;
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
      t.position.setValues(
        m.origin.dx + math.cos(a) * m.amplitudeX,
        m.origin.dy + math.sin(a * 1.3) * m.amplitudeY,
        0,
      );
    });
  }
}

/// Moves each orbiting child in its parent's space; the world's transform
/// hierarchy turns that into a world transform after this system runs.
class _OrbitChildSystem extends System {
  @override
  List<Type> get requiredComponents => [ParentComponent, _OrbitChildComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final link = entity.getComponent<ParentComponent>()!;
      final orbit = entity.getComponent<_OrbitChildComponent>()!;
      orbit.angle += orbit.speed * dt;
      link.localPosition.setValues(
        math.cos(orbit.angle) * orbit.radius,
        math.sin(orbit.angle) * orbit.radius,
        0,
      );
      link.localRotation.z = orbit.angle;
    });
  }
}

/// Breathes each emitter's emission rate. `ParticleSystemECS` does the
/// rest: it moves the emitter to its entity and advances it.
class _EmitterPulseSystem extends System {
  @override
  List<Type> get requiredComponents => [
    ParticleEmitterComponent,
    _EmitterPulseComponent,
  ];

  @override
  void update(double dt) {
    forEach((entity) {
      final emitter = entity.getComponent<ParticleEmitterComponent>()!.emitter;
      final m = entity.getComponent<_EmitterPulseComponent>()!;
      m.time += dt;
      final wave = (math.sin(m.time * m.speed) + 1) / 2;
      emitter.emissionRate = m.minRate + (m.maxRate - m.minRate) * wave;
    });
  }
}

// -----------------------------------------------------------------------------
// Builders and controls
// -----------------------------------------------------------------------------

extension _RenderingDemos on _CoreRenderingScreenState {
  RenderSystem? get _renderSystem => _world.getSystem<RenderSystem>();

  /// A world-space label: a [TextRenderable] on an entity (1.x's
  /// `TextComponent` moved to just_ui_editor).
  Entity _spawnLabel(
    String text,
    Offset position, {
    Color? color,
    List<Component> extra = const [],
  }) {
    return _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(position)),
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
      ...extra,
    ]);
  }

  // -------------------------------------------------------------------------
  // Primitives
  // -------------------------------------------------------------------------

  void _buildPrimitives() {
    // Rectangle cluster — top-left
    for (int i = 0; i < 3; i++) {
      _world.createEntityWithComponents([
        TransformComponent(
          position: Vector3.fromOffset(Offset(-240 + i * 30, -60 + i * 16)),
          angle: -0.18 + i * 0.12,
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
      TransformComponent(position: Vector3.fromOffset(const Offset(230, -50))),
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
      TransformComponent(position: Vector3.fromOffset(const Offset(230, -50))),
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
          position: Vector3.fromOffset(const Offset(-300, 170)),
          angle: -0.9 + i * 0.3,
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
      TransformComponent(position: Vector3.fromOffset(const Offset(230, 150))),
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
      TransformComponent(
        position: Vector3.fromOffset(const Offset(230, 195)),
        angle: -0.06,
      ),
      RenderableComponent(
        renderable: TextRenderable(
          text: 'color, size, weight, angle',
          textStyle: const TextStyle(color: Color(0xFF8BACC0), fontSize: 13),
          layer: 5,
        ),
      ),
    ]);

    _statusMessage = 'Rectangle, Circle, Line, Text renderables';

    // -- ECS Shape Components section --------------------------------------
    _buildShapeEntities();
  }

  // -------------------------------------------------------------------------
  // Shape ECS component entities (shown inside Primitives tab)
  // -------------------------------------------------------------------------

  void _buildShapeEntities() {
    const double row = -300.0; // y row for shape section
    const double labelRow = row + 60.0;

    // Section header
    _spawnLabel(
      '-- ECS Shape Components --',
      const Offset(0, row - 55),
      color: const Color(0xFF29B6F6),
    );

    // CircleComponent
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(const Offset(-320, row))),
      CircleComponent(
        radius: 36,
        fillStyle: const ShapePaintStyle(color: Color(0xFF29B6F6)),
        filled: true,
        strokeWidth: 2.5,
      ),
      _PulseComponent(minScale: 0.9, maxScale: 1.1, speed: 1.8),
      _SpinComponent(speed: 0.2),
    ]);
    _spawnLabel(
      'CircleComponent',
      const Offset(-320, labelRow),
      color: const Color(0xFF29B6F6),
    );

    // RectangleComponent (rounded corners)
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(const Offset(-160, row))),
      RectangleComponent(
        width: 80,
        height: 52,
        cornerRadius: 10,
        fillStyle: const ShapePaintStyle(color: Color(0xFF66BB6A)),
        filled: true,
        strokeWidth: 2.5,
      ),
      _SpinComponent(speed: 0.18),
      _PulseComponent(minScale: 0.88, maxScale: 1.1, speed: 1.5, phase: 1.0),
    ]);
    _spawnLabel(
      'RectangleComponent',
      const Offset(-160, labelRow),
      color: const Color(0xFF66BB6A),
    );

    // PolygonComponent (pentagon)
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(const Offset(0, row))),
      PolygonComponent(
        vertices: List.generate(5, (i) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          return Offset(math.cos(a) * 36, math.sin(a) * 36);
        }),
        fillStyle: const ShapePaintStyle(color: Color(0xFFFFA040)),
        filled: true,
        strokeWidth: 2.5,
      ),
      _SpinComponent(speed: -0.25),
      _PulseComponent(minScale: 0.9, maxScale: 1.1, speed: 2.0, phase: 0.5),
    ]);
    _spawnLabel(
      'PolygonComponent',
      const Offset(0, labelRow),
      color: const Color(0xFFFFA040),
    );

    // LineComponent
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(const Offset(160, row))),
      LineComponent(
        start: const Offset(-38, 0),
        end: const Offset(38, 0),
        strokeStyle: const ShapePaintStyle(color: Color(0xFFFF7043)),
        strokeWidth: 4,
        roundCaps: true,
      ),
      _SpinComponent(speed: 1.1),
    ]);
    _spawnLabel(
      'LineComponent',
      const Offset(160, labelRow),
      color: const Color(0xFFFF7043),
    );

    // CapsuleComponent
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(const Offset(320, row))),
      CapsuleComponent(
        width: 44,
        height: 76,
        fillStyle: const ShapePaintStyle(color: Color(0xFFAB47BC)),
        filled: true,
        strokeWidth: 2.5,
      ),
      _SpinComponent(speed: 0.3),
      _PulseComponent(minScale: 0.88, maxScale: 1.08, speed: 1.6, phase: 2.0),
    ]);
    _spawnLabel(
      'CapsuleComponent',
      const Offset(320, labelRow),
      color: const Color(0xFFAB47BC),
    );
  }

  // -------------------------------------------------------------------------
  // Layers & Z-Order
  // -------------------------------------------------------------------------

  void _buildLayers() {
    // Row 1 — three overlapping circles ordered by LayerComponent.layer.
    // Their renderables all say layer 0: the LayerComponent wins.
    final circles = [
      (const Offset(-70, -110), const Color(0xFFFF5252), 1),
      (const Offset(0, -110), const Color(0xFFFFCA28), 2),
      (const Offset(70, -110), const Color(0xFF29B6F6), 3),
    ];
    for (final (pos, color, layer) in circles) {
      final layerComp = LayerComponent(layerId: 'circles', layer: layer);
      _frontLayers.add(layerComp);
      _world.createEntityWithComponents([
        TransformComponent(position: Vector3.fromOffset(pos)),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: 52,
            fillColor: color.withValues(alpha: 0.9),
            strokeColor: Colors.white.withValues(alpha: 0.6),
            strokeWidth: 2,
          ),
        ),
        layerComp,
      ]);
    }
    _spawnLabel('LayerComponent.layer 1 / 2 / 3', const Offset(0, -30));

    // Row 2 — same layer, zOrder 0/1/2.
    final cols = [
      const Color(0xFFAB47BC),
      const Color(0xFF66BB6A),
      const Color(0xFFFF7043),
    ];
    for (int i = 0; i < 3; i++) {
      final layerComp = LayerComponent(layerId: 'cards', layer: 5, zOrder: i);
      _zLayers.add(layerComp);
      _world.createEntityWithComponents([
        TransformComponent(
          position: Vector3.fromOffset(Offset(-220 + i * 45, 110 + i * 14)),
        ),
        RenderableComponent(
          renderable: RectangleRenderable(
            size: const Size(110, 74),
            fillColor: cols[i].withValues(alpha: 0.92),
            strokeColor: Colors.white.withValues(alpha: 0.5),
            strokeWidth: 1.5,
          ),
        ),
        layerComp,
      ]);
    }
    _spawnLabel('same layer, zOrder 0/1/2', const Offset(-175, 200));

    // Row 3 — identical keys: drawn in creation order, every frame.
    final tied = [
      const Color(0xFF26A69A),
      const Color(0xFF5C6BC0),
      const Color(0xFFEC407A),
    ];
    for (int i = 0; i < 3; i++) {
      _world.createEntityWithComponents([
        TransformComponent(
          position: Vector3.fromOffset(Offset(130 + i * 45, 110 + i * 14)),
        ),
        RenderableComponent(
          renderable: RectangleRenderable(
            size: const Size(110, 74),
            fillColor: tied[i].withValues(alpha: 0.92),
            strokeColor: Colors.white.withValues(alpha: 0.5),
            strokeWidth: 1.5,
          ),
        ),
        LayerComponent(layerId: 'ties', layer: 5),
        // Spinning keeps changing the archetype's data; the order holds.
        _SpinComponent(speed: 0.05 * (i + 1)),
      ]);
    }
    _spawnLabel('equal keys: creation order (stable)', const Offset(175, 200));

    _statusMessage = 'Higher layer draws on top; zOrder breaks ties';
  }

  /// Rotates which circle is in front: every layer moves up one, the top
  /// one wraps to the bottom.
  void _cycleFront() {
    for (final layer in _frontLayers) {
      layer.layer = layer.layer % 3 + 1;
    }
    _refresh(() => _statusMessage = 'Re-layered: sorted again next frame');
  }

  void _reverseZ() {
    final n = _zLayers.length;
    for (final layer in _zLayers) {
      layer.zOrder = n - 1 - layer.zOrder;
    }
    _refresh(() => _statusMessage = 'zOrder reversed within layer 5');
  }

  // -------------------------------------------------------------------------
  // Particles
  // -------------------------------------------------------------------------

  void _buildParticles() {
    // Not a default system: it moves emitters to their entities and
    // advances them; RenderSystem draws them.
    _world
      ..addSystem(ParticleSystemECS())
      ..addSystem(_EmitterPulseSystem()..priority = 65);

    // Fire — the entity drifts, the emitter follows its transform.
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(const Offset(-160, 60))),
      ParticleEmitterComponent(
        emitter: ParticleEmitter(
          maxParticles: 200,
          emissionRate: 28,
          particleLifetime: 1.6,
          startSize: 12,
          endSize: 0,
          startColor: const Color(0xFFFFA040),
          endColor: const Color(0x00FF2020),
          speed: 35,
          speedVariation: 20,
          forces: const [GravityForce(Offset(0, -10))],
          emissionAngle: -math.pi / 2,
          emissionSpread: math.pi / 1.8,
        ),
      ),
      LayerComponent(layer: 5),
      _FloatComponent(
        origin: const Offset(-160, 60),
        amplitudeX: 40,
        amplitudeY: 8,
        speed: 0.9,
      ),
      _EmitterPulseComponent(minRate: 15, maxRate: 38, speed: 1.4),
    ], name: 'Fire');
    _spawnLabel('Fire (follows its entity)', const Offset(-160, 140));

    // Sparkles — stars swirled by a vortex force.
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(const Offset(110, 30))),
      ParticleEmitterComponent(
        emitter: ParticleEmitter(
          maxParticles: 160,
          emissionRate: 20,
          particleLifetime: 2.0,
          startSize: 9,
          endSize: 0,
          startColor: const Color(0xFFCCEEFF),
          endColor: const Color(0x0040AAFF),
          speed: 50,
          speedVariation: 30,
          renderer: StarParticleRenderer(),
          forces: [
            VortexForce(
              center: const Offset(110, 30),
              strength: 90,
              radius: 160,
            ),
          ],
          emissionAngle: 0,
          emissionSpread: math.pi * 2,
        ),
      ),
      LayerComponent(layer: 5, zOrder: 5),
      _EmitterPulseComponent(minRate: 10, maxRate: 30, speed: 0.8),
    ], name: 'Sparkles');
    _spawnLabel('Sparkles (StarParticleRenderer)', const Offset(110, 140));

    _burstCount = 0;
    _statusMessage = 'Tap "Burst" for a self-removing one-shot emitter';
  }

  void _spawnBurst() {
    final rng = math.Random();
    final colors = [
      const Color(0xFFFF7043),
      const Color(0xFFFFCA28),
      const Color(0xFF29B6F6),
      const Color(0xFFAB47BC),
    ];
    final at = Offset(
      -200 + rng.nextDouble() * 400,
      -170 + rng.nextDouble() * 60,
    );
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(at)),
      ParticleEmitterComponent(
        emitter: ParticleEffects.explosion(
          position: Vector3.fromOffset(at),
          particleCount: 60,
          color: colors[rng.nextInt(colors.length)],
        ),
        // ParticleSystemECS destroys the entity once the burst is over.
        removeEntityWhenComplete: true,
      ),
      LayerComponent(layer: 8),
    ], name: 'Burst');
    _burstCount++;
    _refresh(() => _statusMessage = 'Burst #$_burstCount spawned');
  }

  String get _particleStats {
    var emitters = 0, particles = 0;
    for (final e in _world.query(const [ParticleEmitterComponent])) {
      emitters++;
      particles += e
          .getComponent<ParticleEmitterComponent>()!
          .emitter
          .particleCount;
    }
    return '  emitters $emitters  particles $particles';
  }

  // -------------------------------------------------------------------------
  // Hierarchy
  // -------------------------------------------------------------------------

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
        TransformComponent(position: Vector3.fromOffset(offset)),
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
        _PulseComponent(minScale: 0.9, maxScale: 1.1, speed: 0.8 + r * 0.3),
      ], name: 'Parent $r');
      _roots.add(parent);

      final childCount = 2 + r;
      for (int c = 0; c < childCount; c++) {
        final childColor = Color.lerp(color, Colors.white, 0.4)!;
        final radius = 55.0 + c * 22;
        final phase = c * (math.pi * 2 / childCount);
        // Local values place the child relative to its parent on the next
        // hierarchy pass; the world lists it in the parent's
        // ChildrenComponent itself.
        final child = _world.createEntityWithComponents([
          TransformComponent(),
          ParentComponent(
            parentId: parent.id,
            localPosition: Vector3(radius, 0, 0),
            localRotation: EulerRotation(0, 0, phase),
          ),
          RenderableComponent(
            renderable: RectangleRenderable(
              size: Size(18.0 + r * 3, 12.0 + r * 2),
              fillColor: childColor.withValues(alpha: 0.9),
              strokeColor: Colors.white.withValues(alpha: 0.5),
              strokeWidth: 1.5,
              layer: 7,
            ),
          ),
          _OrbitChildComponent(
            radius: radius,
            speed: 1.0 + c * 0.4,
            phase: phase,
          ),
        ]);

        // The outermost child gets a moon: a grandchild that sits still in
        // its parent's space and so circles as the child turns.
        if (c == childCount - 1) {
          _world.createEntityWithComponents([
            TransformComponent(),
            ParentComponent(
              parentId: child.id,
              localPosition: Vector3(0, 18, 0),
            ),
            RenderableComponent(
              renderable: CircleRenderable(
                radius: 4,
                fillColor: Colors.white.withValues(alpha: 0.9),
                strokeColor: color,
                strokeWidth: 1,
                layer: 8,
              ),
            ),
          ]);
        }
      }

      // The label hangs under its parent too, but with inheritTransform
      // off: it does not move with it, yet goes when the parent goes.
      _spawnLabel(
        'parent $r',
        offset + const Offset(0, 120),
        color: color,
        extra: [ParentComponent(parentId: parent.id, inheritTransform: false)],
      );
    }

    _statusMessage = 'ParentComponent only — the world runs the hierarchy';
  }

  bool _isAlive(Entity entity) => _world.getEntity(entity.id) != null;

  void _toggleRoot(int index) {
    if (index >= _roots.length || !_isAlive(_roots[index])) return;
    final root = _roots[index];
    root.isActive = !root.isActive;
    _refresh(
      () => _statusMessage = root.isActive
          ? 'Parent $index on: its subtree is back'
          : 'Parent $index off: its whole subtree is hidden',
    );
  }

  void _destroyRoot(int index) {
    if (index >= _roots.length || !_isAlive(_roots[index])) return;
    final before = _world.entities.length;
    _world.destroyEntity(_roots[index]);
    final gone = before - _world.entities.length;
    _refresh(
      () => _statusMessage =
          'Destroyed parent $index and its subtree '
          '($gone entities)',
    );
  }

  int _childCount(Entity entity) =>
      entity.getComponent<ChildrenComponent>()?.childIds.length ?? 0;

  // -------------------------------------------------------------------------
  // Custom draw
  // -------------------------------------------------------------------------

  void _buildCustom() {
    // Spinning star with gradient fill
    _world.createEntityWithComponents([
      TransformComponent(
        position: Vector3.fromOffset(const Offset(-180, 0)),
        scale: Vector3(1.0, 1.0, 1.0),
      ),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 7,
          getBoundsCallback: () =>
              Rect.fromCircle(center: Offset.zero, radius: 80),
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
              if (i == 0) {
                path.moveTo(p.dx, p.dy);
              } else {
                path.lineTo(p.dx, p.dy);
              }
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
      TransformComponent(position: Vector3.fromOffset(const Offset(80, 0))),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 7,
          getBoundsCallback: () =>
              Rect.fromCircle(center: Offset.zero, radius: 80),
          onRender: (canvas, _) {
            for (double r = 60; r >= 20; r -= 8) {
              canvas.drawCircle(
                Offset.zero,
                r,
                Paint()
                  ..color = const Color(
                    0xFFAB47BC,
                  ).withValues(alpha: 0.08 + (60 - r) * 0.006)
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
      TransformComponent(position: Vector3.fromOffset(const Offset(0, -190))),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 6,
          getBoundsCallback: () =>
              Rect.fromCircle(center: Offset.zero, radius: 80),
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
              if (i == 0) {
                path.moveTo(x, y);
              } else {
                path.lineTo(x, y);
              }
            }
            canvas.drawPath(path, paint);
          },
        ),
      ),
    ]);
    _spawnLabel('Lissajous path', const Offset(0, -100));

    _statusMessage = 'onRender callback with full Canvas API access';
  }

  // -------------------------------------------------------------------------
  // Culling & stats
  // -------------------------------------------------------------------------

  void _buildCulling() {
    const cols = 50, rows = 40;
    const spacing = 80.0;
    final rng = math.Random(7);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final pos = Offset(
          (x - cols / 2 + 0.5) * spacing,
          (y - rows / 2 + 0.5) * spacing,
        );
        final hue = (x * 7.0 + y * 5.0) % 360.0;
        final color = HSLColor.fromAHSL(1, hue, 0.65, 0.55).toColor();
        final outline = ShapePaintStyle(
          color: Color.lerp(color, Colors.white, 0.5)!,
        );
        _world.createEntityWithComponents([
          TransformComponent(position: Vector3.fromOffset(pos)),
          // Plain colours, square corners, an outline: all batchable.
          if ((x + y).isEven)
            CircleComponent(
              radius: 12 + rng.nextDouble() * 12,
              fillStyle: ShapePaintStyle(color: color),
              strokeStyle: outline,
              strokeWidth: 1.5,
            )
          else
            RectangleComponent(
              width: 22 + rng.nextDouble() * 22,
              height: 22 + rng.nextDouble() * 22,
              fillStyle: ShapePaintStyle(color: color),
              strokeStyle: outline,
              strokeWidth: 1.5,
            ),
        ]);
      }
    }
    _applyRenderFlags();
    _statusMessage = '${cols * rows} shapes — zoom out to see more of them';
  }

  void _applyRenderFlags() {
    final render = _renderSystem;
    if (render == null) return;
    render
      ..cullOffscreen = _cullOffscreen
      ..batchShapes = _batchShapes;
  }

  void _setCull(bool on) {
    _cullOffscreen = on;
    _applyRenderFlags();
    _refresh(() => _statusMessage = 'cullOffscreen = $on');
  }

  void _setBatch(bool on) {
    _batchShapes = on;
    _applyRenderFlags();
    _refresh(() => _statusMessage = 'batchShapes = $on');
  }

  String get _renderingStatsLine {
    // The whole frame's counts — the world's RenderSystem reports into
    // engine.rendering (its statsSink).
    final stats = _engine.rendering.stats;
    final ms = (stats['lastRenderMs'] as num?)?.toDouble() ?? 0;
    var line =
        'entities ${_world.entities.length}'
        '  systems ${_world.systems.length}'
        '  draws ${stats['drawCalls']}'
        '  drawn ${stats['renderedObjects']}'
        '  culled ${stats['culledObjects']}'
        '  render ${ms.toStringAsFixed(2)} ms';
    if (_demo == _Demo.particles) line += _particleStats;
    if (_demo == _Demo.hierarchy && _roots.isNotEmpty) {
      line +=
          '  children ${[for (final r in _roots) _isAlive(r) ? _childCount(r) : '-'].join('/')}';
    }
    return line;
  }

  Widget _buildLayersControls() {
    const color = Color(0xFFFFCA28);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton('Cycle front circle', color, _cycleFront),
        _actionButton('Reverse zOrder', color, _reverseZ),
        _actionButton('Reset', color, () => _buildDemo(_Demo.layers)),
        const Text(
          'LayerComponent fields are read every frame',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildParticleControls() {
    const color = Color(0xFFFF7043);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton('Burst', color, _spawnBurst),
        _actionButton('Reset', color, () => _buildDemo(_Demo.particles)),
        const Text(
          'ParticleEffects.explosion · removeEntityWhenComplete: true',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildHierarchyControls() {
    const color = Color(0xFFAB47BC);
    bool alive(int i) => i < _roots.length && _isAlive(_roots[i]);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton(
          alive(0) && !_roots[0].isActive ? 'Show parent 0' : 'Hide parent 0',
          color,
          alive(0) ? () => _toggleRoot(0) : null,
        ),
        _actionButton(
          'Destroy parent 1',
          const Color(0xFFFF5252),
          alive(1) ? () => _destroyRoot(1) : null,
        ),
        _actionButton('Reset', color, () => _buildDemo(_Demo.hierarchy)),
        const Text(
          'children orbit via ParentComponent.localPosition',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCullingControls() {
    const color = Color(0xFF26C6DA);
    final camera = _engine.cameraSystem.mainCamera;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton(
          'cullOffscreen: ${_cullOffscreen ? 'ON' : 'OFF'}',
          color,
          () => _setCull(!_cullOffscreen),
          selected: _cullOffscreen,
        ),
        _actionButton(
          'batchShapes: ${_batchShapes ? 'ON' : 'OFF'}',
          color,
          () => _setBatch(!_batchShapes),
          selected: _batchShapes,
        ),
        _actionButton('Zoom 0.2x', color, () => camera.setZoom(0.2)),
        _actionButton('Zoom 1x', color, () => camera.setZoom(1.0)),
      ],
    );
  }
}

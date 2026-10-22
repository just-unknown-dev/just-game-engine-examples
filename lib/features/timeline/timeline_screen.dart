import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/widgets.dart';

import '../../core/engine/demo_engine.dart';

// -----------------------------------------------------------------------------
// Demo mode
// -----------------------------------------------------------------------------

enum _Demo {
  asset,
  code,
  events,
  activation,
  camera,
  nested;

  String get label => switch (this) {
    asset => 'Timeline Asset',
    code => 'Built in Code',
    events => 'Events & Signals',
    activation => 'Activation',
    camera => 'Camera Shots',
    nested => 'Nested Timelines',
  };

  IconData get icon => switch (this) {
    asset => Icons.movie_filter,
    code => Icons.code,
    events => Icons.bolt,
    activation => Icons.traffic,
    camera => Icons.videocam,
    nested => Icons.account_tree,
  };

  Color get accentColor => switch (this) {
    asset => const Color(0xFF29B6F6),
    code => const Color(0xFF66BB6A),
    events => const Color(0xFFFFCA28),
    activation => const Color(0xFFFF7043),
    camera => const Color(0xFFAB47BC),
    nested => const Color(0xFFF5746F),
  };

  String get description => switch (this) {
    asset =>
      'assets/timelines/shapes_showcase.timeline.json played by a '
          'TimelinePlayerComponent(timelinePath:). Property tracks bound by '
          'name move, drop, spin, scale and recolour three shapes along '
          'bezier, eased, linear and stepped curves.',
    code =>
      'A TimelineAsset made in Dart: one PropertyTrack per lane, each with a '
          'different KeyInterpolation (step, linear, bezier, eased bounce and '
          'elastic), plus a TimelineMarker to play from.',
    events =>
      'An EventTrack fires named events as the playhead crosses them '
          '(TimelineSystem.events). An event marked signal: true goes through '
          'engine.context.signals and starts every player whose listenSignal '
          'matches.',
    activation =>
      'ActivationTrack: the bound entity is active inside its blocks and '
          'switched off outside them — a traffic light from four tracks.',
    camera =>
      'CameraShotTrack blocks raise a VirtualCameraComponent\'s priority for '
          'their length; the camera brain blends to the shot and back. Uses '
          'DefaultSystem.cameras.',
    nested =>
      'assets/timelines/parade.timeline.json holds NestedTimelineTracks: each '
          'block runs hop.timeline.json for its bound hopper on its own '
          'clock — staggered, looped and sped up. Nested events reach the log.',
  };

  String get codeSnippet => switch (this) {
    asset =>
      '// Systems: DefaultSystem.sprites adds the TimelineSystem.\n'
          'DemoEngine.reset(engine, include: {\n'
          '  DefaultSystem.rendering, DefaultSystem.sprites,\n'
          '});\n\n'
          'world.createEntityWithComponents([\n'
          '  TimelinePlayerComponent(\n'
          "    timelinePath: 'assets/timelines/shapes_showcase.timeline.json',\n"
          '    playOnStart: true,\n'
          '  ),\n'
          "], name: 'Director');\n\n"
          '// In the file, a track bound to the entity named "Box":\n'
          '// {"kind": "property", "binding": {"name": "Box"},\n'
          '//  "component": "TransformComponent", "field": "position",\n'
          '//  "channel": "x", "keys": [{"t": 0, "v": -220, "m": "flat"}, ...]}',
    code =>
      'final asset = TimelineAsset(\n'
          '  duration: 3,\n'
          '  wrap: TimelineWrap.loop,\n'
          "  markers: [TimelineMarker(time: 1.5, name: 'half')],\n"
          '  tracks: [\n'
          '    PropertyTrack(\n'
          "      binding: TrackBinding.name('Bounce'),\n"
          "      component: 'TransformComponent',\n"
          "      field: 'position',\n"
          "      channel: 'x',\n"
          '      curve: KeyCurve([\n'
          '        TimelineKey(time: 0, value: -220.0,\n'
          '            interpolation: KeyInterpolation.eased,\n'
          "            easing: 'easeOutBounce'),\n"
          '        TimelineKey(time: 3, value: 220.0),\n'
          '      ]),\n'
          '    ),\n'
          '  ],\n'
          ');\n'
          'world.createEntityWithComponents([\n'
          '  TimelinePlayerComponent(inline: asset, playOnStart: true,\n'
          '      wrap: TimelineWrapChoice.pingPong),\n'
          ']);\n'
          "player.playFrom('half');",
    events =>
      'EventTrack(events: const [\n'
          "  TimelineEvent(time: 0.5, name: 'spark', payload: 'left gate'),\n"
          "  TimelineEvent(time: 2.0, name: 'boom', signal: true),\n"
          ']);\n\n'
          '// Every event any timeline fires:\n'
          'final sub = world.getSystem<TimelineSystem>()!.events.listen(\n'
          "  (e) => log('\${e.owner.name}: \${e.name} \${e.payload}'),\n"
          ');\n\n'
          '// A player started by the signal (or by code):\n'
          "TimelinePlayerComponent(inline: flash, listenSignal: 'boom');\n"
          "engine.context.signals.emit('boom');",
    activation =>
      'ActivationTrack(\n'
          "  binding: TrackBinding.name('Green Lamp'),\n"
          '  blocks: const [TimelineBlock(start: 2.5, length: 2.9)],\n'
          ');\n\n'
          '// Inside a block the entity is active; outside it,\n'
          '// entity.isActive is false and systems pass it by.\n'
          '// After a play the entity stays as the timeline left it.',
    camera =>
      "world.createEntityWithComponents([\n"
          '  TransformComponent(position: Vector3(160, -20, 0)),\n'
          '  VirtualCameraComponent(priority: 5, zoom: 2.4),\n'
          "], name: 'Close Cam');\n\n"
          'CameraShotTrack(blocks: const [\n'
          '  // value: the camera entity, amount: the priority boost\n'
          "  TimelineBlock(start: 1, length: 1.5, value: 'Close Cam',\n"
          '      amount: 100),\n'
          ']);\n\n'
          '// engine.cameraSystem.brain blends to the highest priority.',
    nested =>
      '// parade.timeline.json\n'
          '{"kind": "nested", "binding": {"name": "Hopper 4"},\n'
          ' "blocks": [{"start": 1.6, "length": 2.0,\n'
          '   "value": "assets/timelines/hop.timeline.json",\n'
          '   "speed": 2.0, "loop": true}]}\n\n'
          '// In Dart:\n'
          'NestedTimelineTrack(\n'
          "  binding: TrackBinding.name('Hopper 1'),\n"
          '  blocks: const [TimelineBlock(start: 0, length: 1,\n'
          "      value: 'assets/timelines/hop.timeline.json')],\n"
          ');',
  };
}

// -----------------------------------------------------------------------------
// A component of the demo's own, so a timeline can key a shape's colour
// -----------------------------------------------------------------------------

/// The fill colour of the shape on the same entity.
///
/// A shape's `fillStyle` is a style a timeline cannot key; a `color` field
/// it can. Its [ComponentDefinition] makes `FillColorComponent.color`
/// reachable from a property track, in a file or in code.
class _FillColorComponent extends Component {
  _FillColorComponent({this.color = const Color(0xFFFFFFFF)});

  Color color;
}

final ComponentDefinition<_FillColorComponent> _fillColorDefinition =
    ComponentDefinition<_FillColorComponent>(
      type: 'FillColorComponent',
      create: _FillColorComponent.new,
      fields: [
        SchemaField(
          name: 'color',
          kind: FieldTypes.color,
          read: (c) => (c as _FillColorComponent).color,
          write: (c, v) => (c as _FillColorComponent).color = v as Color,
        ),
      ],
    );

/// Installs [_fillColorDefinition] into the shared engine's context. An
/// extension is installed once per context by its id, so building the
/// screen again does nothing the second time.
final class _TimelineDemoExtension implements ContextExtension {
  const _TimelineDemoExtension();

  @override
  String get id => 'just_game_engine_examples.timeline_demo';

  @override
  void install(EngineContext context) {
    context.definitions.register(_fillColorDefinition);
  }
}

/// Copies [_FillColorComponent.color] into the entity's shape.
class _FillColorSystem extends System {
  _FillColorSystem() {
    // After the timeline system (animation + 2) has keyed it this step.
    priority = SystemPriorities.gameplay;
  }

  @override
  List<Type> get requiredComponents => const [_FillColorComponent];

  @override
  void update(double deltaTime) {
    forEach((entity) {
      final color = entity.getComponent<_FillColorComponent>()!.color;
      // Every shape is filed under RenderableComponent: an entity draws one.
      switch (entity.getComponent<RenderableComponent>()) {
        case final RectangleComponent shape when shape.fillStyle.color != color:
          shape.fillStyle = ShapePaintStyle(color: color);
        case final CircleComponent shape when shape.fillStyle.color != color:
          shape.fillStyle = ShapePaintStyle(color: color);
        case final PolygonComponent shape when shape.fillStyle.color != color:
          shape.fillStyle = ShapePaintStyle(color: color);
        default:
          break;
      }
    });
  }
}

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

enum _Panel { tracks, events, code }

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;
  late final Ticker _ticker;

  final GlobalKey _canvasKey = GlobalKey();

  _Demo _demo = _Demo.asset;
  _Panel _panel = _Panel.tracks;

  /// The player the transport controls drive.
  TimelinePlayerComponent? _player;

  final List<String> _log = [];
  int _eventCount = 0;
  StreamSubscription<TimelineEventFired>? _eventSub;
  StreamSubscription<String>? _signalSub;

  bool _resumeAfterScrub = false;
  double _speed = 1.0;

  static const String _showcasePath =
      'assets/timelines/shapes_showcase.timeline.json';
  static const String _paradePath = 'assets/timelines/parade.timeline.json';

  @override
  void initState() {
    super.initState();
    _engine.context.install(const _TimelineDemoExtension());
    _signalSub = _engine.context.signals.stream.listen(
      (name) => _addLog('signal  "$name"'),
    );
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })..start();
    _buildDemo(_demo);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _eventSub?.cancel();
    _signalSub?.cancel();
    DemoEngine.reset(_engine);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Demo construction
  // ---------------------------------------------------------------------------

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _player = null;
    _speed = 1.0;
    _log.clear();
    _eventCount = 0;
    _eventSub?.cancel();

    DemoEngine.reset(
      _engine,
      include: {
        DefaultSystem.rendering,
        DefaultSystem.sprites,
        if (demo == _Demo.camera) DefaultSystem.cameras,
      },
    );
    _world.addSystem(_FillColorSystem());
    _eventSub = _world.getSystem<TimelineSystem>()?.events.listen(_onEvent);

    switch (demo) {
      case _Demo.asset:
        _buildAsset();
      case _Demo.code:
        _buildCode();
      case _Demo.events:
        _buildEvents();
      case _Demo.activation:
        _buildActivation();
      case _Demo.camera:
        _buildCamera();
      case _Demo.nested:
        _buildNested();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
  }

  /// Zooms the camera so the demo's 640 × 420 world area fits the canvas.
  void _fitCamera() {
    if (!mounted) return;
    final size = _canvasKey.currentContext?.size;
    if (size == null || size.isEmpty) return;
    final fit = math.min(size.width / 640, size.height / 420);
    _engine.cameraSystem.mainCamera.setZoom(fit.clamp(0.4, 1.5).toDouble());
  }

  void _onEvent(TimelineEventFired event) {
    _eventCount++;
    // A nested timeline's events come from the entity it is bound to,
    // which has no player of its own: the director's clock tells the time.
    final at =
        event.owner.getComponent<TimelinePlayerComponent>()?.time ??
        _player?.time ??
        0;
    final payload = event.payload.isEmpty ? '' : '  "${event.payload}"';
    _addLog(
      '${at.toStringAsFixed(2)}s  ${event.owner.name ?? '#${event.owner.id}'}'
      '  ${event.name}$payload',
    );
  }

  void _addLog(String line) {
    _log.insert(0, line);
    if (_log.length > 80) _log.removeLast();
  }

  // ── Entity helpers ─────────────────────────────────────────────────────────

  Entity _spawn(
    String name,
    Offset at,
    Component shape, {
    Color? fill,
    int z = 1,
    List<String> tags = const [],
    double angle = 0,
  }) {
    return _world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0), angle: angle),
      shape,
      LayerComponent(zOrder: z),
      if (fill != null) _FillColorComponent(color: fill),
      if (tags.isNotEmpty) TagComponent.of(tags),
    ], name: name);
  }

  void _label(String text, Offset at, {Color color = Colors.white54}) {
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0)),
      RenderableComponent(
        renderable: TextRenderable(
          text: text,
          textStyle: TextStyle(color: color, fontSize: 11),
        ),
      ),
      LayerComponent(zOrder: 20),
    ], name: 'Label: $text');
  }

  void _backdrop() {
    _spawn(
      'Backdrop',
      Offset.zero,
      RectangleComponent(
        width: 700,
        height: 460,
        fillStyle: const ShapePaintStyle(color: Color(0xFF0B1424)),
        strokeStyle: const ShapePaintStyle(color: Color(0xFF1E2E40)),
        strokeWidth: 2,
        cornerRadius: 12,
      ),
      z: -10,
    );
  }

  Entity _director(TimelinePlayerComponent player, {String name = 'Director'}) {
    final entity = _world.createEntityWithComponents([player], name: name);
    _player = player;
    return entity;
  }

  // ── Timeline asset from a file ─────────────────────────────────────────────

  void _buildAsset() {
    _backdrop();
    _spawn(
      'Floor',
      const Offset(0, -18),
      RectangleComponent(
        width: 520,
        height: 4,
        fillStyle: const ShapePaintStyle(color: Color(0xFF263850)),
      ),
      z: 0,
    );
    _spawn(
      'Box',
      const Offset(-220, -150),
      RectangleComponent(width: 48, height: 48, cornerRadius: 10),
      fill: const Color(0xFF29B6F6),
      z: 2,
    );
    _spawn(
      'Star',
      const Offset(-130, 110),
      PolygonComponent(
        vertices: _starPoints(5, 46, 20),
        fillStyle: const ShapePaintStyle(color: Color(0xFFFFCA28)),
      ),
      z: 2,
    );
    _spawn(
      'Orb',
      const Offset(130, 110),
      CircleComponent(radius: 34),
      fill: const Color(0xFF66BB6A),
      z: 2,
    );
    _label(
      'Box: position.x (bezier), .y (eased bounce), colour',
      const Offset(0, -196),
    );
    _label('Star: rotation.z (linear)', const Offset(-130, 180));
    _label(
      'Orb: scale.x / .y (flat bezier), colour (step)',
      const Offset(130, 180),
    );

    _director(
      TimelinePlayerComponent(timelinePath: _showcasePath, playOnStart: true),
    );
  }

  static List<Offset> _starPoints(int points, double outer, double inner) => [
    for (var i = 0; i < points * 2; i++)
      Offset(
        math.cos(-math.pi / 2 + i * math.pi / points) *
            (i.isEven ? outer : inner),
        math.sin(-math.pi / 2 + i * math.pi / points) *
            (i.isEven ? outer : inner),
      ),
  ];

  // ── A timeline built in code ───────────────────────────────────────────────

  void _buildCode() {
    _backdrop();
    const lanes = <(String, Color)>[
      ('Step', Color(0xFF90A4AE)),
      ('Linear', Color(0xFF29B6F6)),
      ('Bezier', Color(0xFF66BB6A)),
      ('Bounce', Color(0xFFFFCA28)),
      ('Elastic', Color(0xFFF5746F)),
    ];
    for (var i = 0; i < lanes.length; i++) {
      final (name, color) = lanes[i];
      final y = -150.0 + i * 72;
      _spawn(
        '$name Rail',
        Offset(0, y),
        RectangleComponent(
          width: 480,
          height: 2,
          fillStyle: const ShapePaintStyle(color: Color(0xFF263850)),
        ),
        z: 0,
      );
      _spawn(
        name,
        Offset(-240, y),
        CircleComponent(radius: 14),
        fill: color,
        z: 2,
      );
      _label(name, Offset(-290, y), color: color);
    }
    _spawn(
      'Marker Line',
      const Offset(0, -6),
      RectangleComponent(
        width: 2,
        height: 330,
        fillStyle: const ShapePaintStyle(color: Color(0x5566BB6A)),
      ),
      z: 1,
    );
    _label(
      "marker 'half' (1.5 s)",
      const Offset(0, -186),
      color: const Color(0xFF66BB6A),
    );

    _director(
      TimelinePlayerComponent(
        inline: _raceTimeline(),
        playOnStart: true,
        wrap: TimelineWrapChoice.pingPong,
      ),
    );
  }

  /// One [PropertyTrack] per lane, each reaching the same place in its own
  /// way.
  static TimelineAsset _raceTimeline() {
    PropertyTrack lane(String name, KeyCurve curve) => PropertyTrack(
      name: name,
      binding: TrackBinding.name(name),
      component: 'TransformComponent',
      field: 'position',
      channel: 'x',
      curve: curve,
    );

    return TimelineAsset(
      name: 'race',
      duration: 3,
      wrap: TimelineWrap.loop,
      markers: const [TimelineMarker(time: 1.5, name: 'half')],
      tracks: [
        lane(
          'Step',
          KeyCurve(const [
            TimelineKey(
              time: 0,
              value: -240.0,
              interpolation: KeyInterpolation.step,
            ),
            TimelineKey(
              time: 1,
              value: -80.0,
              interpolation: KeyInterpolation.step,
            ),
            TimelineKey(
              time: 2,
              value: 80.0,
              interpolation: KeyInterpolation.step,
            ),
            TimelineKey(time: 3, value: 240.0),
          ]),
        ),
        lane(
          'Linear',
          KeyCurve(const [
            TimelineKey(
              time: 0,
              value: -240.0,
              interpolation: KeyInterpolation.linear,
            ),
            TimelineKey(time: 3, value: 240.0),
          ]),
        ),
        lane(
          'Bezier',
          // Flat handles, worked out from the neighbours: ease in and out.
          KeyCurve(const [
            TimelineKey(time: 0, value: -240.0, tangentMode: TangentMode.flat),
            TimelineKey(time: 3, value: 240.0, tangentMode: TangentMode.flat),
          ]).withAutoTangents(),
        ),
        lane(
          'Bounce',
          KeyCurve(const [
            TimelineKey(
              time: 0,
              value: -240.0,
              interpolation: KeyInterpolation.eased,
              easing: 'easeOutBounce',
            ),
            TimelineKey(time: 3, value: 240.0),
          ]),
        ),
        lane(
          'Elastic',
          KeyCurve(const [
            TimelineKey(
              time: 0,
              value: -240.0,
              interpolation: KeyInterpolation.eased,
              easing: 'easeOutElastic',
            ),
            TimelineKey(time: 3, value: 240.0),
          ]),
        ),
      ],
    );
  }

  // ── Events and signals ─────────────────────────────────────────────────────

  void _buildEvents() {
    _backdrop();
    for (final (name, x) in const [
      ('Left Gate', -160.0),
      ('Centre Gate', 0.0),
      ('Right Gate', 160.0),
    ]) {
      _spawn(
        name,
        Offset(x, -40),
        RectangleComponent(
          width: 6,
          height: 90,
          fillStyle: const ShapePaintStyle(color: Color(0xFF37506E)),
        ),
        z: 0,
      );
    }
    _spawn(
      'Comet',
      const Offset(-260, -40),
      CircleComponent(radius: 16),
      fill: const Color(0xFFFFCA28),
      z: 3,
    );
    final flashEntity = _spawn(
      'Flash',
      const Offset(0, 110),
      CircleComponent(radius: 30),
      fill: const Color(0xFFF5746F),
      z: 2,
    );
    _label(
      'events: spark @0.5 s · boom (signal) @2.0 s · spark @3.5 s',
      const Offset(0, -150),
    );
    _label(
      "Flash: TimelinePlayerComponent(listenSignal: 'boom')",
      const Offset(0, 170),
    );

    // The flash: started by the 'boom' signal, from the timeline or a button.
    final flash = TimelineAsset(
      name: 'flash',
      duration: 0.6,
      tracks: [
        for (final channel in const ['x', 'y'])
          PropertyTrack(
            component: 'TransformComponent',
            field: 'scale',
            channel: channel,
            curve: KeyCurve(const [
              TimelineKey(time: 0, value: 1.0),
              TimelineKey(time: 0.15, value: 2.2),
              TimelineKey(time: 0.6, value: 1.0),
            ]).withAutoTangents(),
          ),
        PropertyTrack(
          component: 'FillColorComponent',
          field: 'color',
          isColor: true,
          curve: KeyCurve(const [
            TimelineKey(
              time: 0,
              value: 0xFFFFFFFF,
              interpolation: KeyInterpolation.linear,
            ),
            TimelineKey(time: 0.6, value: 0xFFF5746F),
          ]),
        ),
      ],
    );
    flashEntity.addComponent(
      TimelinePlayerComponent(inline: flash, listenSignal: 'boom'),
    );

    _director(
      TimelinePlayerComponent(
        playOnStart: true,
        inline: TimelineAsset(
          name: 'comet_run',
          duration: 4,
          wrap: TimelineWrap.loop,
          tracks: [
            PropertyTrack(
              name: 'Fly',
              binding: const TrackBinding.name('Comet'),
              component: 'TransformComponent',
              field: 'position',
              channel: 'x',
              curve: KeyCurve(const [
                TimelineKey(
                  time: 0,
                  value: -260.0,
                  interpolation: KeyInterpolation.linear,
                ),
                TimelineKey(time: 4, value: 260.0),
              ]),
            ),
            EventTrack(
              name: 'Cues',
              events: const [
                TimelineEvent(time: 0.5, name: 'spark', payload: 'left gate'),
                TimelineEvent(
                  time: 2.0,
                  name: 'boom',
                  payload: 'centre gate',
                  signal: true,
                ),
                TimelineEvent(time: 3.5, name: 'spark', payload: 'right gate'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Activation ─────────────────────────────────────────────────────────────

  void _buildActivation() {
    _backdrop();
    _spawn(
      'Housing',
      const Offset(-60, 0),
      RectangleComponent(
        width: 96,
        height: 260,
        cornerRadius: 18,
        fillStyle: const ShapePaintStyle(color: Color(0xFF1C232B)),
        strokeStyle: const ShapePaintStyle(color: Color(0xFF455A64)),
        strokeWidth: 3,
      ),
      z: 0,
    );
    const lamps = <(String, Color, double)>[
      ('Red Lamp', Color(0xFFE53935), -80),
      ('Amber Lamp', Color(0xFFFFB300), 0),
      ('Green Lamp', Color(0xFF43A047), 80),
    ];
    for (final (name, color, y) in lamps) {
      // A dim bulb behind each lamp, always on: what "off" looks like.
      _spawn(
        '$name (off)',
        Offset(-60, y),
        CircleComponent(
          radius: 30,
          fillStyle: ShapePaintStyle(color: color.withValues(alpha: 0.16)),
        ),
        z: 1,
      );
      _spawn(
        name,
        Offset(-60, y),
        CircleComponent(radius: 30),
        fill: color,
        z: 2,
      );
    }
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3(110, 0, 0)),
      RenderableComponent(
        renderable: TextRenderable(
          text: 'WALK',
          textStyle: const TextStyle(
            color: Color(0xFFE0F7FA),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ),
      LayerComponent(zOrder: 3),
    ], name: 'Walk Sign');
    _label('one ActivationTrack per lamp, bound by name', const Offset(0, 170));

    ActivationTrack on(String name, List<TimelineBlock> blocks) =>
        ActivationTrack(
          name: name,
          binding: TrackBinding.name(name),
          blocks: blocks,
        );

    _director(
      TimelinePlayerComponent(
        playOnStart: true,
        inline: TimelineAsset(
          name: 'traffic_light',
          duration: 6,
          wrap: TimelineWrap.loop,
          tracks: [
            on('Red Lamp', const [TimelineBlock(start: 0, length: 2.5)]),
            on('Amber Lamp', const [
              TimelineBlock(start: 2.0, length: 0.5),
              TimelineBlock(start: 5.4, length: 0.6),
            ]),
            on('Green Lamp', const [TimelineBlock(start: 2.5, length: 2.9)]),
            on('Walk Sign', const [TimelineBlock(start: 0.2, length: 1.8)]),
            EventTrack(
              name: 'Cues',
              events: const [
                TimelineEvent(time: 0, name: 'stop'),
                TimelineEvent(time: 2.5, name: 'go'),
                TimelineEvent(time: 5.4, name: 'caution'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Camera shots ───────────────────────────────────────────────────────────

  void _buildCamera() {
    _backdrop();
    _world.createEntityWithComponents([
      TransformComponent(),
      VirtualCameraComponent(priority: 10, zoom: 0.9),
    ], name: 'Wide Cam');
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3(160, -30, 0)),
      VirtualCameraComponent(priority: 5, zoom: 2.4),
    ], name: 'Close Cam');
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3(-170, 50, 0)),
      VirtualCameraComponent(priority: 5, zoom: 1.8, dutch: -0.12),
    ], name: 'Detail Cam');

    _spawn(
      'Rocket',
      const Offset(160, -30),
      PolygonComponent(
        vertices: const [
          Offset(0, -46),
          Offset(16, -10),
          Offset(16, 30),
          Offset(28, 46),
          Offset(-28, 46),
          Offset(-16, 30),
          Offset(-16, -10),
        ],
        fillStyle: const ShapePaintStyle(color: Color(0xFFECEFF1)),
      ),
      z: 2,
    );
    _spawn(
      'Window',
      const Offset(160, -36),
      CircleComponent(radius: 8),
      fill: const Color(0xFF29B6F6),
      z: 3,
    );
    _spawn(
      'Flag Pole',
      const Offset(-170, 50),
      RectangleComponent(
        width: 4,
        height: 110,
        fillStyle: const ShapePaintStyle(color: Color(0xFFB0BEC5)),
      ),
      z: 1,
    );
    _spawn(
      'Flag',
      const Offset(-148, 12),
      RectangleComponent(width: 44, height: 28),
      fill: const Color(0xFFF5746F),
      z: 2,
    );
    _label(
      'Wide Cam (priority 10) · Close Cam / Detail Cam (5, +100 in a shot)',
      const Offset(0, 170),
    );

    _director(
      TimelinePlayerComponent(
        playOnStart: true,
        inline: TimelineAsset(
          name: 'cutscene',
          duration: 6.5,
          wrap: TimelineWrap.loop,
          tracks: [
            CameraShotTrack(
              name: 'Shots',
              blocks: const [
                TimelineBlock(
                  start: 1.0,
                  length: 1.6,
                  value: 'Close Cam',
                  amount: 100,
                ),
                TimelineBlock(
                  start: 3.8,
                  length: 1.6,
                  value: 'Detail Cam',
                  amount: 100,
                ),
              ],
            ),
            PropertyTrack(
              name: 'Wave',
              binding: const TrackBinding.name('Flag'),
              component: 'TransformComponent',
              field: 'rotation',
              channel: 'z',
              curve: KeyCurve(const [
                TimelineKey(time: 0, value: 0.0, tangentMode: TangentMode.flat),
                TimelineKey(
                  time: 3.25,
                  value: 0.35,
                  tangentMode: TangentMode.flat,
                ),
                TimelineKey(
                  time: 6.5,
                  value: 0.0,
                  tangentMode: TangentMode.flat,
                ),
              ]).withAutoTangents(),
            ),
            PropertyTrack(
              name: 'Blink',
              binding: const TrackBinding.name('Window'),
              component: 'FillColorComponent',
              field: 'color',
              isColor: true,
              curve: KeyCurve(const [
                TimelineKey(
                  time: 0,
                  value: 0xFF29B6F6,
                  interpolation: KeyInterpolation.step,
                ),
                TimelineKey(
                  time: 1.4,
                  value: 0xFFFFCA28,
                  interpolation: KeyInterpolation.step,
                ),
                TimelineKey(time: 2.2, value: 0xFF29B6F6),
              ]),
            ),
            EventTrack(
              name: 'Cuts',
              events: const [
                TimelineEvent(time: 1.0, name: 'cut', payload: 'Close Cam'),
                TimelineEvent(time: 3.8, name: 'cut', payload: 'Detail Cam'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Nested timelines ───────────────────────────────────────────────────────

  void _buildNested() {
    _backdrop();
    _spawn(
      'Ground',
      const Offset(0, 96),
      RectangleComponent(
        width: 560,
        height: 6,
        fillStyle: const ShapePaintStyle(color: Color(0xFF37506E)),
      ),
      z: 0,
    );
    const colors = [
      Color(0xFF29B6F6),
      Color(0xFF66BB6A),
      Color(0xFFFFCA28),
      Color(0xFFF5746F),
    ];
    for (var i = 0; i < 4; i++) {
      final x = -180.0 + i * 120;
      _spawn(
        'Hopper ${i + 1}',
        Offset(x, 70),
        RectangleComponent(width: 40, height: 40, cornerRadius: 8),
        fill: colors[i],
        z: 2,
      );
      _label(
        i == 3 ? 'Hopper 4: loop ×2 speed' : 'Hopper ${i + 1}',
        Offset(x, 130),
        color: colors[i],
      );
    }
    _label(
      'parade.timeline.json → 4 nested tracks → hop.timeline.json',
      const Offset(0, -150),
    );
    _director(
      TimelinePlayerComponent(timelinePath: _paradePath, playOnStart: true),
    );
  }

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  TimelinePlayback? get _playback => _player?.playback;

  void _setWrap(TimelineWrapChoice wrap) =>
      setState(() => _player?.wrap = wrap);

  void _setSpeed(double speed) {
    final player = _player;
    if (player == null) return;
    setState(() {
      _speed = speed;
      player.speed = player.speed < 0 ? -speed : speed;
    });
  }

  void _toggleDirection() {
    final player = _player;
    if (player == null) return;
    setState(() => player.speed < 0 ? player.forwards() : player.reverse());
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  String get _statsLine {
    final playback = _playback;
    final player = _player;
    if (player == null || playback == null) {
      return 'loading timeline…  entities ${_world.entityCount}';
    }
    final state = player.isPlaying
        ? (player.speed < 0 ? 'playing ◀' : 'playing ▶')
        : player.isFinished
        ? 'finished'
        : 'paused';
    return 't ${playback.time.toStringAsFixed(2)} / '
        '${playback.duration.toStringAsFixed(2)} s  '
        '$state  wrap ${playback.effectiveWrap.name}  '
        'speed ${player.speed.toStringAsFixed(2)}  '
        'tracks ${playback.asset.tracks.length}  events $_eventCount';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _canvas),
        _buildDemoSelector(),
        _buildTransport(),
        _buildBottomPanel(),
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
              Flexible(
                child: Text(
                  _demo.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _demo.accentColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Spacer(),
              const Flexible(
                child: Text(
                  'TimelineAsset  *  TimelinePlayerComponent  *  TimelineSystem',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Color(0xFFF5746F), fontSize: 10),
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
        ],
      ),
    );
  }

  /// Made once: the per-frame `setState` for the HUD hands Flutter the same
  /// widget, so the game view is not rebuilt.
  late final Widget _canvas = KeyedSubtree(
    key: _canvasKey,
    child: GameCameraControls(
      camera: _engine.cameraSystem.mainCamera,
      enablePan: true,
      enablePinch: true,
      showZoomLevel: true,
      child: GameWidget(engine: _engine, showFPS: true),
    ),
  );

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
              separatorBuilder: (_, _) => const SizedBox(width: 6),
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
                  onSelected: (_) => setState(() => _buildDemo(d)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransport() {
    final player = _player;
    final playback = _playback;
    final accent = _demo.accentColor;
    final duration = playback?.duration ?? 0;
    final time = (playback?.time ?? 0).clamp(0.0, duration).toDouble();
    final hasMarkers = playback?.asset.markers.isNotEmpty ?? false;
    final ready = player != null && playback != null;

    return Container(
      color: const Color(0xFF060D18),
      padding: const EdgeInsets.fromLTRB(8, 2, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _iconButton(
                Icons.play_arrow,
                'Play',
                accent,
                ready ? () => player.play() : null,
              ),
              _iconButton(
                Icons.pause,
                'Pause',
                accent,
                ready ? () => player.pause() : null,
              ),
              _iconButton(
                Icons.stop,
                'Stop (rewind)',
                accent,
                ready ? () => player.stop() : null,
              ),
              _iconButton(
                Icons.replay,
                'Restart',
                accent,
                ready ? () => player.restart() : null,
              ),
              _iconButton(
                (player?.speed ?? 1) < 0 ? Icons.east : Icons.west,
                (player?.speed ?? 1) < 0 ? 'Forwards' : 'Reverse',
                accent,
                ready ? _toggleDirection : null,
              ),
              if (hasMarkers)
                _iconButton(
                  Icons.flag,
                  "Play from marker '${playback!.asset.markers.last.name}'",
                  accent,
                  () => player!.playFrom(playback.asset.markers.last.name),
                ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: time,
                    min: 0,
                    max: duration > 0 ? duration : 1,
                    activeColor: accent,
                    inactiveColor: const Color(0xFF1E2E40),
                    onChangeStart: ready
                        ? (_) {
                            _resumeAfterScrub = player.isPlaying;
                            player.pause();
                          }
                        : null,
                    onChanged: ready ? (v) => player.seek(v) : null,
                    onChangeEnd: ready
                        ? (_) {
                            if (_resumeAfterScrub) player.play();
                          }
                        : null,
                  ),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${time.toStringAsFixed(2)} s',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 6),
                const Text(
                  'speed',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(width: 6),
                for (final s in const [0.25, 0.5, 1.0, 2.0])
                  _choice(
                    s == s.roundToDouble() ? '${s.toInt()}×' : '$s×',
                    _speed == s,
                    accent,
                    ready ? () => _setSpeed(s) : null,
                  ),
                const SizedBox(width: 14),
                const Text(
                  'wrap',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(width: 6),
                for (final w in TimelineWrapChoice.values)
                  _choice(
                    switch (w) {
                      TimelineWrapChoice.fromTimeline => 'asset',
                      TimelineWrapChoice.once => 'once',
                      TimelineWrapChoice.loop => 'loop',
                      TimelineWrapChoice.pingPong => 'ping-pong',
                    },
                    player?.wrap == w,
                    accent,
                    ready ? () => _setWrap(w) : null,
                  ),
                if (_demo == _Demo.events) ...[
                  const SizedBox(width: 14),
                  _choice(
                    "emit 'boom'",
                    false,
                    const Color(0xFFFFCA28),
                    () => _engine.context.signals.emit('boom'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback? onTap,
  ) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      color: color,
      disabledColor: Colors.white24,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }

  Widget _choice(String label, bool active, Color color, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.2)
                : const Color(0xFF0E1A2A),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.75)
                  : const Color(0xFF1E2E40),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null
                  ? Colors.white24
                  : active
                  ? Colors.white
                  : Colors.white60,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final accent = _demo.accentColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF090F1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final p in _Panel.values)
                  _choice(
                    switch (p) {
                      _Panel.tracks => 'Tracks',
                      _Panel.events => 'Event log ($_eventCount)',
                      _Panel.code => 'Code',
                    },
                    _panel == p,
                    accent,
                    () => setState(() => _panel = p),
                  ),
                const Spacer(),
                const Flexible(
                  child: Text(
                    'just_game_engine  Timeline API',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: switch (_panel) {
                _Panel.tracks => _buildTrackView(),
                _Panel.events => _buildEventLog(),
                _Panel.code => SingleChildScrollView(
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackView() {
    final playback = _playback;
    if (playback == null) {
      return const Center(
        child: Text(
          'Loading the timeline…',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }
    final asset = playback.asset;
    final height =
        _TrackLanesPainter.ruler +
        asset.tracks.length * _TrackLanesPainter.lane +
        4;
    return SingleChildScrollView(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _TrackLanesPainter(
            asset: asset,
            time: playback.time,
            duration: playback.duration,
            accent: _demo.accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEventLog() {
    if (_log.isEmpty) {
      return const Center(
        child: Text(
          'No events yet: EventTracks fire as the playhead crosses them.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }
    return ListView.builder(
      itemCount: _log.length,
      itemExtent: 17,
      itemBuilder: (context, i) => Text(
        _log[i],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _log[i].startsWith('signal')
              ? const Color(0xFFFFCA28)
              : const Color(0xFFB0C8E0),
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Track lanes: the playing timeline, drawn the way an editor shows one
// -----------------------------------------------------------------------------

class _TrackLanesPainter extends CustomPainter {
  _TrackLanesPainter({
    required this.asset,
    required this.time,
    required this.duration,
    required this.accent,
  });

  final TimelineAsset asset;
  final double time;
  final double duration;
  final Color accent;

  static const double ruler = 16;
  static const double lane = 18;
  static const double labelWidth = 128;

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.max(size.width - labelWidth - 6, 10.0);
    double xOf(double t) =>
        labelWidth +
        (duration <= 0 ? 0 : (t / duration).clamp(0.0, 1.0)) * width;

    // Ruler: a tick every half second, a number every second.
    final tick = Paint()..color = const Color(0xFF2A3A50);
    for (var t = 0.0; t <= duration + 1e-6; t += 0.5) {
      final x = xOf(t);
      final whole = (t - t.roundToDouble()).abs() < 1e-6;
      canvas.drawLine(Offset(x, whole ? 2 : 8), Offset(x, ruler), tick);
      if (whole) {
        _text(
          canvas,
          '${t.round()}s',
          Offset(x + 2, 0),
          const Color(0xFF5A6E88),
        );
      }
    }
    // Markers.
    for (final m in asset.markers) {
      final x = xOf(m.time);
      final flag = Path()
        ..moveTo(x, 2)
        ..lineTo(x + 7, 5)
        ..lineTo(x, 8)
        ..close();
      canvas.drawPath(flag, Paint()..color = const Color(0xFF66BB6A));
    }

    for (var i = 0; i < asset.tracks.length; i++) {
      final track = asset.tracks[i];
      final top = ruler + i * lane;
      final mid = top + lane / 2;
      if (i.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(0, top, size.width, lane),
          Paint()..color = const Color(0x0DFFFFFF),
        );
      }
      final name = track.name.isEmpty ? track.summary : track.name;
      final bound = track.binding.isSelf || track.binding.label == name
          ? ''
          : ' → ${track.binding.label}';
      _text(
        canvas,
        '$name$bound',
        Offset(2, top + 3),
        track.muted ? Colors.white24 : const Color(0xFF90A4AE),
        maxWidth: labelWidth - 6,
      );
      canvas.drawLine(
        Offset(labelWidth, mid),
        Offset(labelWidth + width, mid),
        Paint()..color = const Color(0xFF1A2738),
      );

      switch (track) {
        case PropertyTrack(:final curve):
          final keyPaint = Paint()..color = accent;
          for (final k in curve.keys) {
            final x = xOf(k.time);
            final diamond = Path()
              ..moveTo(x, mid - 4.5)
              ..lineTo(x + 4.5, mid)
              ..lineTo(x, mid + 4.5)
              ..lineTo(x - 4.5, mid)
              ..close();
            if (track.isColor && k.value is int) {
              canvas.drawPath(diamond, Paint()..color = Color(k.value as int));
              canvas.drawPath(
                diamond,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..color = Colors.white70,
              );
            } else {
              canvas.drawPath(diamond, keyPaint);
            }
          }
        case EventTrack(:final events):
          final paint = Paint()
            ..color = const Color(0xFFFFCA28)
            ..strokeWidth = 2;
          for (final e in events) {
            final x = xOf(e.time);
            canvas.drawLine(
              Offset(x, top + 3),
              Offset(x, top + lane - 3),
              paint,
            );
            _text(
              canvas,
              e.name,
              Offset(x + 3, top + 3),
              const Color(0xFFFFE082),
            );
          }
        case BlockTrack(:final blocks):
          for (final b in blocks) {
            final rect = Rect.fromLTRB(
              xOf(b.start),
              top + 3,
              math.max(xOf(b.end), xOf(b.start) + 3),
              top + lane - 3,
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(3)),
              Paint()..color = accent.withValues(alpha: 0.35),
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(3)),
              Paint()
                ..style = PaintingStyle.stroke
                ..color = accent.withValues(alpha: 0.8),
            );
            final value = b.value.split('/').last;
            final label = b.loop ? '$value ⟳' : value;
            if (label.isNotEmpty) {
              _text(
                canvas,
                label,
                Offset(rect.left + 3, top + 3),
                Colors.white70,
                maxWidth: math.max(rect.width - 4, 0),
              );
            }
          }
        default:
          break;
      }
    }

    // Playhead.
    final x = xOf(time);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = const Color(0xFFF5746F)
        ..strokeWidth = 1.5,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    Color color, {
    double maxWidth = 160,
  }) {
    if (maxWidth <= 4) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9.5),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, at);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_TrackLanesPainter old) =>
      old.time != time || !identical(old.asset, asset) || old.accent != accent;
}

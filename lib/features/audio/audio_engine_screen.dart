import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/engine/demo_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const String _sfxClip = 'assets/audio/test_sfx.wav';
const String _musicClip = 'assets/audio/test_music.mp3';

class _SfxRipple {
  double age = 0;
  final double maxAge;

  /// Where in the world it went off (a 3-D one-shot); null: screen centre.
  final Offset? at;
  _SfxRipple({this.maxAge = 1.4, this.at});
  double get t => (age / maxAge).clamp(0.0, 1.0);
  bool get dead => age >= maxAge;
  void tick(double dt) => age += dt;
}

/// One orbiting 3-D source of the Spatial demo: an entity with a
/// [TransformComponent] the ticker moves and an [AudioSourceComponent] with
/// `is3d: true`.
class _Spatial3dSource {
  final double radius;
  final double angularSpeed;
  final Color color;
  final String label;
  final String clip;
  final double pitch;
  double angle;

  /// The entity while the Spatial demo is built.
  Entity? entity;
  AudioSourceComponent? audio;

  _Spatial3dSource({
    required this.radius,
    required this.angularSpeed,
    required this.color,
    required this.label,
    required this.clip,
    this.pitch = 1.0,
    this.angle = 0.0,
  });

  /// World position (orbiting the world origin).
  Offset get pos => Offset(math.cos(angle) * radius, math.sin(angle) * radius);

  /// World velocity, units per second — for the doppler readout.
  Offset get velocity => Offset(
    -math.sin(angle) * radius * angularSpeed,
    math.cos(angle) * radius * angularSpeed,
  );

  void tick(double dt) => angle += angularSpeed * dt;
}

/// What the painter shows for one 3-D source: where it is and how the
/// listener hears it ([AudioSpatial.mix]).
class _SourceView {
  final Offset pos;
  final Color color;
  final String label;
  final AudioSpatialMix mix;
  final bool playing;
  const _SourceView(this.pos, this.color, this.label, this.mix, this.playing);
}

class _CompTag {
  final String text;
  final Color color;
  const _CompTag(this.text, this.color);
}

class _EcsRow {
  final String entity;
  final List<_CompTag> tags;
  bool flash = false;
  double flashAge = 0;

  /// The component its buttons drive (`play()/pause()/resume()/stop()`);
  /// null for the one-shot row.
  AudioRequests? target;

  /// Live state read back from the component.
  String state = '';
  _EcsRow(this.entity, this.tags);
}

// ─────────────────────────────────────────────────────────────────────────────
// Demo enum
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  bgm,
  sfx,
  channels,
  dspEffects,
  spatial3d,
  ecsIntegration,
  voicePool,
  streaming;

  String get label => switch (this) {
    bgm => 'BGM',
    sfx => 'SFX',
    channels => 'Channels',
    dspEffects => 'DSP Effects',
    spatial3d => 'Spatial 3D',
    ecsIntegration => 'ECS',
    voicePool => 'Voice Pool',
    streaming => 'Streaming',
  };

  IconData get icon => switch (this) {
    bgm => Icons.music_note,
    sfx => Icons.flash_on,
    channels => Icons.tune,
    dspEffects => Icons.equalizer,
    spatial3d => Icons.spatial_audio,
    ecsIntegration => Icons.grid_view,
    voicePool => Icons.layers,
    streaming => Icons.stream,
  };

  Color get accentColor => switch (this) {
    bgm => const Color(0xFF66BB6A),
    sfx => const Color(0xFFFFCA28),
    channels => const Color(0xFF29B6F6),
    dspEffects => const Color(0xFFAB47BC),
    spatial3d => const Color(0xFFFF7043),
    ecsIntegration => const Color(0xFF26A69A),
    voicePool => const Color(0xFFEC407A),
    streaming => const Color(0xFF78909C),
  };

  String get description => switch (this) {
    bgm =>
      'MusicManager wraps AudioEngine.playMusic with fade-in/out, loop and channel routing. One track at a time; switching cross-fades.',
    sfx =>
      'SoundEffectManager fires one-shot or looping SFX. Returns a clip ID for per-voice volume, pan, pitch, speed, pause, resume, and stop.',
    channels =>
      'AudioChannel (master, music, sfx, voice, ambient) maps to AudioBus nodes. setChannelVolume multiplies bus gain; master applies globally.',
    dspEffects =>
      'AudioEffect carries a type + param map applied per voice. Reverb, lowpass, highpass, EQ and delay toggle independently.',
    spatial3d =>
      'Three entities orbit with AudioSourceComponent(is3d: true): full volume within minDistance, silent beyond maxDistance, faded by rolloff, muffled by farCutoff, pitched by dopplerLevel. Drag the AudioListenerComponent (white) around — AudioSystem places every source once per frame.',
    ecsIntegration =>
      'AudioSourceComponent / AudioStreamComponent are data; play(), pause(), resume() and stop() ask the AudioSystem (AudioRequests). One-shots need no component: AudioSystem.playOneShot().',
    voicePool =>
      'VoicePool tracks up to 64 handles. On overflow the oldest unprotected voice is evicted. Music voices are protected.',
    streaming =>
      'AudioStream opens a file with stream:true for chunked decoding. Use for music or long ambient loops to avoid memory spikes.',
  };

  String get codeSnippet => switch (this) {
    bgm =>
      '// Via MusicManager convenience wrapper:\n'
          'engine.music.play(\n'
          "  'assets/audio/bgm.mp3',\n"
          '  loop: true,\n'
          '  fadeIn: true,\n'
          '  fadeDuration: const Duration(seconds: 2),\n'
          ');\n\n'
          'engine.music.pause();\n'
          'engine.music.resume();\n'
          'engine.music.stop(fadeOut: true);\n'
          'engine.music.setChannelVolume(0.7);\n'
          'engine.music.isPlaying; // → bool',
    sfx =>
      'final id = await engine.sfx.play(\n'
          "  'assets/audio/hit.wav',\n"
          '  volume: 0.8, pan: -0.5,\n'
          '  pitch: 1.2, speed: 0.9,\n'
          ');\n\n'
          '// Per-voice controls after launch:\n'
          'engine.audio.setSfxVolume(id!, 0.5);\n'
          'engine.audio.pauseSfx(id!);\n'
          'engine.audio.resumeSfx(id!);\n'
          'engine.audio.stopSfx(id!);\n'
          'engine.audio.stopAllSfx();\n\n'
          '// From gameplay code — nothing added to an entity:\n'
          'world.getSystem<AudioSystem>()?.playOneShot(\n'
          "  'assets/audio/hit.wav', pitch: 1.2,\n"
          ');',
    channels =>
      'engine.audio.setMasterVolume(1.0);\n'
          'engine.audio.setChannelVolume(AudioChannel.master,  1.0);\n'
          'engine.audio.setChannelVolume(AudioChannel.music,   0.7);\n'
          'engine.audio.setChannelVolume(AudioChannel.sfx,     1.0);\n'
          'engine.audio.setChannelVolume(AudioChannel.voice,   0.9);\n'
          'engine.audio.setChannelVolume(AudioChannel.ambient, 0.5);\n\n'
          '// Read back:\n'
          'engine.audio.getChannelVolume(AudioChannel.music); // → 0.7\n\n'
          'engine.audio.mute();\n'
          'engine.audio.unmute();\n'
          'engine.audio.toggleMute();',
    dspEffects =>
      'await engine.audio.playSfx(\n'
          "  'assets/audio/hit.wav',\n"
          '  effects: [\n'
          '    AudioEffect.reverb(roomSize: 0.8, damping: 0.5, wetLevel: 0.4),\n'
          '    AudioEffect.lowpass(frequency: 800, q: 1.0),\n'
          '    AudioEffect.highpass(frequency: 200, q: 1.0),\n'
          '    AudioEffect.delay(delayMs: 250, feedback: 0.3, mix: 0.3),\n'
          '    AudioEffect.eq(frequency: 1000, gain: 3.0, q: 1.0),\n'
          '  ],\n'
          ');',
    spatial3d =>
      '// DefaultSystem.audio adds AudioSystem(engine: engine.audio,\n'
          '//   camera: engine.cameraSystem.mainCamera).\n'
          "// The ear: at its entity (atCamera / faceCamera hear from the camera).\n"
          'world.createEntityWithComponents([\n'
          '  TransformComponent(),\n'
          '  AudioListenerComponent(atCamera: false),\n'
          "], name: 'Listener');\n\n"
          '// A source heard from where its entity is:\n'
          'final hum = AudioSourceComponent(\n'
          "  clipPath: 'assets/audio/test_sfx.wav',\n"
          '  loop: true,\n'
          '  is3d: true,\n'
          '  minDistance: 40,   // full volume inside\n'
          '  maxDistance: 320,  // silent beyond\n'
          '  rolloff: AudioRolloff.inverse, // .linear, .none\n'
          '  dopplerLevel: 0.5, // pitch shift from motion\n'
          '  farCutoff: 600,    // Hz low-pass at maxDistance\n'
          ');\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(120, 0, 0)),\n'
          '  hum,\n'
          "], name: 'Drone');\n"
          'hum.play();\n'
          '// Move the entities; changes to the fields apply at once.\n'
          'engine.audio.speedOfSound = 600; // world units / s\n\n'
          '// A placed one-shot:\n'
          'world.getSystem<AudioSystem>()?.playOneShot(\n'
          "  'assets/audio/test_sfx.wav',\n"
          '  position: Vector3(80, -40, 0),\n'
          '  spatial: const AudioSpatial(minDistance: 40, maxDistance: 320),\n'
          ');',
    ecsIntegration =>
      '// Data on entities; AudioSystem plays them.\n'
          'final fire = AudioSourceComponent(\n'
          "  clipPath: 'assets/audio/fire.ogg',\n"
          '  loop: true, volume: 0.8, pitch: 0.7,\n'
          '  playOnAdd: false, // true: starts when the system sees it\n'
          '  channel: AudioChannel.ambient,\n'
          '  effects: [AudioEffect.reverb()],\n'
          ');\n'
          "world.createEntityWithComponents([fire], name: 'FireEmitter');\n\n"
          '// Control — carried out at the next update (AudioRequests):\n'
          'fire.play();   // from the start\n'
          'fire.pause();\n'
          'fire.resume();\n'
          'fire.stop();\n'
          'fire.handle;   // sound id while it plays, else null\n\n'
          '// One-shot, nothing added to an entity:\n'
          'world.getSystem<AudioSystem>()?.playOneShot(\n'
          "  'assets/audio/coin.wav', pitch: 1.3,\n"
          ');\n\n'
          '// Streaming via ECS:\n'
          'final radio = AudioStreamComponent(\n'
          "  path: 'assets/audio/bgm.mp3',\n"
          '  playOnAdd: false,\n'
          '  fadeInDuration: const Duration(seconds: 2),\n'
          ');\n'
          "world.createEntityWithComponents([radio], name: 'Radio');\n"
          'radio.play(); // .pause() .resume() .stop(), radio.isPlaying',
    voicePool =>
      '// Default pool capacity = 64.  Slot 0 → protected music voice.\n'
          '// Each playSfx call registers into the pool:\n'
          'for (int i = 0; i < 80; i++) {\n'
          "  engine.audio.playSfx('assets/audio/sfx.wav');\n"
          '}\n'
          '// On overflow, oldest unprotected voice is evicted.\n\n'
          '// Stop all SFX (resets non-protected voices):\n'
          'engine.audio.stopAllSfx();',
    streaming =>
      'final stream = AudioStream(\n'
          "  path: 'assets/audio/bgm.mp3',\n"
          '  channel: AudioChannel.music,\n'
          ');\n'
          'await stream.open(engine.audio.backend);\n'
          'await stream.play(volume: 0.8, loop: true);\n\n'
          'await stream.setVolume(0.5);\n'
          'await stream.fade(0.0, const Duration(seconds: 2));\n'
          'await stream.pause();\n'
          'await stream.resume();\n'
          'await stream.stop();\n'
          'await stream.dispose();\n\n'
          '// Or via ECS (AudioSystem opens and drives it):\n'
          'final radio = AudioStreamComponent(\n'
          "  path: 'assets/audio/bgm.mp3',\n"
          '  fadeInDuration: const Duration(seconds: 2),\n'
          ');\n'
          'world.createEntityWithComponents([radio]);\n'
          'radio.pause(); radio.resume(); radio.stop();',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AudioEngineScreen extends StatefulWidget {
  const AudioEngineScreen({super.key});

  @override
  State<AudioEngineScreen> createState() => _AudioEngineScreenState();
}

class _AudioEngineScreenState extends State<AudioEngineScreen>
    with SingleTickerProviderStateMixin {
  // ── Engine ────────────────────────────────────────────────────────────────
  // The app's shared engine: already running, ticked by the GameWidget below
  // (fixed steps, the per-frame phase and the audio engine).
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;
  // Only drives the canvas animation and the live stats (setState).
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _elapsed = 0;

  // ── Demo ──────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.bgm;
  String _status = 'Ready.';

  // ── BGM ───────────────────────────────────────────────────────────────────
  bool _musicPlaying = false;
  bool _musicPaused = false;

  // ── SFX ───────────────────────────────────────────────────────────────────
  double _sfxPitch = 1.0;
  double _sfxSpeed = 1.0;
  double _sfxPan = 0.0;
  String? _activeSfxId;
  bool _sfxPaused = false;
  final List<_SfxRipple> _ripples = [];

  // ── Channels ──────────────────────────────────────────────────────────────
  double _masterVol = 1.0;
  double _musicVol = 1.0;
  double _sfxVol = 1.0;
  double _voiceVol = 1.0;
  double _ambientVol = 1.0;
  bool _muted = false;

  // ── DSP ───────────────────────────────────────────────────────────────────
  bool _dspReverb = false;
  bool _dspLowpass = false;
  bool _dspHighpass = false;
  bool _dspDelay = false;
  bool _dspEq = false;

  // ── Spatial 3D ────────────────────────────────────────────────────────────
  final List<_Spatial3dSource> _sources = [];
  Entity? _listener;
  bool _spatialPlaying = false;
  bool _spatialPaused = false;
  AudioRolloff _rolloff = AudioRolloff.inverse;
  double _minDistance = 40;
  double _maxDistance = 320;
  double _doppler = 0.5;
  bool _farCutoff = true;
  bool _listenerAtCamera = false;
  final math.Random _rng = math.Random();

  // ── ECS ───────────────────────────────────────────────────────────────────
  final List<_EcsRow> _ecsRows = [];

  // ── Shared-engine state this screen changes and puts back ─────────────────
  final Map<AudioChannel, double> _savedVolumes = {};
  bool _savedMuted = false;
  double _savedSpeedOfSound = AudioSpatial.speedOfSoundInAir;
  Color _savedBackground = const Color(0xFF1a1a2e);

  // ── Voice pool ────────────────────────────────────────────────────────────
  int _voiceCount = 0;
  final int _voiceMax = 64;

  // ── Streaming ─────────────────────────────────────────────────────────────
  AudioStream? _stream;
  bool _streamOpen = false;
  bool _streamPlaying = false;
  bool _streamPaused = false;
  double _streamVol = 0.8;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final audio = _engine.audio;
    // The engine is shared by every demo: remember what this screen changes.
    for (final channel in AudioChannel.values) {
      _savedVolumes[channel] = audio.getChannelVolume(channel);
    }
    _savedMuted = audio.isMuted;
    _savedSpeedOfSound = audio.speedOfSound;
    _savedBackground = _engine.rendering.backgroundColor;
    _masterVol = audio.getChannelVolume(AudioChannel.master);
    _musicVol = audio.getChannelVolume(AudioChannel.music);
    _sfxVol = audio.getChannelVolume(AudioChannel.sfx);
    _voiceVol = audio.getChannelVolume(AudioChannel.voice);
    _ambientVol = audio.getChannelVolume(AudioChannel.ambient);
    _muted = audio.isMuted;
    // Doppler works in world units per second; this world is in pixels.
    audio.speedOfSound = 600;
    _engine.rendering.backgroundColor = const Color(0xFF060D18);

    _initSources();
    _initEcsRows();
    _buildDemo();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stream?.dispose();
    final audio = _engine.audio;
    unawaited(_engine.music.stop());
    unawaited(audio.stopAllSfx());
    _savedVolumes.forEach(audio.setChannelVolume);
    if (audio.isMuted != _savedMuted) audio.toggleMute();
    audio.speedOfSound = _savedSpeedOfSound;
    _engine.rendering.backgroundColor = _savedBackground;
    // Destroys this demo's entities (AudioSystem stops their sounds as it
    // goes) and leaves the shared engine running.
    DemoEngine.reset(_engine);
    super.dispose();
  }

  void _initSources() {
    _sources
      ..add(
        _Spatial3dSource(
          radius: 150,
          angularSpeed: -0.45,
          color: const Color(0xFF29B6F6),
          label: 'Radio',
          clip: _musicClip,
          angle: math.pi * 2 / 3,
        ),
      )
      ..add(
        _Spatial3dSource(
          radius: 100,
          angularSpeed: 0.8,
          color: const Color(0xFFFF7043),
          label: 'Drone',
          clip: _sfxClip,
          pitch: 0.6,
        ),
      )
      ..add(
        _Spatial3dSource(
          radius: 60,
          angularSpeed: 1.3,
          color: const Color(0xFF66BB6A),
          label: 'Chime',
          clip: _sfxClip,
          pitch: 1.5,
          angle: math.pi * 4 / 3,
        ),
      );
  }

  void _initEcsRows() {
    _ecsRows
      ..add(
        _EcsRow('Player', [
          const _CompTag('TransformComponent', Color(0xFF78909C)),
          const _CompTag('AudioListenerComponent', Color(0xFF29B6F6)),
          const _CompTag('AudioSourceComponent', Color(0xFF66BB6A)),
        ]),
      )
      ..add(
        _EcsRow('FireEmitter', [
          const _CompTag('AudioSourceComponent  loop', Color(0xFFFF7043)),
          const _CompTag('  ambient · reverb · ×0.7', Color(0xFFFF7043)),
        ]),
      )
      ..add(
        _EcsRow('Radio', [
          const _CompTag('AudioStreamComponent', Color(0xFF78909C)),
          const _CompTag('  fadeIn 2 s · music', Color(0xFF78909C)),
        ]),
      )
      ..add(
        _EcsRow('Coin', [
          const _CompTag('no component —', Color(0xFFFFCA28)),
          const _CompTag('AudioSystem.playOneShot', Color(0xFFFFCA28)),
        ]),
      );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // World per demo
  // ─────────────────────────────────────────────────────────────────────────

  /// A clean world for [_demo]: the AudioSystem (and a RenderSystem for the
  /// Spatial demo's entities), plus the entities the demo plays through.
  /// The other demos call the AudioEngine directly.
  void _buildDemo() {
    DemoEngine.reset(
      _engine,
      include: const {DefaultSystem.rendering, DefaultSystem.audio},
    );
    _listener = null;
    for (final s in _sources) {
      s
        ..entity = null
        ..audio = null;
    }
    for (final row in _ecsRows) {
      row
        ..target = null
        ..state = '';
    }
    _spatialPlaying = false;
    _spatialPaused = false;
    switch (_demo) {
      case _Demo.spatial3d:
        _buildSpatialWorld();
      case _Demo.ecsIntegration:
        _buildEcsWorld();
      default:
        break;
    }
  }

  void _selectDemo(_Demo d) {
    if (d == _demo) return;
    setState(() {
      _demo = d;
      _buildDemo();
      _status = d == _Demo.spatial3d
          ? 'Press ▶ Play, then drag the listener'
          : 'Ready.';
    });
  }

  void _buildSpatialWorld() {
    _listener = _world.createEntityWithComponents([
      TransformComponent(),
      AudioListenerComponent(atCamera: _listenerAtCamera),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: 11,
          fillColor: Colors.white,
          strokeColor: Colors.white24,
          strokeWidth: 10,
        ),
      ),
    ], name: 'Listener');
    for (final s in _sources) {
      final p = s.pos;
      final audio = AudioSourceComponent(
        clipPath: s.clip,
        loop: true,
        playOnAdd: false,
        is3d: true,
        volume: 0.8,
        pitch: s.pitch,
        channel: AudioChannel.ambient,
        minDistance: _minDistance,
        maxDistance: _maxDistance,
        rolloff: _rolloff,
        dopplerLevel: _doppler,
        farCutoff: _farCutoff ? 600 : 0,
      );
      s
        ..audio = audio
        ..entity = _world.createEntityWithComponents([
          TransformComponent(position: Vector3(p.dx, p.dy, 0)),
          audio,
          RenderableComponent(
            renderable: CircleRenderable(radius: 9, fillColor: s.color),
          ),
        ], name: s.label);
    }
  }

  void _buildEcsWorld() {
    final voice = AudioSourceComponent(
      clipPath: _sfxClip,
      playOnAdd: false,
      volume: 0.9,
      channel: AudioChannel.voice,
    );
    _world.createEntityWithComponents([
      TransformComponent(),
      AudioListenerComponent(),
      voice,
    ], name: 'Player');
    final fire = AudioSourceComponent(
      clipPath: _sfxClip,
      loop: true,
      playOnAdd: false,
      volume: 0.7,
      pitch: 0.7,
      channel: AudioChannel.ambient,
      effects: [AudioEffect.reverb(roomSize: 0.8, damping: 0.4, wetLevel: 0.5)],
    );
    _world.createEntityWithComponents([fire], name: 'FireEmitter');
    final radio = AudioStreamComponent(
      path: _musicClip,
      playOnAdd: false,
      volume: 0.7,
      fadeInDuration: const Duration(seconds: 2),
    );
    _world.createEntityWithComponents([radio], name: 'Radio');
    _ecsRows[0].target = voice;
    _ecsRows[1].target = fire;
    _ecsRows[2].target = radio;
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
    _elapsed += dt;
    // Gameplay moves the 3-D sources; the AudioSystem reads their transforms
    // once per rendered frame and the audio engine places them.
    for (final s in _sources) {
      s.tick(dt);
      final p = s.pos;
      s.entity?.getComponent<TransformComponent>()?.position.setValues(
        p.dx,
        p.dy,
        0,
      );
    }
    for (final r in _ripples) {
      r.tick(dt);
    }
    _ripples.removeWhere((r) => r.dead);
    for (final row in _ecsRows) {
      if (row.flash) {
        row.flashAge += dt;
        if (row.flashAge > 0.5) {
          row.flash = false;
          row.flashAge = 0;
        }
      }
      row.state = switch (row.target) {
        final AudioSourceComponent c =>
          'handle: ${c.handle ?? '—'}${_pendingLabel(c)}',
        final AudioStreamComponent c =>
          'isPlaying: ${c.isPlaying}${_pendingLabel(c)}',
        _ => row.target == null && row.entity == 'Coin' ? 'fire & forget' : '',
      };
    }
    if (mounted) setState(() {});
  }

  static String _pendingLabel(AudioRequests c) {
    final pending = c.pendingRequest;
    return pending == null ? '' : '  (${pending.name}…)';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Audio stats line
  // ─────────────────────────────────────────────────────────────────────────

  String get _audioStatsLine {
    final musicState = _engine.music.isPlaying
        ? (_musicPaused ? '⏸ music' : '▶ music')
        : '■ music';
    final mutedStr = _muted ? '  [MUTED]' : '';
    final hear = _engine.audio.listener.position;
    final world = _demo == _Demo.spatial3d || _demo == _Demo.ecsIntegration
        ? '  entities:${_world.entityCount}  listener:(${hear.x.round()}, ${hear.y.round()})'
        : '';
    return '$musicState  master:${(_masterVol * 100).round()}%  voices:$_voiceCount/$_voiceMax$mutedStr$world';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BGM
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _playMusic() async {
    try {
      await _engine.music.play(
        'assets/audio/test_music.mp3',
        loop: true,
        fadeIn: true,
        fadeDuration: const Duration(seconds: 2),
      );
    } catch (_) {}
    setState(() {
      _musicPlaying = true;
      _musicPaused = false;
      _status = 'BGM playing  fadeIn:2 s  loop:true';
    });
  }

  Future<void> _pauseMusic() async {
    await _engine.music.pause();
    setState(() {
      _musicPaused = true;
      _status = 'BGM paused';
    });
  }

  Future<void> _resumeMusic() async {
    await _engine.music.resume();
    setState(() {
      _musicPaused = false;
      _status = 'BGM resumed';
    });
  }

  Future<void> _stopMusic() async {
    await _engine.music.stop(
      fadeOut: true,
      fadeDuration: const Duration(seconds: 1),
    );
    setState(() {
      _musicPlaying = false;
      _musicPaused = false;
      _status = 'BGM stopped  fadeOut:1 s';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SFX
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _playSfx() async {
    _ripples.add(_SfxRipple());
    String? id;
    try {
      id = await _engine.sfx.play(
        'assets/audio/test_sfx.wav',
        volume: 0.85,
        pan: _sfxPan,
        pitch: _sfxPitch,
        speed: _sfxSpeed,
      );
    } catch (_) {}
    setState(() {
      if (id != null) _activeSfxId = id;
      _sfxPaused = false;
      if (_voiceCount < _voiceMax) _voiceCount++;
      _status =
          'SFX  pan:${_sfxPan.toStringAsFixed(2)}  pitch:${_sfxPitch.toStringAsFixed(2)}  speed:${_sfxSpeed.toStringAsFixed(2)}';
    });
  }

  Future<void> _pauseSfx() async {
    if (_activeSfxId == null) return;
    await _engine.audio.pauseSfx(_activeSfxId!);
    setState(() {
      _sfxPaused = true;
      _status = 'SFX paused';
    });
  }

  Future<void> _resumeSfx() async {
    if (_activeSfxId == null) return;
    await _engine.audio.resumeSfx(_activeSfxId!);
    setState(() {
      _sfxPaused = false;
      _status = 'SFX resumed';
    });
  }

  Future<void> _stopSfx() async {
    if (_activeSfxId == null) return;
    await _engine.sfx.stop(_activeSfxId!);
    setState(() {
      _activeSfxId = null;
      _sfxPaused = false;
      if (_voiceCount > 0) _voiceCount--;
      _status = 'SFX stopped';
    });
  }

  Future<void> _stopAllSfx() async {
    await _engine.sfx.stopAll();
    setState(() {
      _activeSfxId = null;
      _sfxPaused = false;
      _voiceCount = 0;
      _status = 'All SFX stopped';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Channels / mute
  // ─────────────────────────────────────────────────────────────────────────

  void _setMasterVol(double v) {
    setState(() => _masterVol = v);
    _engine.audio.setMasterVolume(v);
  }

  void _setChannelVol(AudioChannel ch, double v) {
    setState(() {
      switch (ch) {
        case AudioChannel.music:
          _musicVol = v;
        case AudioChannel.sfx:
          _sfxVol = v;
        case AudioChannel.voice:
          _voiceVol = v;
        case AudioChannel.ambient:
          _ambientVol = v;
        default:
          break;
      }
    });
    _engine.audio.setChannelVolume(ch, v);
  }

  void _toggleMute() {
    _engine.audio.toggleMute();
    setState(() {
      _muted = _engine.audio.isMuted;
      _status = _muted ? 'Global mute ON' : 'Global mute OFF';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DSP
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _playDspSfx() async {
    _ripples.add(_SfxRipple(maxAge: 2.0));
    final effects = [
      if (_dspReverb)
        AudioEffect.reverb(roomSize: 0.75, damping: 0.5, wetLevel: 0.4),
      if (_dspLowpass) AudioEffect.lowpass(frequency: 800),
      if (_dspHighpass) AudioEffect.highpass(frequency: 200),
      if (_dspDelay) AudioEffect.delay(delayMs: 250, feedback: 0.35, mix: 0.3),
      if (_dspEq) AudioEffect.eq(frequency: 1000, gain: 4, q: 1.5),
    ];
    final desc = effects.isEmpty
        ? 'no effects'
        : effects.map((e) => e.type.name).join(', ');
    try {
      await _engine.sfx.play('assets/audio/test_sfx.wav', effects: effects);
    } catch (_) {}
    setState(() => _status = 'SFX with: $desc');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Spatial 3D
  // ─────────────────────────────────────────────────────────────────────────

  /// The AudioSystem DemoEngine.reset added (DefaultSystem.audio).
  AudioSystem? get _audioSystem => _world.getSystem<AudioSystem>();

  /// Asks every 3-D source to [request] (`AudioRequests`): carried out by
  /// the AudioSystem at its next update.
  void _spatialRequest(AudioRequest request) {
    for (final s in _sources) {
      final audio = s.audio;
      if (audio == null) continue;
      switch (request) {
        case AudioRequest.play:
          audio.play();
        case AudioRequest.pause:
          audio.pause();
        case AudioRequest.resume:
          audio.resume();
        case AudioRequest.stop:
          audio.stop();
      }
    }
    setState(() {
      switch (request) {
        case AudioRequest.play:
          _spatialPlaying = true;
          _spatialPaused = false;
        case AudioRequest.pause:
          _spatialPaused = true;
        case AudioRequest.resume:
          _spatialPaused = false;
        case AudioRequest.stop:
          _spatialPlaying = false;
          _spatialPaused = false;
      }
      _status = 'source.${request.name}() on 3 AudioSourceComponents';
    });
  }

  /// Applies the sliders to every source: changes on a playing 3-D source
  /// are heard at once (AudioSystem sends them with the next placement).
  void _setSpatial(VoidCallback change) {
    setState(change);
    for (final s in _sources) {
      s.audio
        ?..minDistance = _minDistance
        ..maxDistance = _maxDistance
        ..rolloff = _rolloff
        ..dopplerLevel = _doppler
        ..farCutoff = _farCutoff ? 600 : 0;
    }
    setState(
      () => _status =
          'rolloff:${_rolloff.name}  min:${_minDistance.round()}  max:${_maxDistance.round()}  doppler:${_doppler.toStringAsFixed(2)}  farCutoff:${_farCutoff ? 600 : 0} Hz',
    );
  }

  void _toggleListenerAtCamera() {
    setState(() {
      _listenerAtCamera = !_listenerAtCamera;
      _listener?.getComponent<AudioListenerComponent>()?.atCamera =
          _listenerAtCamera;
      _status = _listenerAtCamera
          ? 'AudioListenerComponent.atCamera = true — hears from the camera'
          : 'AudioListenerComponent.atCamera = false — hears from its entity';
    });
  }

  void _turnListener() {
    final t = _listener?.getComponent<TransformComponent>();
    if (t == null) return;
    t.angle = (t.angle + math.pi / 2) % (math.pi * 2);
    setState(
      () => _status =
          'Listener angle ${(t.angle * 180 / math.pi).round()}° — its rotation turns left/right',
    );
  }

  void _moveListener(Offset local) {
    final t = _listener?.getComponent<TransformComponent>();
    if (t == null) return;
    final w = _engine.cameraSystem.mainCamera.screenToWorld(local);
    t.position.setValues(w.dx, w.dy, 0);
  }

  /// A placed one-shot near the listener: it stays where it was asked for.
  void _spatialOneShot() {
    final l = _listener?.getComponent<TransformComponent>()?.position;
    final a = _rng.nextDouble() * math.pi * 2;
    final d = 40 + _rng.nextDouble() * (_maxDistance * 0.8);
    final at = Offset(
      (l?.x ?? 0) + math.cos(a) * d,
      (l?.y ?? 0) + math.sin(a) * d,
    );
    _audioSystem?.playOneShot(
      _sfxClip,
      pitch: 1.2,
      position: Vector3(at.dx, at.dy, 0),
      spatial: AudioSpatial(
        minDistance: _minDistance,
        maxDistance: math.max(_maxDistance, _minDistance),
        rolloff: _rolloff,
        farCutoff: _farCutoff ? 600 : 0,
      ),
    );
    setState(() {
      _ripples.add(_SfxRipple(maxAge: 1.2, at: at));
      _status =
          'playOneShot(position: (${at.dx.round()}, ${at.dy.round()}), spatial: …)';
    });
  }

  /// How the listener hears each source right now, for the canvas labels —
  /// the same [AudioSpatial.mix] the audio engine runs.
  List<_SourceView> _sourceViews() {
    final listener = _engine.audio.listener;
    final speed = _engine.audio.speedOfSound;
    return [
      for (final s in _sources)
        if (s.audio case final audio?)
          _SourceView(
            s.pos,
            s.color,
            s.label,
            audio.spatial.mix(
              listener: listener,
              position: Audio3DPosition(s.pos.dx, s.pos.dy, 0),
              velocity: Audio3DPosition(s.velocity.dx, s.velocity.dy, 0),
              speedOfSound: speed,
            ),
            audio.handle != null,
          ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ECS
  // ─────────────────────────────────────────────────────────────────────────

  void _flash(int i) {
    _ecsRows[i]
      ..flash = true
      ..flashAge = 0;
  }

  void _triggerEcsPlay(int i) {
    final row = _ecsRows[i];
    _flash(i);
    final target = row.target;
    if (target == null) {
      // The Coin: nothing to control afterwards, so no component.
      _audioSystem?.playOneShot(_sfxClip, pitch: 1.3, volume: 0.9);
      _ripples.add(_SfxRipple());
      setState(() => _status = "playOneShot('test_sfx.wav', pitch: 1.3)");
      return;
    }
    target.play();
    setState(
      () => _status =
          '${row.entity}: ${target.runtimeType}.play() — from the start',
    );
  }

  void _triggerEcsRequest(int i, AudioRequest request) {
    final row = _ecsRows[i];
    final target = row.target;
    if (target == null) return;
    _flash(i);
    switch (request) {
      case AudioRequest.pause:
        target.pause();
      case AudioRequest.resume:
        target.resume();
      case AudioRequest.stop:
        target.stop();
      case AudioRequest.play:
        target.play();
    }
    setState(
      () => _status = '${row.entity}: ${target.runtimeType}.${request.name}()',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Voice pool
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _spawnVoice() async {
    _ripples.add(_SfxRipple(maxAge: 0.9));
    try {
      await _engine.sfx.play('assets/audio/test_sfx.wav');
    } catch (_) {}
    setState(() {
      _voiceCount = (_voiceCount + 1).clamp(0, _voiceMax);
      _status = 'Voice spawned — $_voiceCount/$_voiceMax active';
    });
  }

  Future<void> _spawnTenVoices() async {
    for (int i = 0; i < 10; i++) {
      await _spawnVoice();
    }
  }

  Future<void> _stopAllVoices() async {
    await _engine.audio.stopAllSfx();
    setState(() {
      _voiceCount = 0;
      _status = 'Pool cleared — stopAllSfx()';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Streaming
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openStream() async {
    _stream?.dispose();
    _stream = AudioStream(
      path: 'assets/audio/test_music.mp3',
      channel: AudioChannel.music,
    );
    try {
      await _stream!.open(_engine.audio.backend);
    } catch (_) {}
    setState(() {
      _streamOpen = true;
      _streamPlaying = false;
      _streamPaused = false;
      _status = 'Stream opened  (stream:true → chunked decode)';
    });
  }

  Future<void> _playStream() async {
    if (!_streamOpen) await _openStream();
    try {
      await _stream!.play(volume: _streamVol, loop: true);
    } catch (_) {}
    setState(() {
      _streamPlaying = true;
      _streamPaused = false;
      _status = 'Stream playing  vol:${(_streamVol * 100).round()}%  loop:true';
    });
  }

  Future<void> _pauseStream() async {
    await _stream?.pause();
    setState(() {
      _streamPaused = true;
      _status = 'Stream paused';
    });
  }

  Future<void> _resumeStream() async {
    await _stream?.resume();
    setState(() {
      _streamPaused = false;
      _status = 'Stream resumed';
    });
  }

  Future<void> _stopStream() async {
    await _stream?.stop();
    setState(() {
      _streamPlaying = false;
      _streamPaused = false;
      _status = 'Stream stopped';
    });
  }

  Future<void> _fadeOutStream() async {
    await _stream?.fade(0.0, const Duration(seconds: 2));
    setState(() => _status = 'Stream fading to 0  over 2 s');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
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
              const Flexible(
                child: Text(
                  'AudioEngine  ·  AudioSystem  ·  MusicManager  ·  SoundEffectManager  ·  AudioStream',
                  style: TextStyle(color: Color(0xFF29B6F6), fontSize: 10),
                  overflow: TextOverflow.ellipsis,
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
            _audioStatsLine,
            style: TextStyle(
              color: _demo.accentColor.withValues(alpha: 0.85),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _status,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    // The GameWidget ticks the shared engine — without it on screen nothing
    // runs the AudioSystem or the audio engine. The Spatial demo shows
    // the world it draws; the other demos paint over it.
    final spatial = _demo == _Demo.spatial3d;
    final painter = CustomPaint(
      painter: _AudioCanvasPainter(
        demo: _demo,
        camera: _engine.cameraSystem.mainCamera,
        hearAt: Offset(
          _engine.audio.listener.position.x,
          _engine.audio.listener.position.y,
        ),
        hearRight: _listenerRight(),
        sourceViews: spatial ? _sourceViews() : const [],
        minDistance: _minDistance,
        maxDistance: _maxDistance,
        atCamera: _listenerAtCamera,
        elapsed: _elapsed,
          accentColor: _demo.accentColor,
          musicPlaying: _musicPlaying,
          musicPaused: _musicPaused,
          ripples: _ripples,
          masterVol: _masterVol,
          musicVol: _musicVol,
          sfxVol: _sfxVol,
          voiceVol: _voiceVol,
          ambientVol: _ambientVol,
          isMuted: _muted,
          dspReverb: _dspReverb,
          dspLowpass: _dspLowpass,
          dspHighpass: _dspHighpass,
          dspDelay: _dspDelay,
          dspEq: _dspEq,
          ecsRows: _ecsRows,
          voiceCount: _voiceCount,
          voiceMax: _voiceMax,
        streamOpen: _streamOpen,
        streamPlaying: _streamPlaying,
        streamPaused: _streamPaused,
        streamVol: _streamVol,
      ),
      child: const SizedBox.expand(),
    );
    return Container(
      color: const Color(0xFF060D18),
      child: GameWidget(
        engine: _engine,
        showFPS: spatial,
        overlay: spatial
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (d) => _moveListener(d.localPosition),
                onPanUpdate: (d) => _moveListener(d.localPosition),
                child: painter,
              )
            : painter,
      ),
    );
  }

  /// The listener's right ear direction (forward × up), from what the
  /// AudioSystem last sent — turns with the listener entity's rotation.
  Offset _listenerRight() {
    final l = _engine.audio.listener;
    final f = l.forward, u = l.up;
    final rx = f.y * u.z - f.z * u.y;
    final ry = f.z * u.x - f.x * u.z;
    final len = math.sqrt(rx * rx + ry * ry);
    return len < 1e-9 ? const Offset(1, 0) : Offset(rx / len, ry / len);
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
                  onSelected: (_) => _selectDemo(d),
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

  Widget _buildDemoControls() => switch (_demo) {
    _Demo.bgm => _buildBgmControls(),
    _Demo.sfx => _buildSfxControls(),
    _Demo.channels => _buildChannelsControls(),
    _Demo.dspEffects => _buildDspControls(),
    _Demo.spatial3d => _buildSpatialControls(),
    _Demo.ecsIntegration => _buildEcsControls(),
    _Demo.voicePool => _buildVoicePoolControls(),
    _Demo.streaming => _buildStreamingControls(),
  };

  // ── BGM ───────────────────────────────────────────────────────────────────
  Widget _buildBgmControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton(
          '▶ Play',
          _Demo.bgm.accentColor,
          !_musicPlaying || _musicPaused ? _playMusic : null,
        ),
        _actionButton(
          '⏸ Pause',
          _Demo.bgm.accentColor,
          _musicPlaying && !_musicPaused ? _pauseMusic : null,
        ),
        _actionButton(
          '⏵ Resume',
          _Demo.bgm.accentColor,
          _musicPaused ? _resumeMusic : null,
        ),
        _actionButton(
          '⏹ Stop',
          _Demo.bgm.accentColor,
          _musicPlaying ? _stopMusic : null,
        ),
        const SizedBox(width: 6),
        const Text(
          'vol:',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        SizedBox(
          width: 110,
          child: _compactSlider(
            _musicVol,
            (v) => _setChannelVol(AudioChannel.music, v),
            _Demo.bgm.accentColor,
          ),
        ),
      ],
    );
  }

  // ── SFX ───────────────────────────────────────────────────────────────────
  Widget _buildSfxControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _actionButton('▶ Play SFX', _Demo.sfx.accentColor, _playSfx),
            _actionButton(
              '⏸ Pause',
              _Demo.sfx.accentColor,
              _activeSfxId != null && !_sfxPaused ? _pauseSfx : null,
            ),
            _actionButton(
              '⏵ Resume',
              _Demo.sfx.accentColor,
              _sfxPaused ? _resumeSfx : null,
            ),
            _actionButton(
              '⏹ Stop',
              _Demo.sfx.accentColor,
              _activeSfxId != null ? _stopSfx : null,
            ),
            _actionButton('⏹⏹ Stop All', const Color(0xFFFF5252), _stopAllSfx),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _sliderRow(
              'Pitch',
              _sfxPitch,
              0.25,
              4.0,
              (v) => setState(() => _sfxPitch = v),
            ),
            const SizedBox(width: 12),
            _sliderRow(
              'Speed',
              _sfxSpeed,
              0.25,
              4.0,
              (v) => setState(() => _sfxSpeed = v),
            ),
            const SizedBox(width: 12),
            _sliderRow(
              'Pan',
              _sfxPan,
              -1.0,
              1.0,
              (v) => setState(() => _sfxPan = v),
            ),
          ],
        ),
      ],
    );
  }

  // ── Channels ──────────────────────────────────────────────────────────────
  Widget _buildChannelsControls() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _namedSlider('Master', _masterVol, Colors.white, _setMasterVol),
        _namedSlider(
          'Music',
          _musicVol,
          _Demo.bgm.accentColor,
          (v) => _setChannelVol(AudioChannel.music, v),
        ),
        _namedSlider(
          'SFX',
          _sfxVol,
          _Demo.sfx.accentColor,
          (v) => _setChannelVol(AudioChannel.sfx, v),
        ),
        _namedSlider(
          'Voice',
          _voiceVol,
          _Demo.dspEffects.accentColor,
          (v) => _setChannelVol(AudioChannel.voice, v),
        ),
        _namedSlider(
          'Ambient',
          _ambientVol,
          _Demo.channels.accentColor,
          (v) => _setChannelVol(AudioChannel.ambient, v),
        ),
        _actionButton(
          _muted ? '🔊 Unmute' : '🔇 Mute',
          _muted ? const Color(0xFFFF5252) : Colors.white38,
          _toggleMute,
        ),
      ],
    );
  }

  // ── DSP ───────────────────────────────────────────────────────────────────
  Widget _buildDspControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _toggleChip(
          'Reverb',
          _dspReverb,
          (v) => setState(() => _dspReverb = v),
          _Demo.dspEffects.accentColor,
        ),
        _toggleChip(
          'Lowpass',
          _dspLowpass,
          (v) => setState(() => _dspLowpass = v),
          _Demo.dspEffects.accentColor,
        ),
        _toggleChip(
          'Highpass',
          _dspHighpass,
          (v) => setState(() => _dspHighpass = v),
          _Demo.dspEffects.accentColor,
        ),
        _toggleChip(
          'Delay',
          _dspDelay,
          (v) => setState(() => _dspDelay = v),
          _Demo.dspEffects.accentColor,
        ),
        _toggleChip(
          'EQ +4dB',
          _dspEq,
          (v) => setState(() => _dspEq = v),
          _Demo.dspEffects.accentColor,
        ),
        const SizedBox(width: 4),
        _actionButton(
          '▶ Play with Effects',
          _Demo.dspEffects.accentColor,
          _playDspSfx,
        ),
      ],
    );
  }

  // ── Spatial ───────────────────────────────────────────────────────────────
  Widget _buildSpatialControls() {
    final c = _Demo.spatial3d.accentColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _actionButton(
              '▶ Play',
              c,
              !_spatialPlaying ? () => _spatialRequest(AudioRequest.play) : null,
            ),
            _actionButton(
              '⏸ Pause',
              c,
              _spatialPlaying && !_spatialPaused
                  ? () => _spatialRequest(AudioRequest.pause)
                  : null,
            ),
            _actionButton(
              '⏵ Resume',
              c,
              _spatialPaused ? () => _spatialRequest(AudioRequest.resume) : null,
            ),
            _actionButton(
              '⏹ Stop',
              const Color(0xFFFF5252),
              _spatialPlaying ? () => _spatialRequest(AudioRequest.stop) : null,
            ),
            _actionButton('💥 One-shot', c, _spatialOneShot),
            _actionButton('↻ Turn listener', c, _turnListener),
            _toggleChip(
              'atCamera',
              _listenerAtCamera,
              (_) => _toggleListenerAtCamera(),
              c,
            ),
            const SizedBox(width: 4),
            for (final r in AudioRolloff.values)
              _toggleChip(
                r.name,
                _rolloff == r,
                (_) => _setSpatial(() => _rolloff = r),
                c,
              ),
            _toggleChip(
              'farCutoff 600 Hz',
              _farCutoff,
              (v) => _setSpatial(() => _farCutoff = v),
              c,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            _sliderRow(
              'min',
              _minDistance,
              10,
              120,
              (v) => _setSpatial(() => _minDistance = v),
              digits: 0,
            ),
            _sliderRow(
              'max',
              _maxDistance,
              150,
              500,
              (v) => _setSpatial(() => _maxDistance = v),
              digits: 0,
            ),
            _sliderRow(
              'doppler',
              _doppler,
              0,
              1,
              (v) => _setSpatial(() => _doppler = v),
            ),
          ],
        ),
      ],
    );
  }

  // ── ECS ───────────────────────────────────────────────────────────────────
  Widget _buildEcsControls() {
    final c = _Demo.ecsIntegration.accentColor;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (int i = 0; i < _ecsRows.length; i++) ...[
          _actionButton(
            '▶ ${_ecsRows[i].entity}',
            c,
            () => _triggerEcsPlay(i),
          ),
          if (_ecsRows[i].target != null) ...[
            _actionButton(
              '⏸',
              c,
              () => _triggerEcsRequest(i, AudioRequest.pause),
            ),
            _actionButton(
              '⏵',
              c,
              () => _triggerEcsRequest(i, AudioRequest.resume),
            ),
            _actionButton(
              '⏹',
              const Color(0xFFFF5252),
              () => _triggerEcsRequest(i, AudioRequest.stop),
            ),
          ],
          if (i < _ecsRows.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  // ── Voice Pool ────────────────────────────────────────────────────────────
  Widget _buildVoicePoolControls() {
    return Row(
      children: [
        _actionButton('+ Spawn', _Demo.voicePool.accentColor, _spawnVoice),
        const SizedBox(width: 6),
        _actionButton(
          '+ Spawn ×10',
          _Demo.voicePool.accentColor,
          _spawnTenVoices,
        ),
        const SizedBox(width: 6),
        _actionButton('⏹ Stop All', const Color(0xFFFF5252), _stopAllVoices),
        const SizedBox(width: 12),
        const Text(
          'capacity: 64  ·  slot 0 = protected music',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  // ── Streaming ─────────────────────────────────────────────────────────────
  Widget _buildStreamingControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton(
          'Open',
          _Demo.streaming.accentColor,
          !_streamOpen ? _openStream : null,
        ),
        _actionButton(
          '▶ Play',
          _Demo.streaming.accentColor,
          !_streamPlaying || _streamPaused ? _playStream : null,
        ),
        _actionButton(
          '⏸ Pause',
          _Demo.streaming.accentColor,
          _streamPlaying && !_streamPaused ? _pauseStream : null,
        ),
        _actionButton(
          '⏵ Resume',
          _Demo.streaming.accentColor,
          _streamPaused ? _resumeStream : null,
        ),
        _actionButton(
          '⏹ Stop',
          _Demo.streaming.accentColor,
          _streamPlaying ? _stopStream : null,
        ),
        _actionButton(
          'Fade Out',
          _Demo.streaming.accentColor,
          _streamPlaying ? _fadeOutStream : null,
        ),
        const SizedBox(width: 4),
        const Text(
          'vol:',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        SizedBox(
          width: 90,
          child: _compactSlider(_streamVol, (v) {
            setState(() => _streamVol = v);
            _stream?.setVolume(v);
          }, _Demo.streaming.accentColor),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared widget helpers
  // ─────────────────────────────────────────────────────────────────────────

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

  Widget _compactSlider(
    double value,
    ValueChanged<double> onChanged,
    Color color,
  ) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        activeTrackColor: color,
        inactiveTrackColor: color.withValues(alpha: 0.2),
        thumbColor: color,
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
    );
  }

  Widget _namedSlider(
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return SizedBox(
      width: 148,
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
          Expanded(child: _compactSlider(value, onChanged, color)),
          SizedBox(
            width: 28,
            child: Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int digits = 2,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 90,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: _demo.accentColor,
              inactiveTrackColor: _demo.accentColor.withValues(alpha: 0.2),
              thumbColor: _demo.accentColor,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            value.toStringAsFixed(digits),
            style: TextStyle(
              color: _demo.accentColor,
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _toggleChip(
    String label,
    bool enabled,
    ValueChanged<bool> onChanged,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!enabled),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.2)
              : const Color(0xFF0E1A2A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.7)
                : const Color(0xFF1E2E40),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: enabled ? FontWeight.w600 : FontWeight.normal,
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
                  'just_game_engine  ·  AudioEngine API',
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
// Canvas painter
// ─────────────────────────────────────────────────────────────────────────────

class _AudioCanvasPainter extends CustomPainter {
  final _Demo demo;
  final Camera camera;
  final Offset hearAt;
  final Offset hearRight;
  final List<_SourceView> sourceViews;
  final double minDistance;
  final double maxDistance;
  final bool atCamera;
  final double elapsed;
  final Color accentColor;
  final bool musicPlaying;
  final bool musicPaused;
  final List<_SfxRipple> ripples;
  final double masterVol;
  final double musicVol;
  final double sfxVol;
  final double voiceVol;
  final double ambientVol;
  final bool isMuted;
  final bool dspReverb;
  final bool dspLowpass;
  final bool dspHighpass;
  final bool dspDelay;
  final bool dspEq;
  final List<_EcsRow> ecsRows;
  final int voiceCount;
  final int voiceMax;
  final bool streamOpen;
  final bool streamPlaying;
  final bool streamPaused;
  final double streamVol;

  const _AudioCanvasPainter({
    required this.demo,
    required this.camera,
    required this.hearAt,
    required this.hearRight,
    required this.sourceViews,
    required this.minDistance,
    required this.maxDistance,
    required this.atCamera,
    required this.elapsed,
    required this.accentColor,
    required this.musicPlaying,
    required this.musicPaused,
    required this.ripples,
    required this.masterVol,
    required this.musicVol,
    required this.sfxVol,
    required this.voiceVol,
    required this.ambientVol,
    required this.isMuted,
    required this.dspReverb,
    required this.dspLowpass,
    required this.dspHighpass,
    required this.dspDelay,
    required this.dspEq,
    required this.ecsRows,
    required this.voiceCount,
    required this.voiceMax,
    required this.streamOpen,
    required this.streamPlaying,
    required this.streamPaused,
    required this.streamVol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (demo == _Demo.spatial3d) {
      // Over the world the GameWidget drew: grid lines only.
      _grid(canvas, size);
    } else {
      _background(canvas, size);
    }
    switch (demo) {
      case _Demo.bgm:
        _paintBgm(canvas, size);
      case _Demo.sfx:
        _paintSfx(canvas, size);
      case _Demo.channels:
        _paintChannels(canvas, size);
      case _Demo.dspEffects:
        _paintDsp(canvas, size);
      case _Demo.spatial3d:
        _paintSpatial(canvas, size);
      case _Demo.ecsIntegration:
        _paintEcs(canvas, size);
      case _Demo.voicePool:
        _paintVoicePool(canvas, size);
      case _Demo.streaming:
        _paintStreaming(canvas, size);
    }
  }

  void _background(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF060D18),
    );
    _grid(canvas, size);
  }

  void _grid(Canvas canvas, Size size) {
    final gp = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
  }

  // ── BGM: animated equalizer bars ─────────────────────────────────────────

  void _paintBgm(Canvas canvas, Size size) {
    const barCount = 28;
    const padX = 24.0;
    final barW = (size.width - padX * 2) / barCount;
    final cy = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final phase = i / barCount;
      double norm;
      if (musicPlaying && !musicPaused) {
        norm =
            0.12 +
            0.38 *
                (0.5 + 0.5 * math.sin(elapsed * 3.6 + phase * math.pi * 2.5)) +
            0.22 *
                (0.5 + 0.5 * math.sin(elapsed * 7.2 + phase * math.pi * 5.1)) +
            0.08 *
                (0.5 + 0.5 * math.sin(elapsed * 13.0 + phase * math.pi * 1.7));
      } else if (musicPaused) {
        norm = 0.06 + 0.22 * math.sin(phase * math.pi * 2.5).abs();
      } else {
        norm = 0.02;
      }
      norm = norm.clamp(0.0, 1.0);
      final barH = norm * size.height * 0.72;
      final x = padX + i * barW;
      final color = musicPlaying && !musicPaused
          ? Color.lerp(accentColor.withValues(alpha: 0.3), accentColor, norm)!
          : musicPaused
          ? accentColor.withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.06);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, cy - barH / 2, barW - 3, barH),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );
    }
    final stateLabel = musicPlaying && !musicPaused
        ? '▶  PLAYING'
        : musicPaused
        ? '⏸  PAUSED'
        : '■  STOPPED';
    _ct(
      canvas,
      stateLabel,
      Offset(size.width / 2, size.height * 0.88),
      accentColor.withValues(alpha: 0.6),
      10,
    );
  }

  // ── SFX: expanding ripple rings ───────────────────────────────────────────

  void _paintSfx(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(size.width, size.height) * 0.44;

    for (final r in ripples) {
      canvas.drawCircle(
        Offset(cx, cy),
        14 + r.t * maxR,
        Paint()
          ..color = accentColor.withValues(alpha: (1 - r.t) * 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - r.t * 0.4),
      );
    }
    final active = ripples.isNotEmpty;
    canvas.drawCircle(
      Offset(cx, cy),
      26,
      Paint()
        ..color = accentColor.withValues(alpha: active ? 0.18 : 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      18 + (active ? math.sin(elapsed * 14) * 3 : 0),
      Paint()..color = accentColor.withValues(alpha: active ? 0.9 : 0.45),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      7,
      Paint()..color = const Color(0xFF060D18),
    );
  }

  // ── Channels: horizontal level meters ────────────────────────────────────

  void _paintChannels(Canvas canvas, Size size) {
    final labels = ['Master', 'Music', 'SFX', 'Voice', 'Ambient'];
    final colors = [
      Colors.white,
      const Color(0xFF66BB6A),
      const Color(0xFFFFCA28),
      const Color(0xFFAB47BC),
      const Color(0xFF29B6F6),
    ];
    final vols = [masterVol, musicVol, sfxVol, voiceVol, ambientVol];
    const labelW = 52.0;
    const valW = 36.0;
    const padX = 16.0;
    const padY = 10.0;
    final barAreaW = size.width - labelW - valW - padX * 3;
    final rowH = (size.height - padY * (labels.length + 1)) / labels.length;

    for (int i = 0; i < labels.length; i++) {
      final vol = vols[i];
      final color = colors[i];
      final y = padY + i * (rowH + padY);
      final barY = y + rowH * 0.3;
      final barH = rowH * 0.4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(labelW + padX, barY, barAreaW, barH),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.06),
      );
      if (vol > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(labelW + padX, barY, barAreaW * vol, barH),
            const Radius.circular(4),
          ),
          Paint()..color = color.withValues(alpha: isMuted ? 0.2 : 0.7),
        );
      }
      for (int t = 1; t < 10; t++) {
        final tx = labelW + padX + barAreaW * (t / 10);
        canvas.drawLine(
          Offset(tx, barY),
          Offset(tx, barY + barH),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..strokeWidth = 1,
        );
      }
      _tl(
        canvas,
        labels[i],
        Offset(padX, y + rowH * 0.5 - 5),
        Colors.white60,
        10,
      );
      _tl(
        canvas,
        '${(vol * 100).round()}%',
        Offset(labelW + padX + barAreaW + 6, y + rowH * 0.5 - 5),
        color.withValues(alpha: isMuted ? 0.35 : 0.9),
        10,
      );
    }
    if (isMuted) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black.withValues(alpha: 0.3),
      );
      _ct(
        canvas,
        '🔇  MUTED',
        Offset(size.width / 2, size.height / 2),
        const Color(0xFFFF5252).withValues(alpha: 0.75),
        14,
      );
    }
  }

  // ── DSP: frequency-response curve ────────────────────────────────────────

  void _paintDsp(Canvas canvas, Size size) {
    final cy = size.height / 2;
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 1,
    );

    const n = 150;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final t = i / (n - 1);
      final freq = 20.0 * math.pow(1000.0, t);
      double gain = 0;
      if (dspLowpass) {
        const fc = 800.0;
        if (freq > fc) gain += -18 * math.log(freq / fc) / math.ln10;
      }
      if (dspHighpass) {
        const fc = 200.0;
        if (freq < fc) gain += -18 * math.log(fc / freq) / math.ln10;
      }
      if (dspEq) {
        const fc = 1000.0;
        final d = (freq - fc) / 500.0;
        gain += 6 * math.exp(-d * d * 2);
      }
      if (dspDelay) {
        gain += -2.5 * (0.5 + 0.5 * math.sin(freq / 220 * math.pi * 2));
      }
      if (dspReverb) gain += -0.0004 * (freq / 100.0);

      final y = (cy - (gain.clamp(-30.0, 18.0) / 30) * size.height * 0.38)
          .clamp(8.0, size.height - 8.0);
      if (i == 0) {
        path.moveTo(t * size.width, y);
      } else {
        path.lineTo(t * size.width, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, cy)
      ..lineTo(0, cy)
      ..close();
    canvas.drawPath(fill, Paint()..color = accentColor.withValues(alpha: 0.07));
    canvas.drawPath(
      path,
      Paint()
        ..color = accentColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (!dspReverb && !dspLowpass && !dspHighpass && !dspDelay && !dspEq) {
      _ct(
        canvas,
        'Enable effects above to see the frequency-response curve',
        Offset(size.width / 2, size.height * 0.82),
        Colors.white24,
        10,
      );
    }
  }

  // ── Spatial 3D: top-down view ─────────────────────────────────────────────

  /// Over the entities the engine draws (listener and sources): the
  /// listener's hearing range, a line per source faded by its gain, and how
  /// each source is heard — gain, pan, doppler pitch, low-pass.
  void _paintSpatial(Canvas canvas, Size size) {
    final zoom = camera.zoom;
    final ear = camera.worldToScreen(hearAt);

    // minDistance (full volume) and maxDistance (silent) around the ear.
    canvas.drawCircle(
      ear,
      minDistance * zoom,
      Paint()..color = accentColor.withValues(alpha: 0.06),
    );
    canvas.drawCircle(
      ear,
      minDistance * zoom,
      Paint()
        ..color = accentColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      ear,
      maxDistance * zoom,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _tl(
      canvas,
      'min ${minDistance.round()}',
      ear + Offset(minDistance * zoom + 3, -5),
      accentColor.withValues(alpha: 0.55),
      8,
    );
    _tl(
      canvas,
      'max ${maxDistance.round()}',
      ear + Offset(maxDistance * zoom + 3, -5),
      Colors.white.withValues(alpha: 0.3),
      8,
    );

    for (int i = 0; i < sourceViews.length; i++) {
      final src = sourceViews[i];
      final s = camera.worldToScreen(src.pos);
      final gain = src.mix.gain;
      if (src.playing) {
        final ringT = (elapsed * 1.5 + i * 0.4) % 1.0;
        canvas.drawCircle(
          s,
          12 + ringT * 40 * (0.3 + gain),
          Paint()
            ..color = src.color.withValues(alpha: (1 - ringT) * 0.45 * gain)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
      }
      canvas.drawLine(
        s,
        ear,
        Paint()
          ..color = src.color.withValues(alpha: 0.06 + gain * 0.4)
          ..strokeWidth = 1,
      );
      final pan = src.mix.pan;
      final lp = src.mix.lowPass;
      _tl(
        canvas,
        '${src.label}  ${(gain * 100).round()}%  '
        'pan ${pan >= 0 ? '+' : ''}${pan.toStringAsFixed(2)}',
        s + const Offset(-24, 12),
        src.color.withValues(alpha: src.playing ? 0.9 : 0.5),
        9,
      );
      _tl(
        canvas,
        '×${src.mix.pitch.toStringAsFixed(2)}'
        '${lp > 0 ? '  lp ${(lp / 1000).toStringAsFixed(1)}k' : ''}',
        s + const Offset(-24, 24),
        src.color.withValues(alpha: src.playing ? 0.6 : 0.35),
        8,
      );
    }

    // Placed one-shots.
    for (final r in ripples) {
      final at = r.at;
      if (at == null) continue;
      canvas.drawCircle(
        camera.worldToScreen(at),
        6 + r.t * 46,
        Paint()
          ..color = const Color(0xFFFFCA28).withValues(alpha: (1 - r.t) * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // The ears: left and right of where the AudioSystem says the listener
    // is and faces.
    _ct(canvas, 'L', ear - hearRight * 22, Colors.white60, 9);
    _ct(canvas, 'R', ear + hearRight * 22, Colors.white60, 9);
    _ct(
      canvas,
      atCamera ? 'LISTENER (at camera)' : 'LISTENER',
      ear + const Offset(0, 24),
      Colors.white.withValues(alpha: 0.45),
      8,
    );
    _ct(
      canvas,
      'drag to move the AudioListenerComponent',
      Offset(size.width / 2, size.height - 12),
      Colors.white.withValues(alpha: 0.25),
      9,
    );
  }

  // ── ECS: entity component boxes ───────────────────────────────────────────

  void _paintEcs(Canvas canvas, Size size) {
    const gap = 14.0;
    final count = ecsRows.length;
    final boxW = (size.width - gap * (count + 1)) / count;
    const padY = 14.0;
    final boxH = size.height - padY * 2;

    for (int i = 0; i < count; i++) {
      final row = ecsRows[i];
      final x = gap + i * (boxW + gap);
      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, padY, boxW, boxH),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..color = (row.flash ? accentColor : Colors.white).withValues(
            alpha: row.flash ? 0.14 : 0.05,
          ),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..color = (row.flash ? accentColor : Colors.white).withValues(
            alpha: row.flash ? 0.75 : 0.14,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = row.flash ? 1.8 : 1.0,
      );
      _tlb(
        canvas,
        row.entity,
        Offset(x + 8, padY + 9),
        row.flash ? accentColor : Colors.white.withValues(alpha: 0.75),
        10,
      );
      for (int j = 0; j < row.tags.length; j++) {
        final tag = row.tags[j];
        final ty = padY + 30 + j * 28.0;
        final chip = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 6, ty, boxW - 12, 20),
          const Radius.circular(4),
        );
        canvas.drawRRect(
          chip,
          Paint()..color = tag.color.withValues(alpha: 0.14),
        );
        canvas.drawRRect(
          chip,
          Paint()
            ..color = tag.color.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        _tl(
          canvas,
          tag.text,
          Offset(x + 10, ty + 4),
          tag.color.withValues(alpha: 0.9),
          8,
        );
      }
      // Read back from the component every frame.
      if (row.state.isNotEmpty) {
        _tl(
          canvas,
          row.state,
          Offset(x + 8, padY + boxH - 18),
          Colors.white.withValues(alpha: 0.55),
          8,
        );
      }
    }
  }

  // ── Voice pool: 8×8 slot grid ─────────────────────────────────────────────

  void _paintVoicePool(Canvas canvas, Size size) {
    const cols = 8;
    const rows = 8;
    const gap = 5.0;
    final cell = math.min(
      (size.width - 40.0 - gap * (cols - 1)) / cols,
      (size.height - 36.0 - gap * (rows - 1)) / rows,
    );
    final gw = cols * cell + (cols - 1) * gap;
    final gh = rows * cell + (rows - 1) * gap;
    final sx = (size.width - gw) / 2;
    final sy = (size.height - gh) / 2;

    for (int i = 0; i < cols * rows; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final x = sx + col * (cell + gap);
      final y = sy + row * (cell + gap);
      final color = i == 0 && voiceCount > 0
          ? const Color(0xFFFFD700)
          : i < voiceCount
          ? accentColor
          : Colors.white.withValues(alpha: 0.07);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cell, cell),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );
    }
    _tl(canvas, '■ empty', Offset(sx, sy + gh + 8), Colors.white24, 9);
    _tl(
      canvas,
      '■ active',
      Offset(sx + 52, sy + gh + 8),
      accentColor.withValues(alpha: 0.7),
      9,
    );
    _tl(
      canvas,
      '■ protected (music)',
      Offset(sx + 108, sy + gh + 8),
      const Color(0xFFFFD700).withValues(alpha: 0.7),
      9,
    );
    _ct(
      canvas,
      '$voiceCount / $voiceMax  voices',
      Offset(size.width / 2, sy - 12),
      accentColor.withValues(alpha: 0.65),
      11,
    );
  }

  // ── Streaming: buffer bar + waveform ─────────────────────────────────────

  void _paintStreaming(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const barW = 280.0;
    const barH = 10.0;
    const barOffY = -28.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW / 2, cy + barOffY, barW, barH),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );

    if (streamOpen) {
      final fill = streamPlaying
          ? (0.55 + 0.2 * (0.5 + 0.5 * math.sin(elapsed * 0.4))).clamp(0.0, 1.0)
          : 0.55;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, cy + barOffY, barW * fill, barH),
          const Radius.circular(5),
        ),
        Paint()
          ..color = accentColor.withValues(alpha: streamPaused ? 0.35 : 0.55),
      );
      _tl(
        canvas,
        'buffer ${(fill * 100).round()}%',
        Offset(cx + barW / 2 + 8, cy + barOffY),
        accentColor.withValues(alpha: 0.45),
        9,
      );
    }

    if (streamPlaying) {
      final path = Path();
      final wStart = cx - barW / 2 - 20;
      const wW = barW + 40;
      for (int i = 0; i <= 160; i++) {
        final t = i / 160;
        final env = math.sin(t * math.pi);
        final y =
            cy +
            22 +
            math.sin(t * math.pi * 20 + elapsed * 7.5) * env * 30 * streamVol +
            math.sin(t * math.pi * 8 + elapsed * 4.1) * env * 13 * streamVol;
        if (i == 0) {
          path.moveTo(wStart + t * wW, y);
        } else {
          path.lineTo(wStart + t * wW, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = accentColor.withValues(alpha: streamPaused ? 0.25 : 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }

    final state = streamPlaying && !streamPaused
        ? '▶  STREAMING'
        : streamPaused
        ? '⏸  PAUSED'
        : streamOpen
        ? '⏹  OPEN / STOPPED'
        : '○  NOT OPEN';
    _ct(
      canvas,
      state,
      Offset(cx, cy + barOffY - 18),
      accentColor.withValues(alpha: 0.6),
      11,
    );
    _ct(
      canvas,
      'AudioStream  (stream: true → chunked decode)',
      Offset(cx, size.height - 16),
      Colors.white.withValues(alpha: 0.2),
      9,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Text helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _tl(
    Canvas canvas,
    String text,
    Offset topLeft,
    Color color,
    double fontSize,
  ) {
    (TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, topLeft);
  }

  void _tlb(
    Canvas canvas,
    String text,
    Offset topLeft,
    Color color,
    double fontSize,
  ) {
    (TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, topLeft);
  }

  void _ct(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double fontSize,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _AudioCanvasPainter old) => true;
}


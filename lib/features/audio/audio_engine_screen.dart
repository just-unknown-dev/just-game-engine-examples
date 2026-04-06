import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SfxRipple {
  double age = 0;
  final double maxAge;
  _SfxRipple({this.maxAge = 1.4});
  double get t => (age / maxAge).clamp(0.0, 1.0);
  bool get dead => age >= maxAge;
  void tick(double dt) => age += dt;
}

class _Spatial3dSource {
  final double radius;
  final double angularSpeed;
  final Color color;
  final String label;
  double angle;

  _Spatial3dSource({
    required this.radius,
    required this.angularSpeed,
    required this.color,
    required this.label,
    this.angle = 0.0,
  });

  Offset get pos => Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  void tick(double dt) => angle += angularSpeed * dt;
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
      'is3d:true on AudioSourceComponent reads TransformComponent every frame and calls setVoice3DPosition. AudioListenerComponent marks the ear.',
    ecsIntegration =>
      'AudioSourceComponent for persistent sources. AudioPlayComponent triggers one-shot playback. Pause/Resume/StopComponent are fire-and-forget.',
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
          'engine.audio.stopAllSfx();',
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
      '// Mark the listener entity:\n'
          'listener.addComponent(AudioListenerComponent());\n'
          'listener.addComponent(TransformComponent(position: playerPos));\n\n'
          '// Attach a 3D source:\n'
          'source.addComponent(TransformComponent(position: emitterPos));\n'
          'source.addComponent(AudioSourceComponent(\n'
          "  clipPath: 'assets/audio/ambient.ogg',\n"
          '  loop: true,\n'
          '  is3d: true,\n'
          '  channel: AudioChannel.ambient,\n'
          '));\n'
          '// AudioSystem updates position every frame automatically.',
    ecsIntegration =>
      '// Persistent looping source:\n'
          'entity.addComponent(AudioSourceComponent(\n'
          "  clipPath: 'assets/audio/fire.ogg',\n"
          '  loop: true, volume: 0.8, pitch: 1.1,\n'
          '  effects: [AudioEffect.reverb()],\n'
          '));\n\n'
          '// One-shot trigger (auto-removes):\n'
          'entity.addComponent(AudioPlayComponent(\n'
          "  clipPath: 'assets/audio/coin.wav', pitch: 1.3,\n"
          '));\n\n'
          '// State triggers:\n'
          'entity.addComponent(AudioPauseComponent());\n'
          'entity.addComponent(AudioResumeComponent());\n'
          'entity.addComponent(AudioStopComponent());\n\n'
          '// Streaming via ECS:\n'
          'entity.addComponent(AudioStreamComponent(\n'
          "  path: 'assets/audio/bgm.mp3',\n"
          '  fadeInDuration: const Duration(seconds: 2),\n'
          '));',
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
          '// Or via ECS (hands-free):\n'
          'entity.addComponent(AudioStreamComponent(\n'
          '  path: path,\n'
          '  fadeInDuration: const Duration(seconds: 2),\n'
          '));',
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
  late final Engine _engine;
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

  // ── ECS ───────────────────────────────────────────────────────────────────
  final List<_EcsRow> _ecsRows = [];

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
    _engine = Engine();
    _ticker = createTicker(_onTick)..start();
    _initSources();
    _initEcsRows();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stream?.dispose();
    super.dispose();
  }

  void _initSources() {
    _sources
      ..add(
        _Spatial3dSource(
          radius: 95,
          angularSpeed: 0.8,
          color: const Color(0xFFFF7043),
          label: 'SFX',
          angle: 0,
        ),
      )
      ..add(
        _Spatial3dSource(
          radius: 145,
          angularSpeed: -0.5,
          color: const Color(0xFF29B6F6),
          label: 'Ambient',
          angle: math.pi * 2 / 3,
        ),
      )
      ..add(
        _Spatial3dSource(
          radius: 65,
          angularSpeed: 1.2,
          color: const Color(0xFF66BB6A),
          label: 'Voice',
          angle: math.pi * 4 / 3,
        ),
      );
  }

  void _initEcsRows() {
    _ecsRows
      ..add(
        _EcsRow('Player', [
          const _CompTag('AudioListenerComponent', Color(0xFF29B6F6)),
          const _CompTag('AudioSourceComponent', Color(0xFF66BB6A)),
        ]),
      )
      ..add(
        _EcsRow('FireEmitter', [
          const _CompTag('AudioSourceComponent  loop+3D', Color(0xFFFF7043)),
          const _CompTag('TransformComponent', Color(0xFF78909C)),
        ]),
      )
      ..add(
        _EcsRow('Coin', [
          const _CompTag('AudioPlayComponent', Color(0xFFFFCA28)),
        ]),
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
    _elapsed += dt;
    for (final s in _sources) {
      s.tick(dt);
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
    }
    _engine.audio.update();
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Audio stats line
  // ─────────────────────────────────────────────────────────────────────────

  String get _audioStatsLine {
    final musicState = _engine.music.isPlaying
        ? (_musicPaused ? '⏸ music' : '▶ music')
        : '■ music';
    final mutedStr = _muted ? '  [MUTED]' : '';
    return '$musicState  master:${(_masterVol * 100).round()}%  voices:$_voiceCount/$_voiceMax$mutedStr';
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

  void _applyListener() {
    _engine.audio.setListener3D(
      const Audio3DListener(
        position: Audio3DPosition(0, 0, 0),
        forward: Audio3DPosition(0, 0, -1),
        up: Audio3DPosition(0, 1, 0),
      ),
    );
    setState(() => _status = 'setListener3D(pos:0,0,0  fwd:0,0,-1)');
  }

  void _applySourcePositions() {
    for (final src in _sources) {
      final p = src.pos;
      if (_activeSfxId != null) {
        _engine.audio.updateSfxPosition(
          _activeSfxId!,
          Audio3DPosition(p.dx, p.dy, 0),
        );
      }
    }
    setState(() => _status = 'updateSfxPosition called for all sources');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ECS
  // ─────────────────────────────────────────────────────────────────────────

  void _triggerEcsPlay(int i) {
    _ecsRows[i].flash = true;
    _ecsRows[i].flashAge = 0;
    _ripples.add(_SfxRipple());
    setState(() => _status = 'AudioPlayComponent → ${_ecsRows[i].entity}');
  }

  void _triggerEcsPause(int i) {
    _ecsRows[i].flash = true;
    _ecsRows[i].flashAge = 0;
    setState(() => _status = 'AudioPauseComponent → ${_ecsRows[i].entity}');
  }

  void _triggerEcsStop(int i) {
    _ecsRows[i].flash = true;
    _ecsRows[i].flashAge = 0;
    setState(() => _status = 'AudioStopComponent → ${_ecsRows[i].entity}');
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
              const Text(
                'AudioEngine  ·  MusicManager  ·  SoundEffectManager  ·  AudioStream',
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
    return Container(
      color: const Color(0xFF060D18),
      child: CustomPaint(
        painter: _AudioCanvasPainter(
          demo: _demo,
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
          sources: _sources,
          ecsRows: _ecsRows,
          voiceCount: _voiceCount,
          voiceMax: _voiceMax,
          streamOpen: _streamOpen,
          streamPlaying: _streamPlaying,
          streamPaused: _streamPaused,
          streamVol: _streamVol,
        ),
        child: const SizedBox.expand(),
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
                  onSelected: (_) => setState(() => _demo = d),
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
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton(
          'Set Listener (0,0,0)',
          _Demo.spatial3d.accentColor,
          _applyListener,
        ),
        _actionButton(
          'Update Source Positions',
          _Demo.spatial3d.accentColor,
          _applySourcePositions,
        ),
        const SizedBox(width: 4),
        const Text(
          '3 sources orbit the listener  ·  volume ≈ 1 − dist/200',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  // ── ECS ───────────────────────────────────────────────────────────────────
  Widget _buildEcsControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (int i = 0; i < _ecsRows.length; i++) ...[
          _actionButton(
            '▶ ${_ecsRows[i].entity}',
            _Demo.ecsIntegration.accentColor,
            () => _triggerEcsPlay(i),
          ),
          _actionButton(
            '⏸',
            _Demo.ecsIntegration.accentColor,
            () => _triggerEcsPause(i),
          ),
          _actionButton('⏹', const Color(0xFFFF5252), () => _triggerEcsStop(i)),
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
    ValueChanged<double> onChanged,
  ) {
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
            value.toStringAsFixed(2),
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
  final List<_Spatial3dSource> sources;
  final List<_EcsRow> ecsRows;
  final int voiceCount;
  final int voiceMax;
  final bool streamOpen;
  final bool streamPlaying;
  final bool streamPaused;
  final double streamVol;

  const _AudioCanvasPainter({
    required this.demo,
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
    required this.sources,
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
    _background(canvas, size);
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
      if (dspDelay)
        gain += -2.5 * (0.5 + 0.5 * math.sin(freq / 220 * math.pi * 2));
      if (dspReverb) gain += -0.0004 * (freq / 100.0);

      final y = (cy - (gain.clamp(-30.0, 18.0) / 30) * size.height * 0.38)
          .clamp(8.0, size.height - 8.0);
      if (i == 0)
        path.moveTo(t * size.width, y);
      else
        path.lineTo(t * size.width, y);
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

  void _paintSpatial(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final sc = math.min(size.width, size.height) / 380.0;

    for (final r in [60, 120, 180]) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * sc,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.04)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }
    _tl(
      canvas,
      '180 u',
      Offset(cx + 180 * sc + 4, cy - 5),
      Colors.white.withValues(alpha: 0.15),
      8,
    );

    for (int i = 0; i < sources.length; i++) {
      final src = sources[i];
      final wp = src.pos;
      final sx = cx + wp.dx * sc;
      final sy = cy + wp.dy * sc;
      final vol = (1.0 - (wp.distance / 200.0)).clamp(0.05, 1.0);
      final ringT = (elapsed * 1.5 + i * 0.4) % 1.0;

      canvas.drawCircle(
        Offset(sx, sy),
        (12 + ringT * 52) * sc,
        Paint()
          ..color = src.color.withValues(alpha: (1 - ringT) * 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      canvas.drawCircle(
        Offset(sx, sy),
        18 * sc,
        Paint()
          ..color = src.color.withValues(alpha: vol * 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * sc),
      );
      canvas.drawLine(
        Offset(sx, sy),
        Offset(cx, cy),
        Paint()
          ..color = src.color.withValues(alpha: 0.12 + vol * 0.28)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(sx, sy), 7 * sc, Paint()..color = src.color);
      _tl(
        canvas,
        '${src.label}  ${(vol * 100).round()}%',
        Offset(sx - 22, sy + 10 * sc),
        src.color.withValues(alpha: 0.75),
        9,
      );
    }

    canvas.drawCircle(
      Offset(cx, cy),
      18 * sc,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * sc),
    );
    canvas.drawCircle(Offset(cx, cy), 11 * sc, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(cx, cy),
      4 * sc,
      Paint()..color = const Color(0xFF060D18),
    );
    _ct(
      canvas,
      'LISTENER',
      Offset(cx, cy + 18 * sc),
      Colors.white.withValues(alpha: 0.4),
      8,
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
        if (i == 0)
          path.moveTo(wStart + t * wW, y);
        else
          path.lineTo(wStart + t * wW, y);
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

import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';

class AudioEngineScreen extends StatefulWidget {
  const AudioEngineScreen({super.key});

  @override
  State<AudioEngineScreen> createState() => _AudioEngineScreenState();
}

class _AudioEngineScreenState extends State<AudioEngineScreen> {
  late final Engine _engine;

  bool _isMusicPlaying = false;
  double _masterVolume = 1.0;
  String _statusMessage = 'System ready.';

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _initializeAudio();
  }

  @override
  void dispose() {
    _engine.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Engine System',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Powered by flutter_soloud, providing high-performance, low-latency audio mixing with support for BGM, SFX overlapping, fading, and volume channels.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),

          // Controls
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleMusic,
                      icon: Icon(
                        _isMusicPlaying ? Icons.stop : Icons.play_arrow,
                      ),
                      label: Text(_isMusicPlaying ? 'Stop BGM' : 'Play BGM'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isMusicPlaying
                            ? Colors.red.shade800
                            : Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _playSfx,
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Play SFX'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Volume Slider
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _engine.audio.isMuted
                            ? Icons.volume_off
                            : Icons.volume_up,
                      ),
                      color: Colors.white,
                      onPressed: _toggleMute,
                    ),
                    Expanded(
                      child: Slider(
                        value: _masterVolume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        activeColor: Colors.blueAccent,
                        inactiveColor: Colors.white24,
                        label: '${(_masterVolume * 100).toInt()}%',
                        onChanged: _updateVolume,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Status Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audio Status:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeAudio() async {
    // AudioEngine must be initialized before use
    await _engine.audio.initialize();
  }

  void _toggleMusic() async {
    // In a real scenario we'd use a real asset path 'assets/audio/bgm.mp3'
    // Here we'll simulate the intent and catch the expected load error
    if (_isMusicPlaying) {
      await _engine.audio.stopMusic(fadeOut: true);
      setState(() {
        _isMusicPlaying = false;
        _statusMessage = 'Stopped Background Music';
      });
    } else {
      try {
        await _engine.audio.playMusic(
          'assets/audio/test_music.mp3',
          loop: true,
          fadeIn: true,
        );
        setState(() {
          _isMusicPlaying = true;
          _statusMessage = 'Playing Background Music (test_music.mp3)';
        });
      } catch (e) {
        setState(() {
          _statusMessage =
              'Note: Could not play music (Add assets/audio/test_music.mp3 to pubspec)';
          _isMusicPlaying = !_isMusicPlaying; // Toggle visually for demo
        });
      }
    }
  }

  void _playSfx() async {
    try {
      await _engine.audio.playSfx('assets/audio/test_sfx.wav');
      setState(() {
        _statusMessage = 'Played Sound Effect (test_sfx.wav)';
      });
    } catch (e) {
      setState(() {
        _statusMessage =
            'Note: Could not play SFX (Add assets/audio/test_sfx.wav to pubspec)';
      });
    }
  }

  void _updateVolume(double value) {
    setState(() {
      _masterVolume = value;
      _engine.audio.setMasterVolume(value);
      _statusMessage = 'Master Volume set to ${(value * 100).toInt()}%';
    });
  }

  void _toggleMute() {
    _engine.audio.toggleMute();
    setState(() {
      _statusMessage = _engine.audio.isMuted
          ? 'Audio System Muted'
          : 'Audio System Unmuted';
    });
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio_engine/just_audio_engine.dart';

/// An [AudioBackend] that plays nothing and touches no platform code.
///
/// The 3-D demos' engines use it ([Demo3DEngine]): the native audio plugin
/// is shared by the whole app, and an engine disposing its own native
/// backend would shut audio down for the shared 2-D engine too.
class SilentAudioBackend implements AudioBackend {
  int _next = 0;
  final StreamController<String> _ended = StreamController.broadcast();

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> dispose() async => _ended.close();

  @override
  Future<String?> loadSource(String path, {bool stream = false}) async =>
      'silent-source-${_next++}';

  @override
  Future<void> disposeSource(String sourceId) async {}

  @override
  Future<String?> playVoice(
    String sourceId, {
    double volume = 1.0,
    bool loop = false,
    double pan = 0.0,
    double pitch = 1.0,
    double speed = 1.0,
    String busName = 'sfx',
    bool spatial = false,
    double lowPass = 0,
  }) async => 'silent-voice-${_next++}';

  @override
  Future<void> stopVoice(String voiceId) async {}

  @override
  Future<void> pauseVoice(String voiceId) async {}

  @override
  Future<void> resumeVoice(String voiceId) async {}

  @override
  Future<void> setVoiceVolume(String voiceId, double volume) async {}

  @override
  Future<void> setVoiceLoop(String voiceId, {required bool loop}) async {}

  @override
  Future<void> setVoicePan(String voiceId, double pan) async {}

  @override
  Future<void> setVoicePitch(String voiceId, double pitch) async {}

  @override
  Future<void> setVoiceSpeed(String voiceId, double speed) async {}

  @override
  Future<bool> isVoiceActive(String voiceId) async => false;

  @override
  Future<void> setVoiceProtected(
    String voiceId, {
    required bool protect,
  }) async {}

  @override
  Future<void> fadeVoiceVolume(
    String voiceId,
    double target,
    Duration duration,
  ) async {}

  @override
  Future<void> cancelFade(String voiceId) async {}

  @override
  Future<void> stopVoices(List<String> voiceIds) async {}

  @override
  Future<void> setBulkVoiceVolumes(Map<String, double> volumes) async {}

  @override
  Future<void> setVoiceMixes(List<String> voiceIds, Float64List mixes) async {}

  @override
  Future<void> setGlobalVolume(double volume) async {}

  @override
  Future<void> setBusVolume(String name, double volume) async {}

  @override
  Future<void> setVoiceEffect(String voiceId, AudioEffect effect) async {}

  @override
  Future<void> clearVoiceEffects(String voiceId) async {}

  @override
  Stream<String> get voiceEndedStream => _ended.stream;
}

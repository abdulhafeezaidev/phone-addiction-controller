import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';

class SoundscapeToken {
  final String id;
  final String name;
  final String category;
  final String musicalKey;
  final String description;
  final int durationMs;

  const SoundscapeToken({
    required this.id,
    required this.name,
    required this.category,
    required this.musicalKey,
    required this.description,
    required this.durationMs,
  });
}

const List<SoundscapeToken> kSoundscapeTokens = [
  SoundscapeToken(
    id: 'bell_528_harmony',
    name: 'Golden Solfeggio Bell',
    category: 'Celebration Chime',
    musicalKey: '528 Hz (Transformation / Miracle Frequency)',
    description: 'Resonates like a golden temple bell, rewarding patience and calm presence.',
    durationMs: 2200,
  ),
  SoundscapeToken(
    id: 'kalimba_pentatonic_sparkle',
    name: 'Bamboo Kalimba Arpeggio',
    category: 'Organic Wood',
    musicalKey: 'C Major Pentatonic (C5, E5, G5, A5)',
    description: 'Warm organic plucks grounding you in the tactile physical world.',
    durationMs: 1400,
  ),
  SoundscapeToken(
    id: 'singing_bowl_drone',
    name: 'Tibetan Singing Bowl Hum',
    category: 'Resonant Drone',
    musicalKey: '216 Hz with 4.5 Hz Theta wave',
    description: 'Low meditative drone inducing theta wave mental settling.',
    durationMs: 2800,
  ),
  SoundscapeToken(
    id: 'dewdrop_water_pluck',
    name: 'Dewdrop Water Pluck',
    category: 'Nature Droplet',
    musicalKey: 'Glissando (880 Hz → 620 Hz)',
    description: 'Playful downward water droplet on pet and mindful breath.',
    durationMs: 400,
  ),
  SoundscapeToken(
    id: 'zen_wind_chime',
    name: 'Misty Forest Wind Chime',
    category: 'Silver Cascade',
    musicalKey: 'Pentatonic Cascade (E5, G#5, B5, E6)',
    description: 'Ethereal forest breeze rewarding garden growth and milestones.',
    durationMs: 2400,
  ),
];

class AmbientSoundscape {
  final String id;
  final String name;
  final String description;
  final String icon;

  const AmbientSoundscape({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

const List<AmbientSoundscape> kAmbientSoundscapes = [
  AmbientSoundscape(
    id: 'forest_rain',
    name: 'Forest Rain',
    description: 'Gentle, soothing woodland precipitation',
    icon: '🌧️',
  ),
  AmbientSoundscape(
    id: 'gentle_stream',
    name: 'Gentle Stream',
    description: 'Babbling mountain brook flowing peacefully',
    icon: '🌊',
  ),
  AmbientSoundscape(
    id: 'soft_drone',
    name: 'Singing Bowl Drone',
    description: 'Deep 108Hz harmonic singing-bowl resonance',
    icon: '🧘',
  ),
];

class SoundscapeState {
  final bool isVoiceEnabled;
  final bool isSoundscapeEnabled;
  final String? activeAmbient;

  const SoundscapeState({
    this.isVoiceEnabled = true,
    this.isSoundscapeEnabled = true,
    this.activeAmbient,
  });

  SoundscapeState copyWith({
    bool? isVoiceEnabled,
    bool? isSoundscapeEnabled,
    String? activeAmbient,
    bool clearAmbient = false,
  }) {
    return SoundscapeState(
      isVoiceEnabled: isVoiceEnabled ?? this.isVoiceEnabled,
      isSoundscapeEnabled: isSoundscapeEnabled ?? this.isSoundscapeEnabled,
      activeAmbient: clearAmbient ? null : (activeAmbient ?? this.activeAmbient),
    );
  }
}

class SoundscapeNotifier extends StateNotifier<SoundscapeState> {
  final Ref _ref;
  static const _voiceKey = 'bloomly_lumi_voice_enabled';
  static const _soundKey = 'bloomly_soundscapes_enabled';

  SoundscapeNotifier(this._ref) : super(const SoundscapeState()) {
    _loadSettings();
  }

  void _loadSettings() {
    try {
      final storage = _ref.read(storageServiceProvider);
      final voiceEnabled = storage.get<bool>(AppConstants.settingsBox, _voiceKey, defaultValue: true) ?? true;
      final soundEnabled = storage.get<bool>(AppConstants.settingsBox, _soundKey, defaultValue: true) ?? true;
      state = state.copyWith(
        isVoiceEnabled: voiceEnabled,
        isSoundscapeEnabled: soundEnabled,
      );
    } catch (_) {}
  }

  Future<void> toggleVoice() async {
    final newValue = !state.isVoiceEnabled;
    state = state.copyWith(isVoiceEnabled: newValue);
    try {
      final storage = _ref.read(storageServiceProvider);
      await storage.put(AppConstants.settingsBox, _voiceKey, newValue);
      if (!newValue) {
        await _ref.read(nativeBridgeServiceProvider).stopSpeakingLumi();
      }
    } catch (_) {}
  }

  Future<void> toggleSoundscape() async {
    final newValue = !state.isSoundscapeEnabled;
    state = state.copyWith(isSoundscapeEnabled: newValue);
    try {
      final storage = _ref.read(storageServiceProvider);
      await storage.put(AppConstants.settingsBox, _soundKey, newValue);
      if (!newValue && state.activeAmbient != null) {
        await stopAmbient();
      }
    } catch (_) {}
  }

  Future<void> playToken(String tokenId) async {
    if (!state.isSoundscapeEnabled) return;
    try {
      await _ref.read(nativeBridgeServiceProvider).playSoundscape(tokenId);
    } catch (_) {}
  }

  Future<void> playDewdrop() => playToken('dewdrop_water_pluck');
  Future<void> playCelebrationBell() => playToken('bell_528_harmony');
  Future<void> playKalimba() => playToken('kalimba_pentatonic_sparkle');
  Future<void> playSingingBowl() => playToken('singing_bowl_drone');
  Future<void> playWindChime() => playToken('zen_wind_chime');

  Future<void> speakLumi(String text) async {
    if (!state.isVoiceEnabled) return;
    try {
      await _ref.read(nativeBridgeServiceProvider).speakLumi(text);
    } catch (_) {}
  }

  Future<void> stopSpeaking() async {
    try {
      await _ref.read(nativeBridgeServiceProvider).stopSpeakingLumi();
    } catch (_) {}
  }

  Future<void> toggleAmbient(String sceneId) async {
    if (state.activeAmbient == sceneId) {
      await stopAmbient();
    } else {
      await startAmbient(sceneId);
    }
  }

  Future<void> startAmbient(String sceneId) async {
    if (!state.isSoundscapeEnabled) return;
    state = state.copyWith(activeAmbient: sceneId);
    try {
      await _ref.read(nativeBridgeServiceProvider).startAmbientSoundscape(sceneId);
    } catch (_) {}
  }

  Future<void> stopAmbient() async {
    state = state.copyWith(clearAmbient: true);
    try {
      await _ref.read(nativeBridgeServiceProvider).stopAmbientSoundscape();
    } catch (_) {}
  }
}

final soundscapeProvider = StateNotifierProvider<SoundscapeNotifier, SoundscapeState>((ref) {
  return SoundscapeNotifier(ref);
});

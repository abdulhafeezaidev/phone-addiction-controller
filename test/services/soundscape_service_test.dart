import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_addiction_controller/core/services/soundscape_service.dart';
import 'package:phone_addiction_controller/core/providers/app_providers.dart';
import 'package:phone_addiction_controller/services/native_bridge_service.dart';
import 'package:phone_addiction_controller/services/interfaces/storage_service.dart';

class FakeStorageService implements StorageService {
  final Map<String, dynamic> _store = {};


  @override
  T? get<T>(String boxName, String key, {T? defaultValue}) {
    return (_store['$boxName:$key'] as T?) ?? defaultValue;
  }

  @override
  Future<void> put<T>(String boxName, String key, T value) async {
    _store['$boxName:$key'] = value;
  }

  @override
  Future<void> delete(String boxName, String key) async {
    _store.remove('$boxName:$key');
  }

  @override
  Future<void> clearBox(String boxName) async {
    _store.removeWhere((k, _) => k.startsWith('$boxName:'));
  }

  @override
  bool containsKey(String boxName, String key) => _store.containsKey('$boxName:$key');

  @override
  List<T> getAll<T>(String boxName) {
    return _store.entries
        .where((e) => e.key.startsWith('$boxName:'))
        .map((e) => e.value as T)
        .toList();
  }
}

class FakeNativeBridgeService extends Fake implements NativeBridgeService {
  String? lastSpoken;
  String? lastPlayedToken;
  String? lastAmbient;
  bool stoppedSpeech = false;

  @override
  Future<bool> speakLumi(String text) async {
    lastSpoken = text;
    return true;
  }

  @override
  Future<bool> stopSpeakingLumi() async {
    stoppedSpeech = true;
    return true;
  }

  @override
  Future<bool> playSoundscape(String token) async {
    lastPlayedToken = token;
    return true;
  }

  @override
  Future<bool> startAmbientSoundscape(String scene) async {
    lastAmbient = scene;
    return true;
  }

  @override
  Future<bool> stopAmbientSoundscape() async {
    lastAmbient = null;
    return true;
  }
}

void main() {
  group('SoundscapeService Tests', () {
    late ProviderContainer container;
    late FakeNativeBridgeService fakeBridge;
    late FakeStorageService fakeStorage;

    setUp(() {
      fakeBridge = FakeNativeBridgeService();
      fakeStorage = FakeStorageService();

      container = ProviderContainer(
        overrides: [
          nativeBridgeServiceProvider.overrideWithValue(fakeBridge),
          storageServiceProvider.overrideWithValue(fakeStorage),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('initializes with default voice and soundscapes enabled', () {
      final state = container.read(soundscapeProvider);
      expect(state.isVoiceEnabled, isTrue);
      expect(state.isSoundscapeEnabled, isTrue);
      expect(state.activeAmbient, isNull);
    });

    test('plays dewdrop water pluck token', () async {
      final notifier = container.read(soundscapeProvider.notifier);
      await notifier.playDewdrop();
      expect(fakeBridge.lastPlayedToken, 'dewdrop_water_pluck');
    });

    test('plays golden solfeggio bell 528Hz token', () async {
      final notifier = container.read(soundscapeProvider.notifier);
      await notifier.playCelebrationBell();
      expect(fakeBridge.lastPlayedToken, 'bell_528_harmony');
    });

    test('speaks Lumi text when voice is enabled', () async {
      final notifier = container.read(soundscapeProvider.notifier);
      await notifier.speakLumi('Hello from Lumi');
      expect(fakeBridge.lastSpoken, 'Hello from Lumi');
    });

    test('does not speak when voice is disabled', () async {
      final notifier = container.read(soundscapeProvider.notifier);
      await notifier.toggleVoice();
      fakeBridge.lastSpoken = null;

      await notifier.speakLumi('Hello from Lumi');
      expect(fakeBridge.lastSpoken, isNull);
    });

    test('toggles ambient soundscape on and off', () async {
      final notifier = container.read(soundscapeProvider.notifier);
      await notifier.toggleAmbient('forest_rain');
      expect(container.read(soundscapeProvider).activeAmbient, 'forest_rain');
      expect(fakeBridge.lastAmbient, 'forest_rain');

      await notifier.toggleAmbient('forest_rain');
      expect(container.read(soundscapeProvider).activeAmbient, isNull);
      expect(fakeBridge.lastAmbient, isNull);
    });
  });
}

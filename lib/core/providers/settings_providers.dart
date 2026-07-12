import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_settings.dart';
import '../../core/constants/app_constants.dart';
import 'service_providers.dart';

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier(ref);
});

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this.ref) : super(AppSettings()) {
    _loadSettings();
  }

  final Ref ref;

  void _loadSettings() {
    final storage = ref.read(storageServiceProvider);
    final savedSettings = storage.get<AppSettings>(
      AppConstants.appSettingsBox,
      'settings',
    );
    if (savedSettings != null) {
      state = savedSettings;
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    final storage = ref.read(storageServiceProvider);
    await storage.put(AppConstants.appSettingsBox, 'settings', newSettings);

    if (state.strictMode != newSettings.strictMode) {
      final accessManager = ref.read(accessibilityServiceManagerProvider);
      await accessManager.sendCommand('updateStrictMode',
          args: {'isStrict': newSettings.strictMode});
    }

    state = newSettings;
  }
}

final isDeviceOwnerProvider = FutureProvider<bool>((ref) async {
  final manager = ref.read(accessibilityServiceManagerProvider);
  return await manager.isDeviceOwner();
});

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../interfaces/backup_restore_service.dart';
import '../interfaces/storage_service.dart';
import '../../domain/models/allowed_app.dart';
import '../../domain/models/routine.dart';
import '../../domain/models/focus_session.dart';
import '../../domain/models/app_settings.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

class BackupRestoreServiceImpl implements BackupRestoreService {
  BackupRestoreServiceImpl({required this.storageService});

  final StorageService storageService;

  @override
  Future<String> exportData() async {
    try {
      final routines = storageService.getAll<Routine>(AppConstants.routinesBox);
      final sessions = storageService.getAll<FocusSession>(AppConstants.focusSessionBox);
      final allowedApps = storageService.getAll<AllowedApp>(AppConstants.allowedAppsBox);
      
      final settingsList = storageService.getAll<AppSettings>(AppConstants.appSettingsBox);
      final settings = settingsList.isNotEmpty ? settingsList.first : AppSettings();

      final data = {
        'version': AppConstants.backupVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'routines': routines.map((r) => {
          'id': r.id,
          'weekdays': r.weekdays,
          'startTime': r.startTime.toIso8601String(),
          'endTime': r.endTime.toIso8601String(),
          'label': r.label,
          'enabled': r.enabled,
        }).toList(),
        'sessions': sessions.map((s) => {
          'id': s.id,
          'startTime': s.startTime.toIso8601String(),
          'endTime': s.endTime?.toIso8601String(),
          'enabled': s.enabled,
          'triggerType': s.triggerType.index,
          'stopType': s.stopType?.index,
          'blockedAttempts': s.blockedAttempts,
          'blockedAppCounts': s.blockedAppCounts,
          'routineId': s.routineId,
        }).toList(),
        'allowedApps': allowedApps.map((a) => {
          'packageName': a.packageName,
          'appName': a.appName,
          'isAllowed': a.isAllowed,
        }).toList(),
        'appSettings': {
          'strictMode': settings.strictMode,
          'notificationsEnabled': settings.notificationsEnabled,
          'autoStartOnBoot': settings.autoStartOnBoot,
          'batteryOptDismissed': settings.batteryOptDismissed,
          'themeMode': settings.themeMode,
        },
      };

      return jsonEncode(data);
    } catch (e, stack) {
      AppLogger.error('Failed to export data', error: e, stackTrace: stack);
      throw Exception('Failed to generate backup: $e');
    }
  }

  @override
  Future<void> importData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      final version = data['version'] as int? ?? 0;
      if (version > AppConstants.backupVersion) {
        throw Exception('Backup version is newer than this app version. Please update the app.');
      }

      // Parse Routines
      final rawRoutines = data['routines'] as List? ?? [];
      final routines = rawRoutines.map((r) => Routine(
        id: r['id'] as String,
        weekdays: List<int>.from(r['weekdays'] as List),
        startTime: DateTime.parse(r['startTime'] as String),
        endTime: DateTime.parse(r['endTime'] as String),
        label: r['label'] as String,
        enabled: r['enabled'] as bool,
      )).toList();

      // Parse Sessions
      final rawSessions = data['sessions'] as List? ?? [];
      final sessions = rawSessions.map((s) => FocusSession(
        id: s['id'] as String,
        startTime: DateTime.parse(s['startTime'] as String),
        endTime: s['endTime'] != null ? DateTime.parse(s['endTime'] as String) : null,
        enabled: s['enabled'] as bool? ?? false,
        triggerType: SessionTriggerType.values[s['triggerType'] as int? ?? 0],
        stopType: s['stopType'] != null ? SessionStopType.values[s['stopType'] as int] : null,
        blockedAttempts: s['blockedAttempts'] as int? ?? 0,
        blockedAppCounts: Map<String, int>.from(s['blockedAppCounts'] as Map? ?? {}),
        routineId: s['routineId'] as String?,
      )).toList();

      // Parse Allowed Apps
      final rawAllowedApps = data['allowedApps'] as List? ?? [];
      final allowedAppsList = rawAllowedApps.map((a) => AllowedApp(
        packageName: a['packageName'] as String,
        appName: a['appName'] as String,
        isAllowed: a['isAllowed'] as bool,
      )).toList();

      // Parse Settings
      final s = data['appSettings'] as Map<String, dynamic>? ?? {};
      final settings = AppSettings(
        strictMode: s['strictMode'] as bool? ?? false,
        notificationsEnabled: s['notificationsEnabled'] as bool? ?? true,
        autoStartOnBoot: s['autoStartOnBoot'] as bool? ?? false,
        batteryOptDismissed: s['batteryOptDismissed'] as bool? ?? false,
        themeMode: s['themeMode'] as int? ?? 2,
      );

      // Clear existing and save new
      await storageService.clearBox(AppConstants.routinesBox);
      for (final r in routines) {
        await storageService.put(AppConstants.routinesBox, r.id, r);
      }

      await storageService.clearBox(AppConstants.focusSessionBox);
      for (final session in sessions) {
        await storageService.put(AppConstants.focusSessionBox, session.id, session);
      }

      await storageService.clearBox(AppConstants.allowedAppsBox);
      for (final app in allowedAppsList) {
        await storageService.put(AppConstants.allowedAppsBox, app.packageName, app);
      }

      await storageService.clearBox(AppConstants.appSettingsBox);
      await storageService.put(AppConstants.appSettingsBox, 'settings', settings);

      AppLogger.info('Successfully imported backup data');
    } catch (e, stack) {
      AppLogger.error('Failed to import data', error: e, stackTrace: stack);
      throw Exception('Invalid or corrupted backup file');
    }
  }

  @override
  Future<bool> saveBackupToFile() async {
    try {
      final json = await exportData();
      final date = DateTime.now().toIso8601String().split('T')[0];
      final filename = '${AppConstants.backupFilePrefix}_$date.json';
      
      // We use SharePlus to let the user save it to their preferred location (e.g. Drive, Files)
      // because direct file writing in scoped storage requires SAF, which Share handles well.
      final result = await Share.shareXFiles(
        [
          XFile.fromData(
            utf8.encode(json),
            name: filename,
            mimeType: 'application/json',
          )
        ],
        text: 'Focus Guard Backup',
      );
      
      return result.status == ShareResultStatus.success;
    } catch (e) {
      AppLogger.error('Failed to share/save backup file', error: e);
      return false;
    }
  }

  @override
  Future<bool> restoreFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        await importData(jsonString);
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Failed to read and restore from file', error: e);
      rethrow;
    }
  }
}

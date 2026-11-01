import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:phone_addiction_controller/core/constants/app_constants.dart';
import 'package:phone_addiction_controller/domain/models/time_slot.dart';
import 'package:phone_addiction_controller/services/impl/schedule_service_impl.dart';
import 'package:phone_addiction_controller/services/native_bridge_service.dart';

import 'emergency_override_service_impl_test.mocks.dart';

class RecordingNativeBridgeService extends Fake implements NativeBridgeService {
  String? lastScheduledJson;
  String? lastCancelledRoutineId;
  List<String> fallbackBlockedPackages = const [];

  @override
  Future<List<String>> getBlockedPackages() async => fallbackBlockedPackages;

  @override
  Future<void> scheduleRoutine(String routineJson) async {
    lastScheduledJson = routineJson;
  }

  @override
  Future<void> cancelRoutine(String routineId) async {
    lastCancelledRoutineId = routineId;
  }
}

void main() {
  late MockStorageService mockStorageService;
  late RecordingNativeBridgeService fakeNativeBridge;
  late ScheduleServiceImpl scheduleService;

  setUp(() {
    mockStorageService = MockStorageService();
    fakeNativeBridge = RecordingNativeBridgeService();
    scheduleService = ScheduleServiceImpl(
      storageService: mockStorageService,
      nativeBridgeService: fakeNativeBridge,
    );
  });

  group('ScheduleServiceImpl Tests', () {
    test('addRoutine syncs selected apps from lastBlockedPackagesKey to native layer', () async {
      when(mockStorageService.get<List<dynamic>>(
        AppConstants.settingsBox,
        AppConstants.lastBlockedPackagesKey,
      )).thenReturn(['com.instagram.android', 'com.zhiliaoapp.musically']);

      final start = DateTime(2026, 1, 1, 22, 0);
      final end = DateTime(2026, 1, 1, 7, 0);

      final routine = await scheduleService.addRoutine(
        weekdays: [0, 1, 2, 3, 4],
        startTime: start,
        endTime: end,
        label: 'Night Wind Down',
        slots: [
          TimeSlot(startHour: 22, startMinute: 0, endHour: 7, endMinute: 0),
        ],
      );

      expect(routine.label, 'Night Wind Down');
      expect(fakeNativeBridge.lastScheduledJson, isNotNull);

      final decoded = jsonDecode(fakeNativeBridge.lastScheduledJson!) as Map<String, dynamic>;
      expect(decoded['id'], routine.id);
      expect(decoded['label'], 'Night Wind Down');
      expect(
        decoded['blockedPackages'],
        equals(['com.instagram.android', 'com.zhiliaoapp.musically']),
      );
    });

    test('deleteRoutine deletes from storage and cancels native routine', () async {
      await scheduleService.deleteRoutine('routine-123');

      verify(mockStorageService.delete(AppConstants.routinesBox, 'routine-123')).called(1);
      expect(fakeNativeBridge.lastCancelledRoutineId, 'routine-123');
    });
  });
}

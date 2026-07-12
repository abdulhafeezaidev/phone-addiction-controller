import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:phone_addiction_controller/core/constants/app_constants.dart';
import 'package:phone_addiction_controller/domain/models/admin_settings.dart';
import 'package:phone_addiction_controller/domain/models/emergency_override_state.dart';
import 'package:phone_addiction_controller/services/impl/emergency_override_service_impl.dart';
import 'package:phone_addiction_controller/services/interfaces/storage_service.dart';
import 'package:phone_addiction_controller/services/interfaces/password_service.dart';
import 'package:phone_addiction_controller/services/interfaces/schedule_service.dart';
import 'package:phone_addiction_controller/services/interfaces/focus_session_manager.dart';

import 'emergency_override_service_impl_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<StorageService>(),
  MockSpec<PasswordService>(),
  MockSpec<ScheduleService>(),
  MockSpec<FocusSessionManager>(),
])
void main() {
  late MockStorageService mockStorageService;
  late MockPasswordService mockPasswordService;
  late MockScheduleService mockScheduleService;
  late MockFocusSessionManager mockFocusSessionManager;
  late EmergencyOverrideServiceImpl overrideService;

  setUp(() {
    mockStorageService = MockStorageService();
    mockPasswordService = MockPasswordService();
    mockScheduleService = MockScheduleService();
    mockFocusSessionManager = MockFocusSessionManager();

    overrideService = EmergencyOverrideServiceImpl(
      storageService: mockStorageService,
      passwordService: mockPasswordService,
      scheduleService: mockScheduleService,
      focusSessionManager: mockFocusSessionManager,
    );
  });

  group('EmergencyOverrideServiceImpl Tests', () {
    test('setRecoveryChallenge hashes answer and updates AdminSettings', () async {
      final mockSettings = AdminSettings(passwordHash: 'hashedPass');
      when(mockPasswordService.getAdminSettings()).thenAnswer((_) async => mockSettings);

      await overrideService.setRecoveryChallenge('Pet name?', 'Buddy');

      final expectedHash = sha256.convert(utf8.encode('buddy')).toString();
      verify(mockStorageService.put(
        AppConstants.adminSettingsBox,
        AppConstants.adminPasswordKey,
        argThat(predicate<AdminSettings>((settings) => settings.recoveryAnswerHash == expectedHash)),
      )).called(1);
    });

    test('verifyRecoveryAnswer initiates reflection timer on match', () async {
      final hashedAnswer = sha256.convert(utf8.encode('buddy')).toString();
      final mockSettings = AdminSettings(
        passwordHash: 'hashedPass',
        recoveryChallenge: 'Pet name?',
        recoveryAnswerHash: hashedAnswer,
      );

      when(mockPasswordService.getAdminSettings()).thenAnswer((_) async => mockSettings);
      when(mockStorageService.get<EmergencyOverrideState>(
        AppConstants.emergencyOverrideBox,
        'state',
      )).thenReturn(EmergencyOverrideState());

      final verified = await overrideService.verifyRecoveryAnswer('BUDDY ');

      expect(verified, isTrue);
      verify(mockStorageService.put(
        AppConstants.emergencyOverrideBox,
        'state',
        any,
      )).called(1);
    });

    test('verifyRecoveryAnswer fails on wrong answer', () async {
      final hashedAnswer = sha256.convert(utf8.encode('buddy')).toString();
      final mockSettings = AdminSettings(
        passwordHash: 'hashedPass',
        recoveryChallenge: 'Pet name?',
        recoveryAnswerHash: hashedAnswer,
      );

      when(mockPasswordService.getAdminSettings()).thenAnswer((_) async => mockSettings);

      final verified = await overrideService.verifyRecoveryAnswer('Max');

      expect(verified, isFalse);
    });

    test('verifyRecoveryAnswer respects cooldown window', () async {
      final hashedAnswer = sha256.convert(utf8.encode('buddy')).toString();
      final mockSettings = AdminSettings(
        passwordHash: 'hashedPass',
        recoveryChallenge: 'Pet name?',
        recoveryAnswerHash: hashedAnswer,
      );

      final stateWithRecentActivation = EmergencyOverrideState(
        lastActivationTime: DateTime.now().subtract(const Duration(hours: 1)),
      );

      when(mockPasswordService.getAdminSettings()).thenAnswer((_) async => mockSettings);
      when(mockStorageService.get<EmergencyOverrideState>(
        AppConstants.emergencyOverrideBox,
        'state',
      )).thenReturn(stateWithRecentActivation);

      final verified = await overrideService.verifyRecoveryAnswer('buddy');

      expect(verified, isFalse);
    });
  });
}

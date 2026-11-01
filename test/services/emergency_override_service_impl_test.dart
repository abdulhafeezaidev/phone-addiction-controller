import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:phone_addiction_controller/core/constants/app_constants.dart';
import 'package:phone_addiction_controller/domain/models/emergency_override_state.dart';
import 'package:phone_addiction_controller/services/impl/emergency_override_service_impl.dart';
import 'package:phone_addiction_controller/services/interfaces/storage_service.dart';
import 'package:phone_addiction_controller/services/interfaces/password_service.dart';
import 'package:phone_addiction_controller/services/native_bridge_service.dart';

import 'emergency_override_service_impl_test.mocks.dart';

class FakeNativeBridgeService extends Fake implements NativeBridgeService {
  @override
  Future<void> setEmergencyOverrideActive({
    required bool active,
    required int expirationTimeMs,
  }) async {}
}

@GenerateNiceMocks([
  MockSpec<StorageService>(),
  MockSpec<PasswordService>(),
])
void main() {
  late MockStorageService mockStorageService;
  late MockPasswordService mockPasswordService;
  late FakeNativeBridgeService fakeNativeBridgeService;
  late EmergencyOverrideServiceImpl overrideService;

  setUp(() {
    mockStorageService = MockStorageService();
    mockPasswordService = MockPasswordService();
    fakeNativeBridgeService = FakeNativeBridgeService();

    overrideService = EmergencyOverrideServiceImpl(
      storageService: mockStorageService,
      passwordService: mockPasswordService,
      nativeBridgeService: fakeNativeBridgeService,
    );
  });

  tearDown(() {
    overrideService.dispose();
  });

  group('EmergencyOverrideServiceImpl Tests', () {
    test('setRecoveryChallenge hashes answer and updates emergencyOverrideBox', () async {
      await overrideService.setRecoveryChallenge('Pet name?', 'Buddy');

      final expectedHash = sha256.convert(utf8.encode('buddy')).toString();
      verify(mockStorageService.put<String>(
        AppConstants.settingsBox,
        'emergency_challenge',
        'Pet name?',
      )).called(1);
      verify(mockStorageService.put<String>(
        AppConstants.settingsBox,
        'emergency_answer_hash',
        expectedHash,
      )).called(1);
    });

    test('verifyRecoveryAnswer initiates reflection timer on match', () async {
      final hashedAnswer = sha256.convert(utf8.encode('buddy')).toString();

      when(mockStorageService.get<dynamic>(
        AppConstants.settingsBox,
        'emergency_answer_hash',
      )).thenReturn(hashedAnswer);
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

      when(mockStorageService.get<dynamic>(
        AppConstants.settingsBox,
        'emergency_answer_hash',
      )).thenReturn(hashedAnswer);

      final verified = await overrideService.verifyRecoveryAnswer('Max');

      expect(verified, isFalse);
    });

    test('verifyRecoveryAnswer respects cooldown window', () async {
      final hashedAnswer = sha256.convert(utf8.encode('buddy')).toString();

      final stateWithRecentActivation = EmergencyOverrideState(
        lastActivationTime: DateTime.now().subtract(const Duration(hours: 1)),
      );

      when(mockStorageService.get<dynamic>(
        AppConstants.settingsBox,
        'emergency_answer_hash',
      )).thenReturn(hashedAnswer);
      when(mockStorageService.get<EmergencyOverrideState>(
        AppConstants.emergencyOverrideBox,
        'state',
      )).thenReturn(stateWithRecentActivation);

      final verified = await overrideService.verifyRecoveryAnswer('buddy');

      expect(verified, isFalse);
    });

    test('verifyRecoveryAnswer rejects default fallback phrase when custom hash is configured', () async {
      final hashedAnswer = sha256.convert(utf8.encode('buddy')).toString();

      when(mockStorageService.get<dynamic>(
        AppConstants.settingsBox,
        'emergency_answer_hash',
      )).thenReturn(hashedAnswer);

      final verified = await overrideService.verifyRecoveryAnswer('I need emergency access');

      expect(verified, isFalse);
    });

    test('verifyRecoveryAnswer accepts default fallback phrase when no custom hash is configured', () async {
      when(mockStorageService.get<dynamic>(
        AppConstants.settingsBox,
        'emergency_answer_hash',
      )).thenReturn(null);
      when(mockStorageService.get<EmergencyOverrideState>(
        AppConstants.emergencyOverrideBox,
        'state',
      )).thenReturn(EmergencyOverrideState());

      final verified = await overrideService.verifyRecoveryAnswer('I need emergency access');

      expect(verified, isTrue);
    });
  });
}

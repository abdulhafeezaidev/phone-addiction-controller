import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:phone_addiction_controller/services/impl/password_service_impl.dart';
import 'package:phone_addiction_controller/services/interfaces/storage_service.dart';

import 'password_service_impl_test.mocks.dart';

@GenerateNiceMocks([MockSpec<StorageService>()])
void main() {
  late MockStorageService mockStorageService;
  late PasswordServiceImpl passwordService;

  setUp(() {
    mockStorageService = MockStorageService();
    passwordService = PasswordServiceImpl(mockStorageService);
  });

  group('PasswordServiceImpl', () {
    test('hashPassword generates unique hashes for same password', () {
      const pass = 'securePin123';
      final hash1 = passwordService.hashPassword(pass);
      final hash2 = passwordService.hashPassword(pass);

      expect(hash1, isNot(equals(hash2)));
      expect(hash1.split(':').length, 2);
    });

    test('verifyPassword correctly validates password', () {
      const pass = 'mySecretPin';
      final hash = passwordService.hashPassword(pass);

      expect(passwordService.verifyPassword(pass, hash), isTrue);
      expect(passwordService.verifyPassword('wrongPin', hash), isFalse);
    });
  });
}

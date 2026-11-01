import 'package:flutter_test/flutter_test.dart';
import 'package:phone_addiction_controller/services/native_bridge_service.dart';

void main() {
  group('ProtectionState', () {
    test('reports Android-enforced owner protection separately', () {
      final state = ProtectionState.fromMap({
        'statusAvailable': true,
        'deviceAdminSupported': true,
        'deviceAdminActive': true,
        'accessibilityServiceEnabled': true,
        'guardEnabled': true,
        'deviceOwner': true,
        'profileOwner': false,
        'ownerUninstallBlocked': true,
      });

      expect(state.statusAvailable, isTrue);
      expect(state.deviceAdminActive, isTrue);
      expect(state.guardEnabled, isTrue);
      expect(state.ownerMode, isTrue);
      expect(state.ownerUninstallBlocked, isTrue);
    });

    test('does not invent a successful status when native status is absent',
        () {
      final state = ProtectionState.fromMap(null);

      expect(state.statusAvailable, isFalse);
      expect(state.deviceAdminActive, isFalse);
      expect(state.ownerMode, isFalse);
      expect(state.ownerUninstallBlocked, isFalse);
    });

    test('keeps a saved guard distinct from the live Accessibility permission',
        () {
      final state = ProtectionState.fromMap({
        'statusAvailable': true,
        'guardEnabled': true,
        'accessibilityServiceEnabled': false,
      });

      expect(state.guardEnabled, isTrue);
      expect(state.accessibilityServiceEnabled, isFalse);
    });
  });

  group('runAuthenticatedProtectionAction', () {
    test('does not run an action if authentication is declined', () async {
      var actionRan = false;

      final result = await runAuthenticatedProtectionAction(
        authenticate: () async => false,
        action: () async {
          actionRan = true;
          return true;
        },
      );

      expect(result, isFalse);
      expect(actionRan, isFalse);
    });

    test('runs the action only after successful authentication', () async {
      final calls = <String>[];

      final result = await runAuthenticatedProtectionAction(
        authenticate: () async {
          calls.add('authenticate');
          return true;
        },
        action: () async {
          calls.add('action');
          return true;
        },
      );

      expect(result, isTrue);
      expect(calls, ['authenticate', 'action']);
    });
  });
}

import 'dart:io';

/// FocusOS Pre-Release Regression Test Runner (Cross-platform Dart CLI).
void main(List<String> args) async {
  final subsystems = <Map<String, String>>[
    {'name': 'Focus Session', 'file': 'test/regression/focus_session_regression_test.dart'},
    {'name': 'Routine Start', 'file': 'test/regression/routine_start_regression_test.dart'},
    {'name': 'Routine End', 'file': 'test/regression/routine_end_regression_test.dart'},
    {'name': 'Allowed Apps', 'file': 'test/regression/allowed_apps_regression_test.dart'},
    {'name': 'Blocked Apps', 'file': 'test/regression/blocked_apps_regression_test.dart'},
    {'name': 'Lock Screen', 'file': 'test/regression/lock_screen_regression_test.dart'},
    {'name': 'Emergency Override', 'file': 'test/regression/emergency_override_regression_test.dart'},
    {'name': 'Boot Recovery', 'file': 'test/regression/boot_recovery_regression_test.dart'},
    {'name': 'Device Reboot', 'file': 'test/regression/device_reboot_regression_test.dart'},
    {'name': 'Incoming Call', 'file': 'test/regression/incoming_call_regression_test.dart'},
    {'name': 'Outgoing Call', 'file': 'test/regression/outgoing_call_regression_test.dart'},
    {'name': 'Notifications', 'file': 'test/regression/notifications_regression_test.dart'},
    {'name': 'Network Controls', 'file': 'test/regression/network_controls_regression_test.dart'},
    {'name': 'Admin Authentication', 'file': 'test/regression/admin_auth_regression_test.dart'},
    {'name': 'Remote Approval', 'file': 'test/regression/remote_approval_regression_test.dart'},
  ];

  stdout.writeln('\n====================================================================');
  stdout.writeln(' FocusOS - Pre-Release Regression Test Suite Runner');
  stdout.writeln('====================================================================');
  stdout.writeln('Executing automated tests for 15 core subsystems...\n');

  final results = <Map<String, dynamic>>[];
  final stopwatch = Stopwatch()..start();

  // Run each subsystem test file individually for granular reporting
  for (final sub in subsystems) {
    final subName = sub['name']!;
    final subFile = sub['file']!;

    stdout.write('Checking ${subName.padRight(25)} ... ');

    final flutterCmd = Platform.isWindows ? 'C:\\Users\\abdul\\flutter\\bin\\flutter.bat' : 'flutter';
    final process = await Process.run(
      flutterCmd,
      ['test', subFile],
      environment: {
        'ANDROID_HOME': r'E:\Phone Addiction Controller\.android-sdk',
        'ANDROID_SDK_ROOT': r'E:\Phone Addiction Controller\.android-sdk',
      },
    );

    final passed = process.exitCode == 0;
    results.add({
      'name': subName,
      'file': subFile,
      'passed': passed,
      'output': process.stdout.toString(),
      'error': process.stderr.toString(),
    });

    stdout.writeln(passed ? '[ PASS ]' : '[ FAIL ]');
  }

  stopwatch.stop();

  final passedCount = results.where((r) => r['passed'] == true).length;
  final failedCount = results.where((r) => r['passed'] == false).length;

  stdout.writeln('\n====================================================================');
  stdout.writeln('                 PRE-RELEASE REGRESSION TEST REPORT                 ');
  stdout.writeln('====================================================================');
  stdout.writeln(' #  | Subsystem                    | Status | Target Test Suite');
  stdout.writeln('----+------------------------------+--------+-----------------------------------');

  for (var i = 0; i < results.length; i++) {
    final r = results[i];
    final num = (i + 1).toString().padLeft(2);
    final name = (r['name'] as String).padRight(28);
    final status = r['passed'] == true ? 'PASS' : 'FAIL';
    final file = r['file'] as String;
    stdout.writeln(' $num | $name |  $status  | $file');
  }

  stdout.writeln('----+------------------------------+--------+-----------------------------------');
  stdout.writeln('Total: ${subsystems.length} | Passed: $passedCount | Failed: $failedCount | Duration: ${stopwatch.elapsed.inSeconds}s\n');

  if (failedCount == 0) {
    stdout.writeln('>> CERTIFICATION: SUCCESS - ALL 15 REGRESSION SUITES PASSED');
    stdout.writeln('>> The build is certified regression-free and ready for release.\n');
    exit(0);
  } else {
    stdout.writeln('>> CERTIFICATION: FAILED - $failedCount REGRESSION(S) DETECTED');
    stdout.writeln('>> Release build is BLOCKED.\n');
    exit(1);
  }
}

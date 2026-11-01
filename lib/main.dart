import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/route_names.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'data/local/hive_boxes.dart';
import 'services/native_bridge_service.dart';
import 'widgets/admin_password_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive using the native app data directory (no third-party path/JNI plugins)
  final storageDir = await NativeBridgeService().getStorageDirectory();
  try {
    Hive.init(storageDir);
    await HiveBoxes.openAllBoxes();
    AppLogger.info('Hive initialized successfully');
  } catch (e, stack) {
    AppLogger.error('Hive initialization failed, attempting recovery',
        error: e, stackTrace: stack);
    try {
      await Hive.deleteFromDisk();
      Hive.init(storageDir);
      await HiveBoxes.openAllBoxes();
      AppLogger.info('Hive recovered after deletion');
    } catch (e2) {
      AppLogger.error('Hive recovery failed', error: e2);
    }
  }

  runApp(
    const ProviderScope(
      child: FocusGuardApp(),
    ),
  );
}

class FocusGuardApp extends ConsumerStatefulWidget {
  const FocusGuardApp({super.key});

  @override
  ConsumerState<FocusGuardApp> createState() => _FocusGuardAppState();
}

class _FocusGuardAppState extends ConsumerState<FocusGuardApp> {
  static const _navChannel = MethodChannel(AppConstants.navigationChannel);

  bool _isPromptingUninstall = false;

  @override
  void initState() {
    super.initState();

    // Listen to native navigation triggers (e.g. Emergency Unlock button, Tamper uninstall attempt)
    _navChannel.setMethodCallHandler((call) async {
      AppLogger.info('Received native nav call: ${call.method}');
      final router = ref.read(appRouterProvider);

      switch (call.method) {
        case 'openEmergency':
          router.push(RouteNames.emergencyOverride);
          break;
        case 'promptUninstallAdmin':
          if (_isPromptingUninstall) break;
          _isPromptingUninstall = true;
          try {
            final navContext = rootNavigatorKey.currentContext;
            final passwordService = ref.read(passwordServiceProvider);
            final adminSettings = await passwordService.getAdminSettings();

            // If no admin password has been set up yet, route to setup and do NOT uninstall
            if (adminSettings == null || adminSettings.passwordHash.isEmpty) {
              router.go(RouteNames.setup);
              break;
            }

            if (navContext != null) {
              try {
                var authorized = false;
                final started = await runAuthenticatedProtectionAction(
                  authenticate: () async {
                    authorized = await AdminPasswordDialog.show(
                      navContext,
                      actionDescription:
                          'deactivate Device Admin and uninstall Detox',
                    );
                    return authorized;
                  },
                  action: () =>
                      ref.read(nativeBridgeServiceProvider).prepareUninstall(),
                );
                if (authorized && !started) {
                  AppLogger.error(
                    'Android could not open the uninstall confirmation screen',
                  );
                }
              } catch (e) {
                AppLogger.error(
                  'Could not prepare Detox uninstall',
                  error: e,
                );
              }
            }
          } finally {
            _isPromptingUninstall = false;
          }
          break;
        case 'routineTriggered':
        case 'bootRecovery':
        case 'focusRecover':
          ref.invalidate(focusSessionProvider);
          break;
      }
    });

    // Notify native side that Flutter navigation is ready to receive method calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navChannel.invokeMethod('navigationReady').catchError((e) {
        AppLogger.warning('Failed to signal navigationReady: $e');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/allowed_apps/presentation/pages/allowed_apps_page.dart';
import '../../features/schedule/presentation/pages/schedule_page.dart';
import '../../features/focus_session/presentation/pages/focus_session_page.dart';
import '../../features/focus_session/presentation/pages/focus_lock_screen.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/diagnostics_page.dart';
import '../../features/admin/presentation/pages/admin_password_page.dart';
import '../../features/settings/presentation/pages/emergency_override_page.dart';
import '../../features/settings/presentation/pages/focus_lock_pin_page.dart';
import '../../features/focus_session/presentation/pages/blocked_page.dart';
import '../../features/home/presentation/pages/statistics_page.dart';
import '../../features/onboarding/presentation/pages/setup_wizard_page.dart';
import '../../features/settings/presentation/pages/system_permissions_page.dart';
import '../constants/route_names.dart';
import '../constants/app_constants.dart';
import '../../widgets/scaffold_with_nav_bar.dart';
import '../providers/service_providers.dart';
import '../providers/focus_providers.dart';
import '../utils/app_logger.dart';

part 'app_router.g.dart';

class _FocusRouterNotifier extends ChangeNotifier {
  bool isFocusActive = false;
}

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final storage = ref.watch(storageServiceProvider);
  final onboardingCompleted = storage.get<dynamic>(AppConstants.settingsBox, 'onboarding_completed') == true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AppLogger.info('Router Init: onboardingCompleted = $onboardingCompleted');
  });

  // Use a ChangeNotifier to trigger redirect re-evaluation without recreating the router
  final focusNotifier = _FocusRouterNotifier();
  ref.listen<bool>(focusModeProvider, (prev, next) {
    focusNotifier.isFocusActive = next;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    focusNotifier.notifyListeners();
  });
  // Sync initial value
  focusNotifier.isFocusActive = ref.read(focusModeProvider);

  ref.onDispose(() => focusNotifier.dispose());

  return GoRouter(
    initialLocation: onboardingCompleted ? RouteNames.home : RouteNames.setup,
    refreshListenable: focusNotifier,
    redirect: (context, state) {
      if (focusNotifier.isFocusActive) {
        final allowedFocusRoutes = [
          RouteNames.focusSession,
          RouteNames.blocked,
          RouteNames.emergencyOverride,
          RouteNames.home,
          RouteNames.allowedApps,
          RouteNames.schedule,
          RouteNames.settings,
          RouteNames.statistics,
          RouteNames.lockScreen,
          RouteNames.diagnostics,
        ];
        if (!allowedFocusRoutes.contains(state.matchedLocation)) {
          return RouteNames.focusSession;
        }
      }
      return null;
    },
    debugLogDiagnostics: false,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.home,
                name: 'home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.allowedApps,
                name: 'allowed_apps',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AllowedAppsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.schedule,
                name: 'schedule',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SchedulePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.settings,
                name: 'settings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SettingsPage(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.focusSession,
        name: 'focus_session',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const FocusSessionPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: RouteNames.adminPassword,
        name: 'admin_password',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const AdminPasswordPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: RouteNames.focusLockPin,
        name: 'focus_lock_pin',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const FocusLockPinPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: RouteNames.emergencyOverride,
        name: 'emergency_override',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const EmergencyOverridePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: RouteNames.blocked,
        name: 'blocked',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CustomTransitionPage(
            child: BlockedPage(appName: extra['appName'] as String? ?? 'App'),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: RouteNames.statistics,
        name: 'statistics',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const StatisticsPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: RouteNames.setup,
        name: 'setup',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const SetupWizardPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: RouteNames.permissions,
        name: 'permissions',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const SystemPermissionsPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: RouteNames.lockScreen,
        name: 'lock_screen',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const FocusLockScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: RouteNames.diagnostics,
        name: 'diagnostics',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const DiagnosticsPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
    ],
  );
}

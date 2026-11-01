import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/routine.dart';
import '../../features/admin/presentation/pages/admin_settings_page.dart';
import '../../features/emergency/presentation/pages/emergency_override_page.dart';
import '../../features/focus/presentation/pages/app_selection_page.dart';
import '../../features/home/presentation/pages/bloomly_home_page.dart';
import '../../features/onboarding/presentation/pages/setup_page.dart';
import '../constants/app_constants.dart';
import '../constants/route_names.dart';
import '../providers/app_providers.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final storage = ref.watch(storageServiceProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.home,
    redirect: (context, state) {
      final onboardingCompleted = storage.get<dynamic>(
            AppConstants.settingsBox,
            AppConstants.onboardingCompletedKey,
          ) ==
          true;

      final isGoingToSetup = state.matchedLocation == RouteNames.setup;

      if (!onboardingCompleted && !isGoingToSetup) {
        return RouteNames.setup;
      }
      if (onboardingCompleted && isGoingToSetup) {
        return RouteNames.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const BloomlyHomePage(),
      ),
      GoRoute(
        path: RouteNames.setup,
        builder: (context, state) => const SetupPage(),
      ),
      GoRoute(
        path: RouteNames.appSelection,
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'quick';
          final durationStr = state.uri.queryParameters['duration'] ?? '30';
          final duration = int.tryParse(durationStr) ?? 30;
          final existingRoutine =
              state.extra is Routine ? state.extra as Routine : null;

          return AppSelectionPage(
            mode: mode,
            durationMinutes: duration,
            existingRoutine: existingRoutine,
          );
        },
      ),
      GoRoute(
        path: RouteNames.adminSettings,
        builder: (context, state) => const AdminSettingsPage(),
      ),
      GoRoute(
        path: RouteNames.emergencyOverride,
        builder: (context, state) => const EmergencyOverridePage(),
      ),
    ],
  );
});

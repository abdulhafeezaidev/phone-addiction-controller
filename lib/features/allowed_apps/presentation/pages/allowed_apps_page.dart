import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/allowed_app.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/focus_providers.dart';
import '../../../../core/providers/admin_auth_provider.dart';

class AllowedAppsPage extends ConsumerStatefulWidget {
  const AllowedAppsPage({super.key});

  @override
  ConsumerState<AllowedAppsPage> createState() => _AllowedAppsPageState();
}

class _AllowedAppsPageState extends ConsumerState<AllowedAppsPage> {
  final _searchController = TextEditingController();

  static final Set<String> _alwaysAllowedKeywords = {
    'dialer', 'phone', 'incallui', // Phone
    'camera', // Camera
    'documentsui', 'myfiles', 'files', // Files
    'mms', 'messaging', // Messages
    'calculator', // Calculator
    'deskclock', 'clockpackage', 'clock', // Clock
    'contacts' // Contacts
  };

  static final Set<String> _systemPackages = {
    'com.android.phone',
    'com.android.server.telecom',
    'com.android.telecom',
    'com.android.dialer',
    'com.android.incallui',
    'com.android.phone.slice',
    'com.samsung.android.incallui',
    'com.samsung.android.dialer',
    'com.samsung.android.app.telephonyui',
    'com.samsung.android.telecom',
    'com.samsung.android.phone',
    'com.google.android.dialer',
    'com.android.contacts',
    'com.samsung.android.contacts',
    'com.google.android.contacts',
    'com.android.providers.contacts',
    'com.android.mms',
    'com.samsung.android.messaging',
    'com.google.android.apps.messaging',
    'com.android.providers.telephony',
    'com.android.camera',
    'com.android.camera2',
    'com.sec.android.app.camera',
    'com.samsung.android.app.camera',
    'com.google.android.GoogleCamera',
    'com.samsung.android.cameralite',
    'com.android.calculator2',
    'com.sec.android.app.popupcalculator',
    'com.samsung.android.calculator',
    'com.google.android.calculator',
    'com.android.deskclock',
    'com.sec.android.app.clockpackage',
    'com.samsung.android.app.clockpackage',
    'com.google.android.deskclock',
    'com.android.documentsui',
    'com.android.providers.downloads',
    'com.android.providers.downloads.ui',
    'com.android.providers.media',
    'com.android.externalstorage',
    'com.sec.android.app.myfiles',
    'com.google.android.apps.nbu.files',
    'com.samsung.android.app.myfiles',
  };

  bool _isAlwaysAllowedApp(String packageName) {
    final pkg = packageName.toLowerCase();

    if (_systemPackages.contains(pkg)) return true;

    // Fallback keyword search for custom vendor names
    for (final kw in _alwaysAllowedKeywords) {
      if (pkg.contains(kw)) {
        if (pkg.contains('systemui') || pkg.contains('keyboard') || pkg.contains('launcher') || pkg.contains('settings')) {
          continue;
        }
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider(true));
    final allowedAppsAsync = ref.watch(allowedAppsProvider);
    final allowedApps = allowedAppsAsync.valueOrNull ?? const <AllowedApp>[];
    final allowedPackages = allowedApps.map((app) => app.packageName).toSet();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RouteNames.home);
      },
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(context),
            appsAsync.when(
              data: (apps) {
                final filtered = apps
                    .where((app) => app.appName
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase()))
                    .toList();

                final alwaysAllowedSection = <AllowedApp>[];
                final thirdPartySection = <AllowedApp>[];

                for (final app in filtered) {
                  if (_isAlwaysAllowedApp(app.packageName)) {
                    alwaysAllowedSection.add(app);
                  } else {
                    thirdPartySection.add(app);
                  }
                }

                final isFocusActive = ref.watch(focusModeProvider);
                final items = <_ListItem>[];

                if (alwaysAllowedSection.isNotEmpty) {
                  items.add(_ListItem.header(isSystem: true));
                  for (final app in alwaysAllowedSection) {
                    items.add(_ListItem.app(app, isSystem: true));
                  }
                }
                if (thirdPartySection.isNotEmpty) {
                  items.add(_ListItem.header(isSystem: false));
                  for (final app in thirdPartySection) {
                    items.add(_ListItem.app(app, isSystem: false));
                  }
                }

                return Expanded(
                  child: Column(
                    children: [
                      _buildStats(context, apps.length, allowedPackages.length),
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmptyState(context)
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  if (item.isHeader) {
                                    return _buildSectionHeader(context, isSystem: item.isSystem);
                                  }
                                  final app = item.app!;
                                  if (item.isSystem) {
                                    return _AppTile(
                                      app: app,
                                      isAllowed: true,
                                      isSystemAlwaysAllowed: true,
                                      onToggle: (_) {},
                                    );
                                  }
                                  final isAllowed = allowedPackages.contains(app.packageName);
                                  return _AppTile(
                                    app: app,
                                    isAllowed: isAllowed,
                                    showLock: isFocusActive,
                                    onToggle: (val) async {
                                      final authService = ref.read(authorizationServiceProvider);
                                      final canEdit = await authService.canEditAllowedApps(isFocusActive: isFocusActive);

                                      final action = () async {
                                        await ref
                                            .read(allowedAppsControllerProvider)
                                            .toggleAllowedApp(app, val);
                                      };

                                      if (canEdit) {
                                        await action();
                                      } else {
                                        if (context.mounted) {
                                          await ref
                                              .read(adminAuthProvider.notifier)
                                              .runProtectedAction(context, action);
                                        }
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Expanded(child: Center(child: Text('Error loading apps: $e'))),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required bool isSystem}) {
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            const Icon(Icons.security_rounded, size: 16, color: Color(0xFF5E6AD2)),
            const SizedBox(width: 8),
            Text(
              'ALWAYS ALLOWED',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: const Color(0xFF5E6AD2).withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(Icons.apps_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            'THIRD-PARTY APPS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allowed Apps',
                  style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Apps permitted during Focus Mode',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(installedAppsProvider(true));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search apps...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, int totalApps, int allowedCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _ChipStat(
            label: '$allowedCount Allowed',
            color: const Color(0xFF4CAF7D),
          ),
          const SizedBox(width: 8),
          _ChipStat(
            label: '${totalApps - allowedCount} Blocked',
            color: const Color(0xFFCF6679),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'No apps found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChipStat extends StatelessWidget {
  const _ChipStat({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.isAllowed,
    required this.onToggle,
    this.showLock = false,
    this.isSystemAlwaysAllowed = false,
  });

  final AllowedApp app;
  final bool isAllowed;
  final ValueChanged<bool> onToggle;
  final bool showLock;
  final bool isSystemAlwaysAllowed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSystemAlwaysAllowed
                    ? const Color(0xFF5E6AD2).withValues(alpha: 0.12)
                    : (isAllowed ? const Color(0xFF4CAF7D).withValues(alpha: 0.12) : cs.surfaceContainerHighest),
                borderRadius: BorderRadius.circular(12),
              ),
              child: app.icon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        app.icon!,
                        fit: BoxFit.cover,
                        cacheWidth: 88,
                        cacheHeight: 88,
                        gaplessPlayback: true,
                      ),
                    )
                  : Icon(
                      Icons.android_rounded,
                      color: isSystemAlwaysAllowed
                          ? const Color(0xFF5E6AD2)
                          : (isAllowed ? const Color(0xFF4CAF7D) : cs.onSurfaceVariant),
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.appName,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    app.packageName,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSystemAlwaysAllowed) ...[
              const Icon(Icons.lock_outline_rounded, color: Color(0xFF5E6AD2), size: 18),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF5E6AD2).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SYSTEM',
                  style: TextStyle(
                    color: Color(0xFF5E6AD2),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ] else ...[
              if (showLock) ...[
                const Icon(Icons.lock_rounded, color: Color(0xFFFFB867), size: 18),
                const SizedBox(width: 8),
              ],
              Switch(
                value: isAllowed,
                onChanged: onToggle,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return const Color(0xFF9E9E9E);
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return const Color(0xFF5E6AD2);
                  return const Color(0xFF2C2C2E);
                }),
                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.transparent;
                  return const Color(0xFF4A4A4C);
                }),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

/// Lightweight descriptor for items in the flat list (header or app tile).
class _ListItem {
  final bool isHeader;
  final bool isSystem;
  final AllowedApp? app;

  const _ListItem._({required this.isHeader, required this.isSystem, this.app});

  factory _ListItem.header({required bool isSystem}) =>
      _ListItem._(isHeader: true, isSystem: isSystem);

  factory _ListItem.app(AllowedApp app, {required bool isSystem}) =>
      _ListItem._(isHeader: false, isSystem: isSystem, app: app);
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/allowed_app.dart';
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

  bool _isAlwaysAllowedApp(String packageName) {
    final pkg = packageName.toLowerCase();
    
    // Exact package names check matching native implementation
    final incallPackages = {
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

    if (incallPackages.contains(pkg)) return true;

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

    return Scaffold(
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

                return Expanded(
                  child: Column(
                    children: [
                      _buildStats(context, apps.length, allowedPackages.length),
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmptyState(context)
                            : ListView(
                                padding: const EdgeInsets.only(bottom: 100),
                                children: [
                                  if (alwaysAllowedSection.isNotEmpty) ...[
                                    Padding(
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
                                              color: const Color(0xFF5E6AD2).withOpacity(0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...alwaysAllowedSection.map((app) {
                                      return _AppTile(
                                        app: app,
                                        isAllowed: true,
                                        isSystemAlwaysAllowed: true,
                                        onToggle: (_) {},
                                      );
                                    }),
                                  ],
                                  if (thirdPartySection.isNotEmpty) ...[
                                    Padding(
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
                                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...thirdPartySection.map((app) {
                                      final isAllowed = allowedPackages.contains(app.packageName);
                                      final isFocusActive = ref.watch(focusModeProvider);
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
                                    }),
                                  ],
                                ],
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
    ).animate().fadeIn(duration: 400.ms);
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
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
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
        color: color.withOpacity(0.12),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSystemAlwaysAllowed
                    ? const Color(0xFF5E6AD2).withOpacity(0.12)
                    : (isAllowed ? const Color(0xFF4CAF7D).withOpacity(0.12) : cs.surfaceVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: app.icon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        app.icon!,
                        fit: BoxFit.cover,
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
                  color: const Color(0xFF5E6AD2).withOpacity(0.12),
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

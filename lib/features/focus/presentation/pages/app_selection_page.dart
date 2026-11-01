import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/focus_tokens.dart';
import '../../../../domain/models/routine.dart';
import '../../../../domain/models/time_slot.dart';
import '../../../../services/native_bridge_service.dart';

class AppSelectionPage extends ConsumerStatefulWidget {
  const AppSelectionPage({
    super.key,
    this.mode = 'quick',
    this.durationMinutes = 30,
    this.existingRoutine,
  });

  /// Mode: 'quick' or 'routine'
  final String mode;

  /// Duration in minutes if mode == 'quick'
  final int durationMinutes;

  /// Existing routine if editing in mode == 'routine'
  final Routine? existingRoutine;

  @override
  ConsumerState<AppSelectionPage> createState() => _AppSelectionPageState();
}

class _AppSelectionPageState extends ConsumerState<AppSelectionPage> {
  final _searchController = TextEditingController();
  final Set<String> _selectedPackages = {};
  String _searchQuery = '';
  bool _isSaving = false;

  // Known distracting social & entertainment apps
  static const Set<String> _distractingPresets = {
    'com.instagram.android',
    'com.zhiliaoapp.musically', // TikTok
    'com.google.android.youtube',
    'com.facebook.katana',
    'com.twitter.android',
    'com.snapchat.android',
    'com.reddit.frontpage',
    'com.netflix.mediaclient',
    'tv.twitch.android.app',
    'com.pinterest',
    'org.telegram.messenger',
    'com.discord',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialSelection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSelection() async {
    final native = ref.read(nativeBridgeServiceProvider);
    final storage = ref.read(storageServiceProvider);

    // If editing existing routine, load routine packages or last blocked packages
    final lastSaved = storage.get<List<dynamic>>(
      AppConstants.settingsBox,
      AppConstants.lastBlockedPackagesKey,
    );

    final currentlyBlocked = await native.getBlockedPackages();

    if (mounted) {
      setState(() {
        if (currentlyBlocked.isNotEmpty) {
          _selectedPackages.addAll(currentlyBlocked);
        } else if (lastSaved != null && lastSaved.isNotEmpty) {
          _selectedPackages.addAll(lastSaved.map((e) => e.toString()));
        }
      });
    }
  }

  void _togglePackage(String packageName) {
    setState(() {
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });
  }

  void _selectAll(List<AppInfo> apps) {
    setState(() {
      _selectedPackages.addAll(apps.map((a) => a.packageName));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedPackages.clear();
    });
  }

  void _selectDistractingPresets(List<AppInfo> apps) {
    setState(() {
      for (final app in apps) {
        if (_distractingPresets.contains(app.packageName)) {
          _selectedPackages.add(app.packageName);
        }
      }
    });
  }

  Future<void> _handleConfirm(List<AppInfo> apps) async {
    if (_selectedPackages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 app to block.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Ensure Accessibility Service is enabled before starting a block
    final native = ref.read(nativeBridgeServiceProvider);
    final isEnabled = await native.isServiceEnabled();
    if (!isEnabled) {
      if (!mounted) return;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: FocusTokens.surface,
          title: const Row(
            children: [
              Icon(Icons.accessibility_new_rounded, color: FocusTokens.danger),
              SizedBox(width: 8),
              Expanded(child: Text('Accessibility Required', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            ],
          ),
          content: const Text(
            'Detox requires the Accessibility Service to detect and block apps.\n\n'
            'Please turn on Detox in Accessibility Settings first.',
            style: TextStyle(fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: FocusTokens.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (openSettings == true) {
        await native.openAccessibilitySettings();
      }
      return;
    }

    final packagesList = _selectedPackages.toList();

    // Persist as last selection for future convenience
    final storage = ref.read(storageServiceProvider);
    await storage.put(
      AppConstants.settingsBox,
      AppConstants.lastBlockedPackagesKey,
      packagesList,
    );

    if (widget.mode == 'quick') {
      await _startQuickFocus(packagesList);
    } else {
      await _configureAndSaveRoutine(packagesList);
    }
  }

  Future<void> _startQuickFocus(List<String> packages) async {
    setState(() => _isSaving = true);
    final native = ref.read(nativeBridgeServiceProvider);

    try {
      final endTime = DateTime.now().add(Duration(minutes: widget.durationMinutes));
      await native.startSession(
        endTime: endTime,
        packages: packages,
      );

      // Invalidate focus session provider to trigger immediate UI refresh
      ref.invalidate(focusSessionProvider);

      if (mounted) {
        context.go(RouteNames.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start focus session: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _configureAndSaveRoutine(List<String> packages) async {
    // Show routine configuration bottom sheet
    final result = await showModalBottomSheet<_RoutineConfigResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FocusTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RoutineConfigSheet(existingRoutine: widget.existingRoutine),
    );

    if (result == null) return;

    setState(() => _isSaving = true);

    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      final routinesNotifier = ref.read(routinesProvider.notifier);

      if (widget.existingRoutine != null) {
        final updated = widget.existingRoutine!.copyWith(
          label: result.label,
          weekdays: result.weekdays,
          startTime: result.startTime,
          endTime: result.endTime,
          slots: [
            TimeSlot(
              startHour: result.startTime.hour,
              startMinute: result.startTime.minute,
              endHour: result.endTime.hour,
              endMinute: result.endTime.minute,
            ),
          ],
        );
        await routinesNotifier.updateRoutine(updated);
      } else {
        await scheduleService.addRoutine(
          label: result.label,
          weekdays: result.weekdays,
          startTime: result.startTime,
          endTime: result.endTime,
          slots: [
            TimeSlot(
              startHour: result.startTime.hour,
              startMinute: result.startTime.minute,
              endHour: result.endTime.hour,
              endMinute: result.endTime.minute,
            ),
          ],
        );
        await routinesNotifier.loadRoutines();
      }

      if (mounted) {
        context.go(RouteNames.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save routine: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final installedAppsAsync = ref.watch(installedAppsProvider);

    return Scaffold(
      backgroundColor: FocusTokens.canvas,
      appBar: AppBar(
        title: Text(
          widget.mode == 'quick' ? 'Quick Focus: Block Apps' : 'Routine: Block Apps',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: FocusTokens.ink,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: installedAppsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading installed applications...',
                style: TextStyle(color: FocusTokens.inkMuted, fontSize: 14),
              ),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: FocusTokens.danger, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Failed to load applications:\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: FocusTokens.inkMuted),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(installedAppsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (apps) {
          // Filter out our own app package
          final usableApps = apps.where(
            (app) => app.packageName != AppConstants.packageName,
          ).toList();

          final query = _searchQuery.trim().toLowerCase();
          final filteredApps = usableApps.where((app) {
            if (query.isEmpty) return true;
            return app.appName.toLowerCase().contains(query) ||
                app.packageName.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search installed apps...',
                        hintStyle: const TextStyle(color: FocusTokens.inkMuted, fontSize: 14),
                        filled: true,
                        fillColor: FocusTokens.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: FocusTokens.inkMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Select Action Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'Social & Media',
                            icon: Icons.auto_awesome_rounded,
                            onTap: () => _selectDistractingPresets(usableApps),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Select All (${usableApps.length})',
                            icon: Icons.select_all_rounded,
                            onTap: () => _selectAll(usableApps),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Deselect All',
                            icon: Icons.deselect_rounded,
                            onTap: _deselectAll,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Selection Stats Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: FocusTokens.elevated,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedPackages.length} of ${usableApps.length} apps will be BLOCKED',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: FocusTokens.ink,
                      ),
                    ),
                    if (_selectedPackages.isNotEmpty)
                      const Text(
                        'Policy active on OK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: FocusTokens.primary,
                        ),
                      ),
                  ],
                ),
              ),

              // App List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filteredApps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final app = filteredApps[index];
                    final isBlocked = _selectedPackages.contains(app.packageName);

                    return Material(
                      color: FocusTokens.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => _togglePackage(app.packageName),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              // App Icon
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: FocusTokens.elevated,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: app.icon != null
                                    ? Image.memory(
                                        app.icon!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.apps_rounded,
                                          color: FocusTokens.inkMuted,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.apps_rounded,
                                        color: FocusTokens.inkMuted,
                                      ),
                              ),
                              const SizedBox(width: 14),

                              // App Title & Package
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.appName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: FocusTokens.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      app.packageName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: FocusTokens.inkMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Block Status Tag / Checkbox
                              Checkbox(
                                value: isBlocked,
                                activeColor: FocusTokens.danger,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                onChanged: (_) => _togglePackage(app.packageName),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Confirmation Bar
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: FocusTokens.surface,
                    boxShadow: FocusTokens.shadowSoft,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () => _handleConfirm(usableApps),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FocusTokens.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: FocusTokens.borderRadiusButton,
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.mode == 'quick'
                                  ? 'OK — Begin Focus (${widget.durationMinutes}m)'
                                  : 'OK — Set Routine',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: FocusTokens.primary),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: FocusTokens.ink),
      ),
      backgroundColor: FocusTokens.surface,
      side: const BorderSide(color: FocusTokens.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
    );
  }
}

// ── Routine Configuration Bottom Sheet ───────────────────────────────────────

class _RoutineConfigResult {
  final String label;
  final List<int> weekdays;
  final DateTime startTime;
  final DateTime endTime;

  _RoutineConfigResult({
    required this.label,
    required this.weekdays,
    required this.startTime,
    required this.endTime,
  });
}

class _RoutineConfigSheet extends StatefulWidget {
  const _RoutineConfigSheet({this.existingRoutine});

  final Routine? existingRoutine;

  @override
  State<_RoutineConfigSheet> createState() => _RoutineConfigSheetState();
}

class _RoutineConfigSheetState extends State<_RoutineConfigSheet> {
  late final TextEditingController _labelController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late final Set<int> _selectedDays;

  static const List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final r = widget.existingRoutine;
    _labelController = TextEditingController(text: r?.label ?? 'Focus Hours');
    _startTime = r != null
        ? TimeOfDay(hour: r.startTime.hour, minute: r.startTime.minute)
        : const TimeOfDay(hour: 9, minute: 0);
    _endTime = r != null
        ? TimeOfDay(hour: r.endTime.hour, minute: r.endTime.minute)
        : const TimeOfDay(hour: 17, minute: 0);
    _selectedDays = r != null ? r.weekdays.toSet() : {0, 1, 2, 3, 4}; // Mon-Fri default
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  void _save() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine label.')),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day.')),
      );
      return;
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, _startTime.hour, _startTime.minute);
    final end = DateTime(now.year, now.month, now.day, _endTime.hour, _endTime.minute);

    Navigator.of(context).pop(
      _RoutineConfigResult(
        label: label,
        weekdays: _selectedDays.toList()..sort(),
        startTime: start,
        endTime: end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Schedule Routine',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: FocusTokens.ink,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Label
          const Text(
            'Routine Name',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FocusTokens.ink),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              hintText: 'e.g. Work Deep Focus, Sleep Lock, Study',
              filled: true,
              fillColor: FocusTokens.elevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time pickers
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickStartTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: FocusTokens.elevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 18, color: FocusTokens.primary),
                            const SizedBox(width: 8),
                            Text(
                              _startTime.format(context),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('End Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickEndTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: FocusTokens.elevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, size: 18, color: FocusTokens.primary),
                            const SizedBox(width: 8),
                            Text(
                              _endTime.format(context),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Days of Week
          const Text('Repeat Days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isSelected = _selectedDays.contains(index);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(index);
                    } else {
                      _selectedDays.add(index);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? FocusTokens.primary : FocusTokens.elevated,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _dayNames[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : FocusTokens.inkMuted,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Confirm Button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: FocusTokens.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: FocusTokens.borderRadiusButton,
                ),
                elevation: 0,
              ),
              child: const Text(
                'Save Routine',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../widgets/section_header.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/schedule_providers.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/admin_auth_provider.dart';
import '../../../../core/providers/focus_providers.dart';
import '../../../../domain/models/routine.dart';
import '../../../../domain/models/time_slot.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RouteNames.home);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Active Routines',
                subtitle: 'Automate multiple focus session slots across your week',
                trailing: TextButton.icon(
                  onPressed: () => _showAddOrEditRoutineSheet(context, ref),
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF5E6AD2)),
                  label: const Text(
                    'Add Routine',
                    style: TextStyle(
                      color: Color(0xFF5E6AD2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            routinesAsync.when(
              data: (routines) {
                if (routines.isEmpty) {
                  return SliverToBoxAdapter(child: _buildEmptyState(context, ref));
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final routine = routines[index];
                      return _RoutineCard(
                        routine: routine,
                        onToggle: (val) async {
                          final isFocusActive = ref.read(focusModeProvider);
                          final activeSnapshot = ref.read(activeSessionSnapshotProvider);
                          final isThisRoutineActive = isFocusActive && activeSnapshot?.scheduleId == routine.id;

                          if (isThisRoutineActive) {
                            // Toggling the CURRENTLY RUNNING routine requires admin auth
                            await ref.read(adminAuthProvider.notifier).runProtectedAction(context, () {
                              ref.read(routinesProvider.notifier).toggleRoutine(routine.id, val);
                            });
                          } else {
                            // Future routine — no password needed
                            ref.read(routinesProvider.notifier).toggleRoutine(routine.id, val);
                          }
                        },
                        onEdit: () async {
                          final isFocusActive = ref.read(focusModeProvider);
                          final activeSnapshot = ref.read(activeSessionSnapshotProvider);
                          final isThisRoutineActive = isFocusActive && activeSnapshot?.scheduleId == routine.id;

                          if (isThisRoutineActive) {
                            // Editing the CURRENTLY RUNNING routine requires admin auth
                            await ref.read(adminAuthProvider.notifier).runProtectedAction(context, () {
                              _showAddOrEditRoutineSheet(context, ref, existing: routine);
                            });
                          } else {
                            // Future routine — open editor directly
                            _showAddOrEditRoutineSheet(context, ref, existing: routine);
                          }
                        },
                        onDelete: () async {
                          final isFocusActive = ref.read(focusModeProvider);
                          final activeSnapshot = ref.read(activeSessionSnapshotProvider);
                          final isThisRoutineActive = isFocusActive && activeSnapshot?.scheduleId == routine.id;

                          if (isThisRoutineActive) {
                            // Deleting the CURRENTLY RUNNING routine requires admin auth
                            await ref.read(adminAuthProvider.notifier).runProtectedAction(context, () {
                              ref.read(routinesProvider.notifier).deleteRoutine(routine.id);
                            });
                          } else {
                            // Future routine — delete directly
                            ref.read(routinesProvider.notifier).deleteRoutine(routine.id);
                          }
                        },
                      );
                    },
                    childCount: routines.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error loading routines: $e')),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFFE3E2E2),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Automate your focus sessions with recurring daily time slots',
            style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.event_repeat_rounded, size: 72, color: const Color(0xFFC6C5D5).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No routines yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE3E2E2)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a routine with custom daily session timings',
              style: TextStyle(fontSize: 13, color: Color(0xFFC6C5D5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E6AD2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _showAddOrEditRoutineSheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Routine'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrEditRoutineSheet(BuildContext context, WidgetRef ref, {Routine? existing}) {
    // Creating or editing a FUTURE routine requires NO password.
    // Password is only required when modifying an ACTIVE Focus Session.
    showModalBottomSheet<Routine>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditRoutineSheet(existingRoutine: existing),
    ).then((routine) async {
      if (routine == null) return;

      // Check for schedule overlap before saving
      final scheduleService = ref.read(scheduleServiceProvider);
      final hasOverlap = await scheduleService.hasOverlappingRoutines(routine);

      if (hasOverlap && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This routine overlaps with an existing enabled routine. Please adjust the time or days.'),
            backgroundColor: Color(0xFFCF6679),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (existing != null) {
        ref.read(routinesProvider.notifier).updateRoutine(routine);
      } else {
        ref.read(routinesProvider.notifier).addRoutine(routine);
      }
    });
  }
}

// ── Routine Card ────────────────────────────────────────────────────────────

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Routine routine;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final isActive = routine.enabled;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF212123),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? const Color(0xFF5E6AD2).withValues(alpha: 0.4) : const Color(0xFF2C2C2E),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header + Switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF5E6AD2).withValues(alpha: 0.15) : const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: isActive ? const Color(0xFF5E6AD2) : const Color(0xFFC6C5D5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.label.isNotEmpty ? routine.label : 'Routine',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE3E2E2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${routine.slots.length} session timing${routine.slots.length > 1 ? 's' : ''} per day',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFC6C5D5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: routine.enabled,
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
          ),
          const SizedBox(height: 16),

          // Row 2: Time Slots List
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: routine.slots.map((slot) {
              final isOvernight = slot.startHour > slot.endHour ||
                  (slot.startHour == slot.endHour && slot.startMinute > slot.endMinute);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF18191B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2E), width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOvernight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      size: 14,
                      color: isOvernight ? const Color(0xFFFFB867) : const Color(0xFF4CAF7D),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      slot.format(context),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE3E2E2),
                      ),
                    ),
                    if (isOvernight) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB867).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Overnight',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFB867),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Row 3: Weekday Chips + Action Buttons
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(7, (i) {
                      final selected = routine.weekdays.contains(i);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF5E6AD2) : const Color(0xFF18191B),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? const Color(0xFF5E6AD2) : const Color(0xFF2C2C2E),
                            ),
                          ),
                          child: Text(
                            _dayLabels[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : const Color(0xFFC6C5D5),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: const Color(0xFFC6C5D5),
                onPressed: onEdit,
                tooltip: 'Edit Routine',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: const Color(0xFFCF6679),
                onPressed: onDelete,
                tooltip: 'Delete Routine',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add/Edit Routine Sheet ──────────────────────────────────────────────────

class _AddEditRoutineSheet extends StatefulWidget {
  const _AddEditRoutineSheet({this.existingRoutine});

  final Routine? existingRoutine;

  @override
  State<_AddEditRoutineSheet> createState() => _AddEditRoutineSheetState();
}

class _AddEditRoutineSheetState extends State<_AddEditRoutineSheet> {
  late TextEditingController _labelController;
  late Set<int> _selectedDays;
  late List<TimeSlot> _slots;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final r = widget.existingRoutine;
    _labelController = TextEditingController(text: r?.label ?? 'My Routine');
    _selectedDays = Set<int>.from(r?.weekdays ?? [0, 1, 2, 3, 4, 5, 6]);
    _slots = r != null && r.slots.isNotEmpty
        ? r.slots.map((s) => s.copyWith()).toList()
        : [
            TimeSlot(startHour: 23, startMinute: 0, endHour: 9, endMinute: 0),
          ];
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _addSlot() {
    setState(() {
      _slots.add(TimeSlot(startHour: 10, startMinute: 0, endHour: 14, endMinute: 0));
    });
  }

  void _removeSlot(int index) {
    if (_slots.length > 1) {
      setState(() {
        _slots.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1F22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Text(
                    widget.existingRoutine != null ? 'Edit Routine' : 'New Routine',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE3E2E2),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFFC6C5D5)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2C2C2E), height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  // Routine Title
                  TextField(
                    controller: _labelController,
                    style: const TextStyle(color: Color(0xFFE3E2E2)),
                    decoration: InputDecoration(
                      labelText: 'Routine Label',
                      labelStyle: const TextStyle(color: Color(0xFFC6C5D5)),
                      prefixIcon: const Icon(Icons.label_outline_rounded, color: Color(0xFF5E6AD2)),
                      filled: true,
                      fillColor: const Color(0xFF18191B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Session Timings Header
                  Row(
                    children: [
                      const Icon(Icons.access_time_filled_rounded, size: 20, color: Color(0xFFFFB867)),
                      const SizedBox(width: 8),
                      const Text(
                        'Session Timings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE3E2E2),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addSlot,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Timing'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF5E6AD2)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Time Slots List
                  for (int i = 0; i < _slots.length; i++) ...[
                    _buildTimeSlotRow(i),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 24),

                  // Repeat Days Section
                  const Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF5E6AD2)),
                      SizedBox(width: 8),
                      Text(
                        'Active Days',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE3E2E2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Day Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (i) {
                      final sel = _selectedDays.contains(i);
                      return FilterChip(
                        label: Text(_dayLabels[i]),
                        selected: sel,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _selectedDays.add(i);
                          } else {
                            if (_selectedDays.length > 1) {
                              _selectedDays.remove(i);
                            }
                          }
                        }),
                        selectedColor: const Color(0xFF5E6AD2),
                        backgroundColor: const Color(0xFF18191B),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : const Color(0xFFC6C5D5),
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: sel ? const Color(0xFF5E6AD2) : const Color(0xFF2C2C2E),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  // Day Quick Presets
                  Row(
                    children: [
                      _buildPresetChip('Every Day', () {
                        setState(() => _selectedDays = {0, 1, 2, 3, 4, 5, 6});
                      }),
                      const SizedBox(width: 8),
                      _buildPresetChip('Mon-Fri', () {
                        setState(() => _selectedDays = {0, 1, 2, 3, 4});
                      }),
                      const SizedBox(width: 8),
                      _buildPresetChip('Weekends', () {
                        setState(() => _selectedDays = {5, 6});
                      }),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Save Routine Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5E6AD2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final now = DateTime.now();
                        final firstSlot = _slots.first;
                        final startDT = DateTime(now.year, now.month, now.day, firstSlot.startHour, firstSlot.startMinute);
                        final endDT = DateTime(now.year, now.month, now.day, firstSlot.endHour, firstSlot.endMinute);

                        final routine = Routine(
                          id: widget.existingRoutine?.id ?? '',
                          label: _labelController.text.trim().isNotEmpty
                              ? _labelController.text.trim()
                              : 'My Routine',
                          weekdays: _selectedDays.toList()..sort(),
                          startTime: startDT,
                          endTime: endDT,
                          enabled: widget.existingRoutine?.enabled ?? true,
                          slots: _slots,
                        );

                        Navigator.pop(context, routine);
                      },
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(
                        widget.existingRoutine != null ? 'Save Changes' : 'Create Routine',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotRow(int index) {
    final slot = _slots[index];
    final startTime = TimeOfDay(hour: slot.startHour, minute: slot.startMinute);
    final endTime = TimeOfDay(hour: slot.endHour, minute: slot.endMinute);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18191B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Timing Slot #${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFB867),
                ),
              ),
              const Spacer(),
              if (_slots.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                  color: const Color(0xFFCF6679),
                  onPressed: () => _removeSlot(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeSlotPickerButton(
                  label: 'Start Time',
                  time: startTime,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                    );
                    if (t != null) {
                      setState(() {
                        _slots[index] = slot.copyWith(startHour: t.hour, startMinute: t.minute);
                      });
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('to', style: TextStyle(color: Color(0xFFC6C5D5), fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: _TimeSlotPickerButton(
                  label: 'End Time',
                  time: endTime,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: endTime,
                    );
                    if (t != null) {
                      setState(() {
                        _slots[index] = slot.copyWith(endHour: t.hour, endMinute: t.minute);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFFC6C5D5), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _TimeSlotPickerButton extends StatelessWidget {
  const _TimeSlotPickerButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF212123),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFFC6C5D5)),
            ),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE3E2E2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

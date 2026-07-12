import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hidden diagnostics screen accessible via 7 rapid taps on the app version
/// in Settings. Displays comprehensive system state for debugging.
class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  static const _channel =
      MethodChannel('com.personal.phone_addiction_controller/accessibility');

  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDiagnosticsData',
      );
      if (result == null) throw Exception('No data returned');

      final data = Map<String, dynamic>.from(result);

      // Parse events JSON
      final eventsRaw = data['allEvents'] as String? ?? '[]';
      final eventsList = jsonDecode(eventsRaw) as List;
      final events = eventsList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
          .reversed
          .toList(); // newest first

      setState(() {
        _data = data;
        _events = events;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'System Diagnostics',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        backgroundColor: const Color(0xFF0A0A0A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5E6AD2)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(color: Color(0xFFCF6679)),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDiagnostics,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSectionTitle('Core System'),
                      _buildStatusCard([
                        _statusRow(
                          'Device Owner',
                          _data['isDeviceOwner'] == true,
                        ),
                        _statusRow(
                          'Lock Task',
                          (_data['lockTaskState'] as int? ?? 0) != 0,
                          trueLabel: 'Active',
                          falseLabel: 'Inactive',
                        ),
                        _statusRow(
                          'Accessibility Service',
                          _data['isAccessibilityRunning'] == true,
                          trueLabel: 'Running',
                          falseLabel: 'Stopped',
                        ),
                        _statusRow(
                          'Foreground Service',
                          _data['isForegroundServiceRunning'] == true,
                          trueLabel: 'Running',
                          falseLabel: 'Stopped',
                        ),
                        _statusRow(
                          'Battery Opt. Disabled',
                          _data['isBatteryOptimizationDisabled'] == true,
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Focus Session'),
                      _buildStatusCard([
                        _infoRow(
                          'Active Session',
                          _data['isFocusActive'] == true ? 'Yes' : 'No',
                        ),
                        _infoRow(
                          'Scheduled',
                          _data['isScheduled'] == true ? 'Yes' : 'No',
                        ),
                        _infoRow(
                          'Strict Mode',
                          _data['strictMode'] == true ? 'Yes' : 'No',
                        ),
                        _infoRow(
                          'Active Routine ID',
                          _truncate(_data['activeRoutineId']?.toString() ?? 'None', 20),
                        ),
                        _infoRow(
                          'Session Start',
                          _formatTimestamp(_data['sessionStartTime'] as int? ?? 0),
                        ),
                        _infoRow(
                          'Scheduled End',
                          _formatTimestamp(_data['scheduledEndTime'] as int? ?? 0),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Recovery & Monitoring'),
                      _buildStatusCard([
                        _infoRow(
                          'Last Boot Time',
                          _formatTimestamp(_data['lastBootTime'] as int? ?? 0),
                        ),
                        _infoRow(
                          'Last Watchdog Repair',
                          _formatPipeDelimited(_data['lastWatchdogRepair']?.toString() ?? ''),
                        ),
                        _infoRow(
                          'Last Blocked App',
                          _formatPipeDelimited(_data['lastBlockedApp']?.toString() ?? ''),
                        ),
                        _infoRow(
                          'Last Recovery Event',
                          _formatPipeDelimited(_data['lastRecoveryEvent']?.toString() ?? ''),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Event Log (${_events.length})'),
                      ..._events.take(50).map(_buildEventRow),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF5E6AD2).withValues(alpha: 0.8),
          fontFamily: 'monospace',
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildStatusCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151517),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(children: children),
    );
  }

  Widget _statusRow(String label, bool value,
      {String trueLabel = '✅', String falseLabel = '❌'}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC6C5D5),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFF4CAF7D).withValues(alpha: 0.15)
                  : const Color(0xFFCF6679).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value ? trueLabel : falseLabel,
              style: TextStyle(
                color: value ? const Color(0xFF4CAF7D) : const Color(0xFFCF6679),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC6C5D5),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFE3E2E2),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventRow(Map<String, dynamic> event) {
    final ts = event['ts'] as int? ?? 0;
    final cat = event['cat'] as String? ?? '';
    final evt = event['evt'] as String? ?? '';
    final msg = event['msg'] as String? ?? '';

    Color catColor;
    switch (cat) {
      case 'ROUTINE':
        catColor = const Color(0xFF5E6AD2);
        break;
      case 'WATCHDOG':
        catColor = const Color(0xFFFFB74D);
        break;
      case 'BOOT':
        catColor = const Color(0xFF4CAF7D);
        break;
      case 'SERVICE':
        catColor = const Color(0xFF42A5F5);
        break;
      case 'SESSION':
        catColor = const Color(0xFFAB47BC);
        break;
      default:
        catColor = const Color(0xFFC6C5D5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151517),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E1E20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: catColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                evt,
                style: const TextStyle(
                  color: Color(0xFFE3E2E2),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(ts),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              msg,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(int epochMs) {
    if (epochMs <= 0) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatPipeDelimited(String value) {
    if (value.isEmpty) return 'None';
    final parts = value.split('|');
    if (parts.length >= 2) {
      final ts = int.tryParse(parts.last);
      if (ts != null) {
        return '${parts.take(parts.length - 1).join(' ')} (${_formatTimestamp(ts)})';
      }
    }
    return value;
  }

  String _truncate(String value, int maxLen) {
    if (value.length <= maxLen) return value;
    return '${value.substring(0, maxLen)}…';
  }
}

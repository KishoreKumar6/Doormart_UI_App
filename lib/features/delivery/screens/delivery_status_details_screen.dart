import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/delivery_provider.dart';

class DeliveryStatusDetailsScreen extends StatefulWidget {
  const DeliveryStatusDetailsScreen({super.key});
  static const routeName = '/delivery/status-details';

  @override
  State<DeliveryStatusDetailsScreen> createState() =>
      _DeliveryStatusDetailsScreenState();
}

class _DeliveryStatusDetailsScreenState
    extends State<DeliveryStatusDetailsScreen> {
  _StatusFilter _filter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeliveryProvider>();
      provider.bootstrap().then((_) => provider.loadStatusDetails());
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final allLogs =
        provider.statusDetails.where((log) => _matches(log, _filter)).toList()
          ..sort((a, b) {
            final aStarted =
                _parseLocalDate(a['startedAt'] as String?) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bStarted =
                _parseLocalDate(b['startedAt'] as String?) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bStarted.compareTo(aStarted);
          });
    final activeLog = allLogs.where(_isActiveLog).toList();
    final completedLogs = allLogs.where((log) => !_isActiveLog(log)).toList();
    final online = provider.online;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Status Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE8541A)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CurrentStatusCard(online: online),
          const SizedBox(height: 16),
          _FilterBar(
            filter: _filter,
            onChanged: (filter) => setState(() => _filter = filter),
          ),
          const SizedBox(height: 16),
          if (activeLog.isNotEmpty) ...[
            const _SectionTitle(title: 'In Progress'),
            const SizedBox(height: 10),
            ...activeLog.map((log) => _StatusLogCard(log: log)),
            const SizedBox(height: 14),
          ],
          if (completedLogs.isNotEmpty) ...[
            const _SectionTitle(title: 'Completed'),
            const SizedBox(height: 10),
            ...completedLogs.map((log) => _StatusLogCard(log: log)),
          ] else if (activeLog.isEmpty)
            const _EmptyState(),
        ],
      ),
    );
  }
}

class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: const Color(0xFFE8541A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Status',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  online ? 'Online right now' : 'Offline right now',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              online ? 'ACTIVE' : 'INACTIVE',
              style: const TextStyle(
                color: Color(0xFFE8541A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});
  final _StatusFilter filter;
  final ValueChanged<_StatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _StatusFilter.values.map((item) {
        final selected = item == filter;
        return ChoiceChip(
          label: Text(item.label),
          selected: selected,
          onSelected: (_) => onChanged(item),
          selectedColor: const Color(0xFFE8541A),
          labelStyle: TextStyle(
            color: selected ? Colors.white : const Color(0xFF1A1A1A),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusLogCard extends StatelessWidget {
  const _StatusLogCard({required this.log});
  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final status = (log['status'] as String? ?? 'offline').toUpperCase();
    final startedAt =
        _parseLocalDate(log['startedAt'] as String?) ?? DateTime.now();
    final endedAt = _parseLocalDate(log['endedAt'] as String?);
    final active = endedAt == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Color(0xFFE8541A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                active ? 'IN PROGRESS' : 'ENDED',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Started: ${_formatDateTime(startedAt)}'),
          Text('Ended: ${active ? 'In progress' : _formatDateTime(endedAt)}'),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text('No status records found', textAlign: TextAlign.center),
    );
  }
}

enum _StatusFilter { all, today, yesterday, week, month, year }

extension on _StatusFilter {
  String get label => switch (this) {
    _StatusFilter.all => 'All',
    _StatusFilter.today => 'Today',
    _StatusFilter.yesterday => 'Yesterday',
    _StatusFilter.week => 'Week',
    _StatusFilter.month => 'Month',
    _StatusFilter.year => 'Year',
  };
}

bool _matches(Map<String, dynamic> log, _StatusFilter filter) {
  if (filter == _StatusFilter.all) return true;
  final startedAt = _parseLocalDate(log['startedAt'] as String?);
  if (startedAt == null) return false;
  final now = DateTime.now();
  return switch (filter) {
    _StatusFilter.today =>
      startedAt.year == now.year &&
          startedAt.month == now.month &&
          startedAt.day == now.day,
    _StatusFilter.yesterday => _isSameDay(
      startedAt,
      now.subtract(const Duration(days: 1)),
    ),
    _StatusFilter.week => _isSameWeek(startedAt, now),
    _StatusFilter.month =>
      startedAt.year == now.year && startedAt.month == now.month,
    _StatusFilter.year => startedAt.year == now.year,
    _StatusFilter.all => true,
  };
}

bool _isActiveLog(Map<String, dynamic> log) {
  return (log['status'] as String? ?? '').toLowerCase() == 'online' &&
      (log['endedAt'] == null || log['endedAt'].toString().trim().isEmpty);
}

String _formatDateTime(DateTime d) {
  final local = d.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month/$year, $hour:$minute $suffix';
}

DateTime? _parseLocalDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isSameWeek(DateTime a, DateTime b) {
  final aDate = DateTime(a.year, a.month, a.day);
  final bDate = DateTime(b.year, b.month, b.day);
  final mondayA = aDate.subtract(Duration(days: aDate.weekday - 1));
  final mondayB = bDate.subtract(Duration(days: bDate.weekday - 1));
  return mondayA.year == mondayB.year &&
      mondayA.month == mondayB.month &&
      mondayA.day == mondayB.day;
}

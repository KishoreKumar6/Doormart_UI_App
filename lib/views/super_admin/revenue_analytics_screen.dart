import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../widgets/animated_chart.dart';
import '../app_page.dart';
import '../admin/admin_logout_confirm.dart';
import '../admin/admin_sidebar_drawer.dart';

const _analyticsPrimary = Color(0xFFE8541A);
const _analyticsOrange = Color(0xFFE8541A);
const _analyticsInk = Color(0xFF1A1A1A);

class RevenueAnalyticsScreen extends StatefulWidget {
  const RevenueAnalyticsScreen({super.key});
  static const routeName = '/super-admin/revenue';

  @override
  State<RevenueAnalyticsScreen> createState() => _RevenueAnalyticsScreenState();
}

class _RevenueAnalyticsScreenState extends State<RevenueAnalyticsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _period = 'month';
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().superAdminOrderAnalytics(_period);
  }

  void _changePeriod(String period) {
    setState(() {
      _period = period;
      _future = context.read<AppState>().superAdminOrderAnalytics(period);
    });
  }

  void _reload() {
    setState(() {
      _future = context.read<AppState>().superAdminOrderAnalytics(_period);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Order analytics',
      scaffoldKey: _scaffoldKey,
      drawer: AdminSidebarDrawer(
        currentRoute: RevenueAnalyticsScreen.routeName,
        onLogout: () async {
          final appState = context.read<AppState>();
          final navigator = Navigator.of(context);
          if (!await confirmAdminLogout(context)) return;
          if (!mounted) return;
          navigator.pop();
          final logoutRoute = appState.logoutRouteName;
          await appState.logout();
          if (!mounted) return;
          navigator.pushNamedAndRemoveUntil(logoutRoute, (_) => false);
        },
      ),
      leading: Builder(
        builder: (ctx) => Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton.filledTonal(
            tooltip: 'Menu',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFFF0EB),
              foregroundColor: _analyticsPrimary,
            ),
            icon: const Icon(Icons.menu),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh analytics',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: [
        _AnalyticsHero(period: _period),
        const SizedBox(height: 16),
        _PeriodSelector(period: _period, onChanged: _changePeriod),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _AnalyticsLoading();
            }
            if (snapshot.hasError) {
              return _AnalyticsError(onRetry: _reload);
            }
            return _AnalyticsContent(data: snapshot.data ?? {});
          },
        ),
      ],
    );
  }
}

class _AnalyticsHero extends StatelessWidget {
  const _AnalyticsHero({required this.period});
  final String period;

  String get _description => switch (period) {
    'day' => 'Hourly order activity for today',
    'yesterday' => 'Hourly order activity for yesterday',
    'week' => 'Daily order activity for this week',
    'year' => 'Monthly order activity for this year',
    _ => 'Daily order activity for this month',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_analyticsPrimary, Color(0xFFC63F12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _analyticsPrimary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Business overview',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Order performance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});
  final String period;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          _PeriodButton(
            label: 'Today',
            value: 'day',
            selected: period == 'day',
            onTap: onChanged,
          ),
          _PeriodButton(
            label: 'Yesterday',
            value: 'yesterday',
            selected: period == 'yesterday',
            onTap: onChanged,
          ),
          _PeriodButton(
            label: 'Week',
            value: 'week',
            selected: period == 'week',
            onTap: onChanged,
          ),
          _PeriodButton(
            label: 'Month',
            value: 'month',
            selected: period == 'month',
            onTap: onChanged,
          ),
          _PeriodButton(
            label: 'Year',
            value: 'year',
            selected: period == 'year',
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _analyticsPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF66706D),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final totalOrders = (data['totalOrders'] as num? ?? 0).toInt();
    final totalRevenue = (data['totalRevenue'] as num? ?? 0).toDouble();
    final delivered = (data['deliveredOrders'] as num? ?? 0).toInt();
    final cancelled = (data['cancelledOrders'] as num? ?? 0).toInt();
    final maxOrders = items.fold<double>(
      0,
      (max, item) => ((item['orders'] as num? ?? 0).toDouble() > max)
          ? (item['orders'] as num).toDouble()
          : max,
    );
    final chartValues = items.map((item) {
      final count = (item['orders'] as num? ?? 0).toDouble();
      return maxOrders == 0 ? 0.0 : (count / maxOrders) * 108;
    }).toList();
    final activeItems = items
        .where((item) => (item['orders'] as num? ?? 0) > 0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.receipt_long_rounded,
                title: 'Orders',
                value: '$totalOrders',
                color: _analyticsPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.currency_rupee_rounded,
                title: 'Revenue',
                value: 'Rs ${totalRevenue.toStringAsFixed(0)}',
                color: _analyticsOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'Delivered',
                value: '$delivered',
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.cancel_outlined,
                title: 'Cancelled',
                value: '$cancelled',
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ChartPanel(items: items, values: chartValues, maxOrders: maxOrders),
        const SizedBox(height: 16),
        _ActivityPanel(items: activeItems),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9ECEB)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF7A8581),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _analyticsInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
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
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.items,
    required this.values,
    required this.maxOrders,
  });
  final List<Map<String, dynamic>> items;
  final List<double> values;
  final double maxOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9ECEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Order volume',
                  style: TextStyle(
                    color: _analyticsInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: _analyticsPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Orders',
                style: TextStyle(
                  color: Color(0xFF7A8581),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            maxOrders == 0
                ? 'No orders in this period'
                : 'Peak: ${maxOrders.toInt()} orders',
            style: const TextStyle(color: Color(0xFF8A9490), fontSize: 12),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 138,
            child: values.isEmpty
                ? const Center(child: Text('No data available'))
                : AnimatedChart(values: values),
          ),
          const SizedBox(height: 8),
          if (items.isNotEmpty)
            Row(
              children: items
                  .map(
                    (item) => Expanded(
                      child: Text(
                        item['label']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF8A9490),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.reversed.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9ECEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity breakdown',
            style: TextStyle(
              color: _analyticsInk,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Periods with completed order activity',
            style: TextStyle(color: Color(0xFF8A9490), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('No orders found for this period')),
            ),
          ...visible.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _analyticsPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['label']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _analyticsInk,
                      ),
                    ),
                  ),
                  Text(
                    '${item['orders'] ?? 0} orders',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _analyticsPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rs ${(item['revenue'] as num? ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF7A8581),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsLoading extends StatelessWidget {
  const _AnalyticsLoading();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      SizedBox(height: 24),
      CircularProgressIndicator(),
      SizedBox(height: 24),
    ],
  );
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFF9CA3AF)),
        const SizedBox(height: 10),
        const Text('Analytics could not be loaded'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

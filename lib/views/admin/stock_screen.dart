import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import 'admin_logout_confirm.dart';
import 'admin_dashboard_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_orders_screen.dart';
import 'manage_banners_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_delivery_screen.dart';
import 'manage_products_screen.dart';
import 'manage_users_screen.dart';
import 'admin_sidebar_drawer.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  static const routeName = '/admin/stock';

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Future<Map<String, dynamic>> _dashboardFuture;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'All';
  int _lastRefreshTick = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _dashboardFuture = context.read<AppState>().adminDashboard();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _dashboardFuture = context.read<AppState>().adminDashboard();
      _lastRefreshTick = context.read<AppState>().dashboardRefreshTick;
      _controller
        ..reset()
        ..forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refreshTick = context.watch<AppState>().dashboardRefreshTick;
    if (refreshTick != _lastRefreshTick) {
      _lastRefreshTick = refreshTick;
      _dashboardFuture = context.read<AppState>().adminDashboard();
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF6F6F6),
      drawer: AdminSidebarDrawer(
        currentRoute: StockScreen.routeName,
        onLogout: () async {
          if (!await confirmAdminLogout(context)) return;
          Navigator.pop(context);
          final logoutRoute = context.read<AppState>().logoutRouteName;
          await context.read<AppState>().logout();
          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            logoutRoute,
            (route) => false,
          );
        },
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: _ErrorCard(
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final lowStockItems = _parseLowStock(snapshot.data!);
            final products = context.watch<AppState>().products;
            final stockRows = _buildStockRows(products, lowStockItems);
            final q = _searchController.text.trim().toLowerCase();
            final visibleRows = stockRows.where((row) {
              final matchesSearch =
                  q.isEmpty ||
                  row.name.toLowerCase().contains(q) ||
                  row.category.toLowerCase().contains(q);
              final matchesFilter = switch (_filter) {
                'All' => true,
                'Low stock' => row.level == 'Low stock',
                'Out of stock' => row.level == 'Out of stock',
                _ => true,
              };
              return matchesSearch && matchesFilter;
            }).toList();

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    _AnimatedIn(
                      animation: _controller,
                      index: 0,
                      child: _StockHero(
                        onOpenMenu: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        onRefresh: _refresh,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AnimatedIn(
                      animation: _controller,
                      index: 1,
                      child: _StockMetrics(
                        totalProducts: products.length,
                        inStock: products.where((p) => p.stock > 15).length,
                        lowStock: lowStockItems
                            .where((i) => i.status == 'Low')
                            .length,
                        outOfStock: lowStockItems
                            .where((i) => i.status == 'Critical')
                            .length,
                        totalValue: products.fold<double>(
                          0,
                          (sum, p) => sum + (p.price * p.stock),
                        ),
                        expiringSoon: lowStockItems
                            .where((i) => i.status != 'Healthy')
                            .length,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AnimatedIn(
                      animation: _controller,
                      index: 2,
                      child: _CriticalAlertsPanel(items: lowStockItems),
                    ),
                    const SizedBox(height: 16),
                    _AnimatedIn(
                      animation: _controller,
                      index: 4,
                      child: _StockSearchBar(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AnimatedIn(
                      animation: _controller,
                      index: 5,
                      child: _StockFilterChips(
                        selected: _filter,
                        onChanged: (value) => setState(() => _filter = value),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AnimatedIn(
                      animation: _controller,
                      index: 6,
                      child: _StockTable(rows: visibleRows),
                    ),
                    const SizedBox(height: 16),
                    _AnimatedIn(
                      animation: _controller,
                      index: 7,
                      child: _RestockPlanner(items: lowStockItems),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StockHero extends StatelessWidget {
  const _StockHero({required this.onOpenMenu, required this.onRefresh});

  final VoidCallback onOpenMenu;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 14,
              left: 14,
              child: IconButton.filledTonal(
                onPressed: onOpenMenu,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF0EB),
                  foregroundColor: const Color(0xFFE8541A),
                ),
                icon: const Icon(Icons.menu),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: FilledButton.icon(
                onPressed: onRefresh,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'Refresh',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock manager',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Monitor inventory, low-stock alerts, and restock status from one polished control panel.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9E9E9E),
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

class _StockMetrics extends StatelessWidget {
  const _StockMetrics({
    required this.totalProducts,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
    required this.totalValue,
    required this.expiringSoon,
  });

  final int totalProducts;
  final int inStock;
  final int lowStock;
  final int outOfStock;
  final double totalValue;
  final int expiringSoon;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CountCard(title: 'TOTAL PRODUCTS', value: '$totalProducts'),
      _CountCard(title: 'IN STOCK', value: '$inStock'),
      _CountCard(
        title: 'LOW STOCK ALERTS',
        value: '$lowStock',
        accent: const Color(0xFFE8541A),
        filled: true,
        trailing: Icons.warning_amber_outlined,
      ),
      _CountCard(
        title: 'OUT OF STOCK',
        value: '$outOfStock',
        accent: const Color(0xFFDC2626),
        filled: true,
        trailing: Icons.error_outline,
      ),
      _CountCard(
        title: 'INVENTORY VALUE',
        value: '₹${(totalValue / 1000000).toStringAsFixed(1)}M',
      ),
      _CountCard(title: 'EXPIRING SOON', value: '$expiringSoon Items'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 700 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 150,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.title,
    required this.value,
    this.trailing,
    this.accent,
    this.filled = false,
  });

  final String title;
  final String value;
  final IconData? trailing;
  final Color? accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final base = accent ?? const Color(0xFF1F3A68);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: filled ? base.withValues(alpha: .10) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: base.withValues(alpha: .22), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (trailing != null) ...[
            Align(
              alignment: Alignment.topRight,
              child: Icon(trailing, color: base),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: base,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockSearchBar extends StatelessWidget {
  const _StockSearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search by Product Name or Category',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFF1C6B2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE8541A), width: 1.4),
        ),
      ),
    );
  }
}

class _StockFilterChips extends StatelessWidget {
  const _StockFilterChips({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = ['All', 'Low stock', 'Out of stock'];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final value = filters[index];
          final active = selected == value;
          return ChoiceChip(
            selected: active,
            label: Text(value),
            selectedColor: const Color(0xFFE8541A),
            labelStyle: TextStyle(
              color: active ? Colors.white : const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w800,
            ),
            onSelected: (_) => onChanged(value),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: filters.length,
      ),
    );
  }
}

class _StockTable extends StatelessWidget {
  const _StockTable({required this.rows});

  final List<_StockRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1C6B2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F5FD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'PRODUCT',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STOCK LEVEL',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No matching stock rows found.'),
            )
          else
            ...rows.map((row) => _StockTableRow(row: row)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Showing ${rows.length} item(s)',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockTableRow extends StatelessWidget {
  const _StockTableRow({required this.row});

  final _StockRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1E3D8))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFF4F7FB),
                  child: Icon(row.icon, size: 18, color: row.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 8,
                  decoration: BoxDecoration(
                    color: row.color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: row.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: row.color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  row.stockLabel,
                  style: TextStyle(
                    color: row.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.item});

  final _StockAlertItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(item.icon, color: item.color),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          item.category,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(label: item.status, color: item.color),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.stock}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: const Text(
                      'units available',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: item.status == 'Critical'
                      ? 0.08
                      : item.status == 'Low'
                      ? 0.28
                      : 0.62,
                  minHeight: 9,
                  color: item.color,
                  backgroundColor: item.color.withValues(alpha: .12),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.event_available,
                    size: 17,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Restock: ${item.restock}',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestockPlanner extends StatelessWidget {
  const _RestockPlanner({required this.items});

  final List<_StockAlertItem> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1E3D8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Restock priority',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Create purchase order',
                  onPressed: () {},
                  icon: const Icon(Icons.add_shopping_cart),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No stock alerts right now.'),
              )
            else
              ...items.map((item) => _RestockRow(item: item)),
          ],
        ),
      ),
    );
  }
}

class _RestockRow extends StatelessWidget {
  const _RestockRow({required this.item});

  final _StockAlertItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            item.status == 'Critical' ? Icons.bolt : Icons.low_priority,
            color: item.color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Stock ${item.stock}  •  ${item.status}  •  ${item.restock}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: () {}, child: const Text('Order')),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1E3D8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(metric.icon, color: metric.color),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    metric.label,
                    style: const TextStyle(color: Color(0xFF64748B)),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label: $value',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AnimatedIn extends StatelessWidget {
  const _AnimatedIn({
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(
        (index * .07).clamp(0, .72),
        1,
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFFBE123C),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.onNavigate, required this.onLogout});

  final void Function(String route) onNavigate;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin =
        context.read<AppState>().user?.role == UserRoles.superAdmin;
    final items = [
      ('Overview', Icons.dashboard, AdminDashboardScreen.routeName),
      ('Orders', Icons.receipt_long, AdminOrdersScreen.routeName),
      if (isSuperAdmin)
        (
          'Notifications',
          Icons.notifications_active,
          AdminNotificationsScreen.routeName,
        ),
      ('Products', Icons.inventory_2, ManageProductsScreen.routeName),
      if (isSuperAdmin)
        ('Categories', Icons.category, ManageCategoriesScreen.routeName),
      if (isSuperAdmin)
        ('Banners', Icons.slideshow, ManageBannersScreen.routeName),
      if (isSuperAdmin) ('Users', Icons.groups, ManageUsersScreen.routeName),
      if (isSuperAdmin)
        (
          'Delivery partners',
          Icons.delivery_dining,
          ManageDeliveryScreen.routeName,
        ),
      ('Stock alerts', Icons.warning_amber, StockScreen.routeName),
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFFFFF0EB),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Color(0xFFE8541A),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin menu',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Navigate the control center',
                          style: TextStyle(color: Color(0xFF9E9E9E)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE7E7E7)),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final accentColors = const [
                    Color(0xFF0F766E),
                    Color(0xFFB45309),
                    Color(0xFF2563EB),
                    Color(0xFF059669),
                    Color(0xFFEA580C),
                    Color(0xFF7C3AED),
                    Color(0xFFDB2777),
                    Color(0xFFDC2626),
                  ];
                  final accent = accentColors[index % accentColors.length];
                  final selected = item.$3 == StockScreen.routeName;
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onNavigate(item.$3),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE8541A,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                item.$2,
                                color: const Color(0xFFE8541A),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.$1,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFE8541A),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: selected
                                  ? const Color(0xFFE8541A)
                                  : const Color(0xFF9E9E9E),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE8541A),
                    side: const BorderSide(color: Color(0xFFE8541A)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFFFF0EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockAlertItem {
  const _StockAlertItem({
    required this.name,
    required this.category,
    required this.stock,
    required this.status,
    required this.restock,
    required this.color,
    required this.icon,
  });

  final String name;
  final String category;
  final int stock;
  final String status;
  final String restock;
  final Color color;
  final IconData icon;
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StockRow {
  const _StockRow({
    required this.name,
    required this.category,
    required this.stockLabel,
    required this.progress,
    required this.color,
    required this.icon,
    required this.level,
  });

  final String name;
  final String category;
  final String stockLabel;
  final double progress;
  final Color color;
  final IconData icon;
  final String level;
}

List<_StockRow> _buildStockRows(
  List<ProductModel> products,
  List<_StockAlertItem> alerts,
) {
  final alertMap = {for (final item in alerts) item.name.toLowerCase(): item};
  return products.map((product) {
    final alert = alertMap[product.name.toLowerCase()];
    final stock = product.stock;
    final level = alert?.status == 'Critical'
        ? 'Out of stock'
        : stock <= 15
        ? 'Low stock'
        : 'In stock';
    final color =
        alert?.color ??
        (stock <= 15 ? const Color(0xFFE8541A) : const Color(0xFF0F766E));
    final progress = stock <= 0
        ? 0.08
        : stock <= 15
        ? 0.42
        : 0.78;
    return _StockRow(
      name: product.name,
      category: product.category,
      stockLabel: stock <= 0 ? '0/${product.stock}' : '$stock/${stock + 100}',
      progress: progress,
      color: color,
      icon: _stockIcon(product.category),
      level: level,
    );
  }).toList();
}

class _CriticalAlertsPanel extends StatelessWidget {
  const _CriticalAlertsPanel({required this.items});

  final List<_StockAlertItem> items;

  @override
  Widget build(BuildContext context) {
    final criticalItems = items
        .where((item) => item.status == 'Critical')
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1C6B2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F5FD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFE8541A)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Critical Stock Alerts',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
          ),
          if (criticalItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No critical alerts right now.'),
            )
          else
            ...criticalItems
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFF4F7FB),
                          child: Icon(item.icon, color: item.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'SKU: ${item.category}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8541A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Restock',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
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

List<_StockAlertItem> _parseLowStock(Map<String, dynamic> data) {
  final rawItems = (data['lowStock'] as List<dynamic>? ?? const []);
  return rawItems.map((raw) {
    final item = raw as Map<String, dynamic>;
    final product = ProductModel.fromJson(item);
    final stock = product.stock;
    final status = (item['status'] as String?) ?? _stockStatus(stock).status;
    final restock = (item['restock'] as String?) ?? _stockStatus(stock).restock;
    return _StockAlertItem(
      name: product.name,
      category: product.category,
      stock: stock,
      status: status,
      restock: restock,
      color: _stockColor(status),
      icon: _stockIcon(product.category),
    );
  }).toList();
}

({String status, String restock}) _stockStatus(int stock) {
  if (stock <= 0) return (status: 'Critical', restock: 'Today');
  if (stock <= 5) return (status: 'Critical', restock: 'Today');
  if (stock <= 15) return (status: 'Low', restock: 'Soon');
  return (status: 'Healthy', restock: 'This week');
}

Color _stockColor(String status) {
  switch (status) {
    case 'Critical':
      return const Color(0xFFDC2626);
    case 'Low':
      return const Color(0xFFB45309);
    case 'Healthy':
      return const Color(0xFF0F766E);
    default:
      return const Color(0xFF2563EB);
  }
}

IconData _stockIcon(String category) {
  final value = category.toLowerCase();
  if (value.contains('dairy') || value.contains('milk'))
    return Icons.local_drink;
  if (value.contains('fruit')) return Icons.eco;
  if (value.contains('staple') || value.contains('rice'))
    return Icons.rice_bowl;
  if (value.contains('baby')) return Icons.child_care;
  return Icons.inventory_2;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/delivery_order_model.dart';
import '../providers/delivery_provider.dart';
import '../widgets/delivery_sidebar_drawer.dart';
import 'delivery_home_screen.dart';
import 'delivery_earnings_screen.dart';
import 'delivery_profile_screen.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});
  static const routeName = '/delivery/history';

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().loadDashboard();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final provider = context.watch<DeliveryProvider>();
    final history = provider.history;
    final backendStats = provider.earningsStats;
    final filtered = _applyFilters(history, _query, _filter);
    final completedOrders =
        backendStats['completedOrders'] as num? ?? history.length;
    final totalEarnings =
        (backendStats['total'] as num?)?.toDouble() ??
        _selectedEarnings(backendStats, _filter);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      drawer: const DeliverySidebarDrawer(
        currentRoute: DeliveryHistoryScreen.routeName,
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF1A1A1A)),
          ),
        ),
        title: const Text(
          'Delivery History',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A1A),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE8541A)),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFE8541A),
        onRefresh: () => context.read<DeliveryProvider>().loadDashboard(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            const Text(
              'Track your professional performance',
              style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 14),
            // _MonthSelector(
            //   value: 'October',
            //   onTap: () {},
            // ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _HistoryStatCard(
                    title: 'Total Deliveries',
                    value: '${completedOrders.toInt()}',
                    accent: const Color(0xFFE8541A),
                    icon: Icons.local_shipping_rounded,
                    muted: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HistoryStatCard(
                    title: 'Total Earnings',
                    value: '₹${totalEarnings.toStringAsFixed(2)}',
                    accent: const Color(0xFFF97316),
                    icon: Icons.payments_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SearchField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            _FilterChipBar(
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 18),
            if (provider.loading && history.isEmpty)
              const _HistorySkeleton()
            else if (filtered.isEmpty)
              const _EmptyHistoryCard(
                message: 'No orders match your search or filter',
              )
            else
              ..._groupedOrders(filtered).entries.expand((entry) {
                final sectionOrders = entry.value;
                return [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SectionHeader(
                      title: entry.key,
                      count: sectionOrders.length,
                    ),
                  ),
                  ...sectionOrders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HistoryOrderCard(order: order),
                    ),
                  ),
                ];
              }),
            const SizedBox(height: 6),
            if (filtered.isNotEmpty) ...[
              const SizedBox(height: 4),
              _SummaryFooter(
                totalOrders: filtered.length,
                completedOrders: completedOrders.toInt(),
                totalEarnings: totalEarnings,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_month_rounded, size: 18),
        label: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A1A1A),
          side: const BorderSide(color: Color(0xFFE7D7CF)),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

class _HistoryStatCard extends StatelessWidget {
  const _HistoryStatCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
    this.muted = false,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: muted ? Colors.white : accent,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: muted ? const Color(0xFFE7D7CF) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              icon,
              size: 74,
              color: Colors.white.withValues(alpha: muted ? 0.7 : 0.18),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: muted
                      ? const Color(0xFFFFF0EB)
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: muted ? const Color(0xFFE8541A) : Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: muted ? const Color(0xFF1A1A1A) : Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search by Order ID, name, area',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7D7CF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7D7CF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8541A), width: 1.4),
        ),
      ),
    );
  }
}

class _FilterChipBar extends StatelessWidget {
  const _FilterChipBar({required this.selected, required this.onChanged});
  final _HistoryFilter selected;
  final ValueChanged<_HistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _HistoryFilter.values.map((item) {
        final active = item == selected;
        return ChoiceChip(
          selected: active,
          label: Text(item.label),
          onSelected: (_) => onChanged(item),
          selectedColor: const Color(0xFFE8541A),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : const Color(0xFF1A1A1A),
          ),
          side: BorderSide(
            color: active ? const Color(0xFFE8541A) : const Color(0xFFE7D7CF),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0EB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE8541A),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({required this.order});

  final DeliveryOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showOrderDetails(context, order),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEDED)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 56,
                  color: const Color(0xFFFFF0EB),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Color(0xFFE8541A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.displayOrderId,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        _PaymentPill(type: order.paymentType),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF444444),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (order.vendorStoreName?.trim().isNotEmpty == true)
                      Text(
                        order.vendorStoreName!.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE8541A),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatDate(_historyDate(order))} • ${order.customerArea}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniInfoChip(
                          icon: Icons.shopping_bag_rounded,
                          label: '${order.itemCount} items',
                        ),
                        if (order.vendorStoreName?.trim().isNotEmpty == true)
                          _MiniInfoChip(
                            icon: Icons.storefront_rounded,
                            label: order.vendorStoreName!.trim(),
                          ),
                        _MiniInfoChip(
                          icon: Icons.payments_rounded,
                          label: '₹${order.totalAmount.toStringAsFixed(2)}',
                        ),
                        _MiniInfoChip(
                          icon: Icons.account_balance_wallet_rounded,
                          label:
                              'Earned ₹${(order.deliveryEarning ?? 0).toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showOrderDetails(BuildContext context, DeliveryOrderModel order) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F7F7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D8D8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  order.displayOrderId,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  order.customerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF555555),
                  ),
                ),
                if (order.vendorStoreName?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  _DetailTile(
                    icon: Icons.storefront_rounded,
                    title: 'Vendor Store',
                    value: order.vendorStoreName!.trim(),
                  ),
                  const SizedBox(height: 12),
                  if (order.vendorAddress?.trim().isNotEmpty == true)
                    _DetailTile(
                      icon: Icons.location_on_rounded,
                      title: 'Vendor Address',
                      value: order.vendorAddress!.trim(),
                    ),
                  if (order.vendorPickupAddress?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: Icons.local_shipping_rounded,
                      title: 'Pickup Address',
                      value: order.vendorPickupAddress!.trim(),
                    ),
                  ],
                  if (order.vendorCity?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: Icons.location_city_rounded,
                      title: 'Pickup City',
                      value: order.vendorCity!.trim(),
                    ),
                  ],
                  if (order.vendorPincode?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: Icons.pin_drop_rounded,
                      title: 'Pickup Pincode',
                      value: order.vendorPincode!.trim(),
                    ),
                  ],
                  if (order.vendorAddress?.trim().isNotEmpty == true)
                    const SizedBox(height: 12),
                  if (order.vendorPhone?.trim().isNotEmpty == true)
                    _DetailTile(
                      icon: Icons.call_rounded,
                      title: 'Vendor Phone',
                      value: order.vendorPhone!.trim(),
                    ),
                  if (order.vendorPhone?.trim().isNotEmpty == true)
                    const SizedBox(height: 16),
                ],
                const SizedBox(height: 16),
                _DetailTile(
                  icon: Icons.location_on_rounded,
                  title: 'Delivered Address',
                  value: order.customerAddress.isNotEmpty
                      ? order.customerAddress
                      : order.customerArea,
                ),
                if (order.customerLine1?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.home_rounded,
                    title: 'Customer Street',
                    value: order.customerLine1!.trim(),
                  ),
                ],
                if (order.customerCity?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.location_city_rounded,
                    title: 'Customer City',
                    value: order.customerCity!.trim(),
                  ),
                ],
                if (order.customerPincode?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _DetailTile(
                    icon: Icons.pin_drop_rounded,
                    title: 'Customer Pincode',
                    value: order.customerPincode!.trim(),
                  ),
                ],
                const SizedBox(height: 12),
                _DetailTile(
                  icon: Icons.payments_rounded,
                  title: 'Amount',
                  value: '₹${order.totalAmount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 12),
                _DetailTile(
                  icon: Icons.calendar_month_rounded,
                  title: 'Delivered Time',
                  value: _formatDate(_historyDate(order)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OrderItemTile(item: item),
                  ),
                ),
                if (order.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No item details available',
                      style: TextStyle(color: Color(0xFF777777)),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFE8541A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF777777),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
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

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item});

  final DeliveryOrderItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 54,
              height: 54,
              color: const Color(0xFFFFF0EB),
              child: item.imageUrl.isNotEmpty
                  ? Image.network(item.imageUrl, fit: BoxFit.cover)
                  : const Icon(Icons.image_rounded, color: Color(0xFFE8541A)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity}  •  ₹${item.unitPrice.toStringAsFixed(2)} each',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${item.lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE8541A),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE8541A)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentPill extends StatelessWidget {
  const _PaymentPill({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final isCod = type.toLowerCase() == 'cod';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isCod ? const Color(0xFFFFF0EB) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isCod ? 'COD' : 'ONLINE',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isCod ? const Color(0xFFE8541A) : const Color(0xFF4F46E5),
        ),
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 112,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF777777),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryFooter extends StatelessWidget {
  const _SummaryFooter({
    required this.totalOrders,
    required this.completedOrders,
    required this.totalEarnings,
  });

  final int totalOrders;
  final int completedOrders;
  final double totalEarnings;

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
          Expanded(
            child: Text(
              'Showing $totalOrders orders',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            'Delivered $completedOrders',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFFE8541A),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${totalEarnings.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.grid_view_rounded, 'Home'),
      (Icons.history_rounded, 'History'),
      (Icons.account_balance_wallet_rounded, 'Earnings'),
      (Icons.person_rounded, 'Profile'),
    ];

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final selected = i == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFE8541A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          item.$1,
                          size: 22,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? const Color(0xFFE8541A)
                              : const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

int _countToday(List<DeliveryOrderModel> orders) {
  final now = DateTime.now();
  return orders.where((order) {
    final created = _historyDate(order);
    return created.year == now.year &&
        created.month == now.month &&
        created.day == now.day;
  }).length;
}

List<DeliveryOrderModel> _applyFilters(
  List<DeliveryOrderModel> orders,
  String query,
  _HistoryFilter filter,
) {
  final needle = query.trim().toLowerCase();
  return orders.where((order) {
    final matchesSearch =
        needle.isEmpty ||
        [
          order.displayOrderId,
          order.customerName,
          order.customerArea,
          order.paymentType,
        ].any((value) => value.toLowerCase().contains(needle));
    final matchesFilter = switch (filter) {
      _HistoryFilter.all => true,
      _HistoryFilter.today => _isSameDay(_historyDate(order), DateTime.now()),
      _HistoryFilter.yesterday => _isSameDay(
        _historyDate(order),
        DateTime.now().subtract(const Duration(days: 1)),
      ),
      _HistoryFilter.thisWeek => _isSameWeek(
        _historyDate(order),
        DateTime.now(),
      ),
      _HistoryFilter.thisMonth => _isSameMonth(
        _historyDate(order),
        DateTime.now(),
      ),
    };
    return matchesSearch && matchesFilter;
  }).toList();
}

Map<String, List<DeliveryOrderModel>> _groupedOrders(
  List<DeliveryOrderModel> orders,
) {
  final today = <DeliveryOrderModel>[];
  final yesterday = <DeliveryOrderModel>[];
  final thisWeek = <DeliveryOrderModel>[];
  final earlier = <DeliveryOrderModel>[];

  for (final order in orders) {
    final historyDate = _historyDate(order);
    if (_isSameDay(historyDate, DateTime.now())) {
      today.add(order);
    } else if (_isSameDay(
      historyDate,
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
      yesterday.add(order);
    } else if (_isSameWeek(historyDate, DateTime.now())) {
      thisWeek.add(order);
    } else {
      earlier.add(order);
    }
  }

  return {
    if (today.isNotEmpty) 'Today': today,
    if (yesterday.isNotEmpty) 'Yesterday': yesterday,
    if (thisWeek.isNotEmpty) 'This Week': thisWeek,
    if (earlier.isNotEmpty) 'Earlier': earlier,
  };
}

double _selectedEarnings(Map<String, dynamic> stats, _HistoryFilter filter) {
  final value = switch (filter) {
    _HistoryFilter.all =>
      stats['monthly'] ?? stats['monthlyEarnings'] ?? stats['today'] ?? 0,
    _HistoryFilter.today => stats['today'] ?? stats['todayEarnings'] ?? 0,
    _HistoryFilter.yesterday => stats['today'] ?? stats['todayEarnings'] ?? 0,
    _HistoryFilter.thisWeek => stats['weekly'] ?? stats['weeklyEarnings'] ?? 0,
    _HistoryFilter.thisMonth =>
      stats['monthly'] ?? stats['monthlyEarnings'] ?? 0,
  };
  return (value as num?)?.toDouble() ?? 0;
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isSameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
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

enum _HistoryFilter { all, today, yesterday, thisWeek, thisMonth }

extension on _HistoryFilter {
  String get label => switch (this) {
    _HistoryFilter.all => 'All',
    _HistoryFilter.today => 'Today',
    _HistoryFilter.yesterday => 'Yesterday',
    _HistoryFilter.thisWeek => 'This Week',
    _HistoryFilter.thisMonth => 'This Month',
  };
}

int _countYesterday(List<DeliveryOrderModel> orders) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  return orders.where((order) {
    final created = _historyDate(order);
    return created.year == yesterday.year &&
        created.month == yesterday.month &&
        created.day == yesterday.day;
  }).length;
}

List<DeliveryOrderModel> _todayOrders(List<DeliveryOrderModel> orders) {
  final now = DateTime.now();
  return orders.where((order) {
    final created = _historyDate(order);
    return created.year == now.year &&
        created.month == now.month &&
        created.day == now.day;
  }).toList();
}

List<DeliveryOrderModel> _yesterdayOrders(List<DeliveryOrderModel> orders) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  return orders.where((order) {
    final created = _historyDate(order);
    return created.year == yesterday.year &&
        created.month == yesterday.month &&
        created.day == yesterday.day;
  }).toList();
}

DateTime _historyDate(DeliveryOrderModel order) {
  return order.deliveredAt ?? order.createdAt;
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute $suffix';
}

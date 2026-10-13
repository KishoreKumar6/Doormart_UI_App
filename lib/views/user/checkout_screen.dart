import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/address_model.dart';
import '../../providers/app_state.dart';
import '../../widgets/toast_widget.dart';
import 'add_edit_address_screen.dart';
import 'payment_screen.dart';
import 'order_success_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFE8541A);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kBg = Color(0xFFF6F6F6);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextMid = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE8E8E8);

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  static const routeName = '/checkout';

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _selectedAddressId;
  bool _initialLoadDone = false;
  bool _processingCod = false;
  Future<Map<String, dynamic>>? _summaryFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadDone) return;
    _initialLoadDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = context.read<AppState>();
      // Refresh cart products so vendor pickup coordinates are available for
      // distance-based delivery pricing.
      await state.loadCart();
      if (!mounted) return;
      await state.loadCheckoutSettings();
      if (!mounted) return;
      await state.loadAddresses();
      if (!mounted) return;
      _selectedAddressId = state.selectedAddress?.id;
      // Never render a summary calculated for a previous address or cart.
      state.checkoutSummary = null;
      _summaryFuture = state.loadCheckoutSummary(
        address: state.selectedAddress,
      );
      final summary = await _summaryFuture;
      if (!mounted) return;
      state.checkoutSummary = summary;
      if (mounted) setState(() {});
    });
  }

  AddressModel? _resolveAddress(AppState state) {
    if (state.savedAddresses.isEmpty) return null;
    final id = _selectedAddressId ?? state.selectedAddress?.id;
    return state.savedAddresses.firstWhere(
      (a) => a.id == id,
      orElse: () => state.savedAddresses.first,
    );
  }

  // ── COD order ─────────────────────────────────────────────────────────────
  Future<void> _placeCodOrder(
    AppState state,
    AddressModel selectedAddress,
  ) async {
    setState(() => _processingCod = true);
    try {
      await state.checkout(address: selectedAddress, paymentMethod: 'cod');
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showToast(context, '✅ COD order placed!');
      Navigator.pushReplacementNamed(context, OrderSuccessScreen.routeName);
    } catch (e) {
      if (!mounted) return;
      showToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _processingCod = false);
    }
  }

  // ── Cashfree — set address then navigate ───────────────────────────────────
  Future<void> _goToCashfree(
    AppState state,
    AddressModel selectedAddress,
  ) async {
    state.selectedAddress = selectedAddress;
    if (!mounted) return;
    Navigator.pushNamed(context, PaymentScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, state, _) {
            final addresses = state.savedAddresses;
            final selectedAddress = _resolveAddress(state);
            final canOrder =
                addresses.isNotEmpty &&
                state.cart.isNotEmpty &&
                selectedAddress != null;
            final vendorEntries = <String, String>{};
            for (final line in state.cart) {
              final vendorId = line.product.vendorId.trim().isEmpty
                  ? 'main'
                  : line.product.vendorId.trim();
              final storeName = line.product.supplierName.trim().isNotEmpty
                  ? line.product.supplierName.trim()
                  : (vendorId == 'main' ? 'Main Store' : vendorId);
              final city = line.product.supplierCity.trim();
              vendorEntries.putIfAbsent(
                vendorId,
                () => city.isNotEmpty ? '$storeName, $city' : storeName,
              );
            }
            final vendorLabels = vendorEntries.values.toList(growable: false);
            final hasMultiVendorCart = vendorEntries.length > 1;

            return Column(
              children: [
                _TopBar(onBack: () => Navigator.pop(context)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero title ────────────────────────────────────
                        const Text(
                          'Confirm delivery\nand payment',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: _kTextDark,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a delivery address and your preferred payment method.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.black.withValues(alpha: 0.52),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Addresses ─────────────────────────────────────
                        const _SectionLabel('📍  Delivery address'),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final appState = context.read<AppState>();
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddEditAddressScreen(),
                                ),
                              );
                              if (result == true && mounted) {
                                await appState.loadAddresses();
                                if (!mounted) return;
                                setState(() {
                                  _selectedAddressId =
                                      state.selectedAddress?.id;
                                });
                                state.checkoutSummary = null;
                              }
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add New Address'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kOrange,
                              side: const BorderSide(color: _kOrange),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (addresses.isEmpty)
                          _InfoCard(
                            icon: Icons.location_off_rounded,
                            title: 'No saved addresses',
                            subtitle:
                                'Add an address now to continue checkout.',
                            actionLabel: 'Add address',
                            onAction: () async {
                              final appState = context.read<AppState>();
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddEditAddressScreen(),
                                ),
                              );
                              if (result == true && mounted) {
                                await appState.loadAddresses();
                              }
                            },
                          )
                        else
                          SizedBox(
                            height: 198,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: addresses.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, i) {
                                final addr = addresses[i];
                                final sel =
                                    _selectedAddressId == addr.id ||
                                    (_selectedAddressId == null &&
                                        state.selectedAddress?.id == addr.id);
                                return _AddressCard(
                                  data: addr,
                                  selected: sel,
                                  onTap: () => setState(() {
                                    _selectedAddressId = addr.id;
                                    state.selectedAddress = addr;
                                    state.checkoutSummary = null;
                                    _summaryFuture = state.loadCheckoutSummary(
                                      address: addr,
                                    );
                                  }),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 24),

                        // ── Order summary ─────────────────────────────────
                        const _SectionLabel('🧾  Order summary'),
                        const SizedBox(height: 12),
                        FutureBuilder<Map<String, dynamic>>(
                          future:
                              _summaryFuture ??
                              state.loadCheckoutSummary(
                                address: selectedAddress,
                              ),
                          builder: (context, snapshot) {
                            final summary =
                                snapshot.data ?? state.checkoutSummary;
                            final subtotal =
                                (summary?['subtotal'] as num?)?.toDouble() ??
                                state.subtotal;
                            final localDistanceFee = state
                                .distanceBasedDeliveryFee(selectedAddress);
                            final localDeliveryBreakdown = state
                                .deliveryChargeBreakdown(selectedAddress);
                            final deliveryDistance = state.cartDistanceKm(
                              selectedAddress,
                            );
                            final calculatedDeliveryFee =
                                localDistanceFee ??
                                (summary?['calculatedDeliveryFee'] as num?)
                                    ?.toDouble() ??
                                (summary?['deliveryFee'] as num?)?.toDouble() ??
                                state.calculatedDeliveryFee;
                            final gstAmount =
                                (summary?['gstAmount'] as num?)?.toDouble() ??
                                state.gstAmount;
                            final freeDeliveryUnlocked =
                                (summary?['isFreeDelivery'] as bool?) == true ||
                                state.isFreeDelivery ||
                                calculatedDeliveryFee <= 0 ||
                                (state.freeDeliveryEnabled &&
                                    (state.freeDeliveryThreshold <= 0 ||
                                        subtotal >=
                                            state.freeDeliveryThreshold));

                            final effectiveDeliveryFee = freeDeliveryUnlocked
                                ? 0.0
                                : calculatedDeliveryFee;
                            final total =
                                subtotal + effectiveDeliveryFee + gstAmount;
                            return _SummaryCard(
                              items: state.cart,
                              subtotal: subtotal,
                              deliveryFee: effectiveDeliveryFee,
                              gstAmount: gstAmount,
                              total: total,
                              distanceKm: deliveryDistance,
                              chargePerKm: state.deliveryBaseCharge,
                              deliveryBreakdown: localDeliveryBreakdown,
                              freeDeliveryUnlocked: freeDeliveryUnlocked,
                              loading:
                                  snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  summary == null,
                            );
                          },
                        ),

                        if (hasMultiVendorCart) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _kBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _kOrangeLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.storefront_rounded,
                                        color: _kOrange,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Text(
                                        'Stores in your cart',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: _kTextDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'This cart will be split into separate orders by store.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: vendorLabels
                                      .map(
                                        (label) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _kOrangeLight,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: _kOrange.withValues(
                                                alpha: 0.12,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            label,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _kOrange,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // ── Payment methods ───────────────────────────────
                        const _SectionLabel('💳  Payment method'),
                        const SizedBox(height: 12),

                        // COD button
                        _ActionButton(
                          label: 'Place Cash On Delivery Order',
                          icon: Icons.money_rounded,
                          loading: _processingCod,
                          enabled: canOrder,
                          onTap: () => _placeCodOrder(state, selectedAddress!),
                        ),

                        const SizedBox(height: 12),

                        // Cashfree button
                        _CashfreeButton(
                          enabled: canOrder,
                          onTap: () => _goToCashfree(state, selectedAddress!),
                        ),

                        const SizedBox(height: 16),

                        // Delivery address reminder
                        if (selectedAddress != null)
                          _DeliveryAddressChip(
                            address: selectedAddress.fullAddress,
                          )
                        else
                          const _InfoCard(
                            icon: Icons.info_outline_rounded,
                            title: 'Select an address',
                            subtitle: 'Tap a saved address above to continue.',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                size: 26,
                color: _kTextDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Checkout',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _kTextDark,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: _kTextDark,
      ),
    );
  }
}

// ─── Address Card ─────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final AddressModel data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 210,
        constraints: const BoxConstraints(minHeight: 166),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _kOrange : _kBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? _kOrange.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: selected ? _kOrange : _kOrangeLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 15,
                    color: selected ? Colors.white : _kOrange,
                  ),
                ),
                const Spacer(),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: selected ? 1 : 0,
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: _kOrange,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.line1,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF666666),
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.shortAddress,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: _kTextMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.gstAmount,
    required this.total,
    this.distanceKm,
    this.chargePerKm,
    this.deliveryBreakdown = const [],
    this.freeDeliveryUnlocked,
    this.loading = false,
  });

  final List<CartLine> items;
  final double subtotal;
  final double deliveryFee;
  final double gstAmount;
  final double total;
  final double? distanceKm;
  final double? chargePerKm;
  final List<DeliveryChargeBreakdown> deliveryBreakdown;
  final bool? freeDeliveryUnlocked;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isFree =
        freeDeliveryUnlocked ??
        (deliveryFee <= 0 ||
            appState.isFreeDelivery ||
            (appState.freeDeliveryEnabled &&
                (appState.freeDeliveryThreshold <= 0 ||
                    subtotal >= appState.freeDeliveryThreshold)));
    final effectiveDeliveryFee = isFree ? 0.0 : deliveryFee;
    final effectiveTotal = subtotal + effectiveDeliveryFee + gstAmount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 14),
          ],
          const Text(
            'Items in your cart',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              'No items in cart',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            )
          else
            ...items.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.product.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kTextDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Qty x${line.quantity}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Subtotal', value: subtotal),
          const SizedBox(height: 10),
          if (deliveryBreakdown.length > 1) ...[
            _SummaryRow(
              label: 'Delivery fee (2 stores)',
              value: effectiveDeliveryFee,
              valueText: isFree ? 'Rs 0.00' : null,
              valueColor: isFree ? const Color(0xFF16A34A) : null,
            ),
            const SizedBox(height: 6),
            ...deliveryBreakdown.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _SummaryRow(
                  label:
                      '${entry.storeName} (${entry.distanceKm.toStringAsFixed(1)} km × ₹${chargePerKm?.toStringAsFixed(2) ?? '0.00'})',
                  value: isFree ? 0 : entry.fee,
                  valueText: isFree ? 'Rs 0.00' : null,
                  valueColor: isFree ? const Color(0xFF16A34A) : null,
                  compact: true,
                ),
              ),
            ),
          ] else
            _SummaryRow(
              label: distanceKm != null && chargePerKm != null
                  ? 'Delivery fee (${distanceKm!.toStringAsFixed(1)} km × ₹${chargePerKm!.toStringAsFixed(2)})'
                  : 'Delivery fee',
              value: effectiveDeliveryFee,
              valueText: effectiveDeliveryFee <= 0 ? 'Rs 0.00' : null,
              valueColor: effectiveDeliveryFee <= 0
                  ? const Color(0xFF16A34A)
                  : null,
            ),
          const SizedBox(height: 10),
          _SummaryRow(label: 'GST', value: gstAmount),
          if (appState.freeDeliveryEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isFree
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFree
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFFED7AA),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFree
                          ? Icons.check_circle_rounded
                          : Icons.local_shipping_outlined,
                      size: 15,
                      color: isFree
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEA580C),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isFree
                            ? 'FREE delivery applied!'
                            : ((appState.freeDeliveryThreshold - subtotal) > 0
                                  ? 'Add Rs ${(appState.freeDeliveryThreshold - subtotal).toStringAsFixed(0)} more to get FREE delivery'
                                  : 'FREE delivery applied!'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isFree
                              ? const Color(0xFF15803D)
                              : const Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
          _SummaryRow(label: 'Total', value: effectiveTotal, bold: true),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.compact = false,
    this.valueText,
    this.valueColor,
  });

  final String label;
  final double value;
  final bool bold;
  final bool compact;
  final String? valueText;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final displayText = valueText ?? 'Rs ${value.toStringAsFixed(2)}';
    final textColor = valueColor ?? (bold ? _kOrange : _kTextDark);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: bold ? 15 : (compact ? 11 : 13),
              color: bold ? _kTextDark : const Color(0xFF666666),
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          displayText,
          style: TextStyle(
            fontSize: bold ? 17 : 13,
            color: textColor,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Action Button (COD) ──────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.96,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading;

    return GestureDetector(
      onTapDown: active ? (_) => _c.forward() : null,
      onTapUp: active
          ? (_) {
              _c.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFFF26522), Color(0xFFE8401A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: active ? null : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        size: 18,
                        color: active ? Colors.white : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : Colors.grey,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Cashfree Button ──────────────────────────────────────────────────────────

class _CashfreeButton extends StatefulWidget {
  const _CashfreeButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_CashfreeButton> createState() => _CashfreeButtonState();
}

class _CashfreeButtonState extends State<_CashfreeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.96,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _c.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _c.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? const LinearGradient(
                    colors: [Color(0xFF7B73FF), Color(0xFF5851DB)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: widget.enabled ? null : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(999),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 18,
                color: widget.enabled ? Colors.white : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Pay Online',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: widget.enabled ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Delivery address chip ────────────────────────────────────────────────────

class _DeliveryAddressChip extends StatelessWidget {
  const _DeliveryAddressChip({required this.address});
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kOrangeLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_rounded, size: 16, color: _kOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Delivering to: $address',
              style: const TextStyle(
                fontSize: 12.5,
                color: _kOrange,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kOrangeLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _kOrange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

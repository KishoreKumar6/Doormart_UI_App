import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../providers/app_state.dart';
import '../admin/admin_logout_confirm.dart';
import '../admin/admin_sidebar_drawer.dart';

const Color _kBg = Color(0xFFF6F6F6);
const Color _kCard = Colors.white;
const Color _kOrange = Color(0xFFE8541A);
const Color _kOrangeLight = Color(0xFFFFF0EB);
const Color _kTextDark = Color(0xFF1E293B);
const Color _kTextMuted = Color(0xFF64748B);
const Color _kBorder = Color(0xFFE2E8F0);
const Color _kSuccess = Color(0xFF16A34A);

class DeliveryChargesScreen extends StatefulWidget {
  const DeliveryChargesScreen({super.key});

  static const routeName = '/super-admin/delivery-charges';

  @override
  State<DeliveryChargesScreen> createState() => _DeliveryChargesScreenState();
}

class _DeliveryChargesScreenState extends State<DeliveryChargesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Distance & Basic Pricing
  late final TextEditingController _fallbackFeeController;
  late final TextEditingController _baseChargeController;
  bool _distanceBasedDelivery = false;

  // Free Delivery
  bool _freeDeliveryEnabled = true;
  late final TextEditingController _freeDeliveryThresholdController;

  // Shift Pricing
  bool _shiftChargesEnabled = false;
  late final TextEditingController _nightChargeController;
  late final TextEditingController _dayShiftStartController;
  late final TextEditingController _dayShiftEndController;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _fallbackFeeController = TextEditingController();
    _baseChargeController = TextEditingController();

    _freeDeliveryThresholdController = TextEditingController();

    _nightChargeController = TextEditingController();
    _dayShiftStartController = TextEditingController();
    _dayShiftEndController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _fallbackFeeController.dispose();
    _baseChargeController.dispose();
    _freeDeliveryThresholdController.dispose();
    _nightChargeController.dispose();
    _dayShiftStartController.dispose();
    _dayShiftEndController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final state = context.read<AppState>();
    await state.loadCheckoutSettings();
    if (!mounted) return;

    _populateFromState(state);
    setState(() {
      _isLoading = false;
      _initialized = true;
    });
  }

  void _populateFromState(AppState state) {
    _fallbackFeeController.text = state.deliveryChargeAmount.toStringAsFixed(0);
    _distanceBasedDelivery = state.distanceBasedDelivery;
    _baseChargeController.text = state.deliveryBaseCharge.toStringAsFixed(2);

    _freeDeliveryEnabled = state.freeDeliveryEnabled;
    _freeDeliveryThresholdController.text = state.freeDeliveryThreshold
        .toStringAsFixed(0);

    _shiftChargesEnabled = state.shiftChargesEnabled;
    _nightChargeController.text = state.nightDeliveryCharge.toStringAsFixed(0);
    _dayShiftStartController.text = state.dayShiftStart;
    _dayShiftEndController.text = state.dayShiftEnd;
  }

  double _cleanDouble(String text, {double fallback = 0.0}) {
    final clean = text.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    if (clean.isEmpty) return fallback;
    return double.tryParse(clean) ?? fallback;
  }

  Future<void> _pickShiftTime(TextEditingController controller) async {
    final parts = controller.text.trim().split(':');
    final initialTime = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select night surcharge window time',
    );
    if (!mounted || picked == null) return;
    controller.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {});
  }

  Future<void> _save() async {
    final fallbackFee = _cleanDouble(_fallbackFeeController.text, fallback: -1);
    final baseCharge = _cleanDouble(_baseChargeController.text, fallback: -1);
    final freeThreshold = _cleanDouble(
      _freeDeliveryThresholdController.text,
      fallback: 0,
    );
    final nightCharge = _cleanDouble(_nightChargeController.text, fallback: -1);
    final dayStart = _dayShiftStartController.text.trim();
    final dayEnd = _dayShiftEndController.text.trim();

    final timeRegex = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$');

    if (fallbackFee < 0) {
      _showToast('Enter a valid non-negative fixed fallback fee');
      return;
    }
    if (baseCharge < 0) {
      _showToast('Enter a valid non-negative charge per km');
      return;
    }
    if (freeThreshold < 0) {
      _showToast('Enter a valid non-negative free delivery threshold');
      return;
    }
    if (nightCharge < 0) {
      _showToast('Enter a valid non-negative night shift charge');
      return;
    }
    if (!timeRegex.hasMatch(dayStart)) {
      _showToast('Night shift start time must be in HH:mm format (e.g. 22:00)');
      return;
    }
    if (!timeRegex.hasMatch(dayEnd)) {
      _showToast('Night shift end time must be in HH:mm format (e.g. 06:00)');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final state = context.read<AppState>();
      await state.saveCheckoutSettings(
        deliveryChargeAmount: fallbackFee,
        // GST is configured per product, not in delivery-charge settings.
        gstPercent: state.gstPercent,
        distanceBasedDelivery: _distanceBasedDelivery,
        deliveryBaseDistanceKm: 0,
        deliveryBaseCharge: baseCharge,
        deliveryPerKmCharge: 0,
        freeDeliveryEnabled: _freeDeliveryEnabled,
        freeDeliveryThreshold: freeThreshold,
        shiftChargesEnabled: _shiftChargesEnabled,
        // Normal daytime pricing comes from the fixed or distance settings.
        // The only shift surcharge is the configured night charge.
        dayDeliveryCharge: state.dayDeliveryCharge,
        nightDeliveryCharge: nightCharge,
        dayShiftStart: dayStart,
        dayShiftEnd: dayEnd,
      );
      if (!mounted) return;
      _populateFromState(state);
      _showToast('Delivery charges saved successfully', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showToast(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showToast(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : _kSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    final isSuperAdmin = user?.role == UserRoles.superAdmin;

    if (!isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text(
            'Only Super Admin is authorized to access Delivery Charges Management.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      drawer: AdminSidebarDrawer(
        currentRoute: DeliveryChargesScreen.routeName,
        onLogout: () async {
          if (!await confirmAdminLogout(context)) return;
          if (!context.mounted) return;
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
        child: _isLoading && !_initialized
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildModeCard(),
                    const SizedBox(height: 16),
                    _buildDistancePricingCard(),
                    const SizedBox(height: 16),
                    _buildFreeDeliveryCard(),
                    const SizedBox(height: 16),
                    _buildShiftChargesCard(),
                    const SizedBox(height: 16),
                    _buildCurrentConfigCard(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu, color: _kOrange, size: 26),
            tooltip: 'Menu',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Charges Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Super Admin Delivery Pricing Control Center',
                  style: TextStyle(
                    fontSize: 13,
                    color: _kTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh, color: _kOrange),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard() {
    return _SectionCard(
      title: '1. Delivery Fee Mode',
      subtitle:
          'Choose between distance-based calculation or standard fixed delivery fee. All customer checkouts use this rule automatically.',
      icon: Icons.alt_route_rounded,
      child: SwitchListTile.adaptive(
        value: _distanceBasedDelivery,
        onChanged: (val) => setState(() => _distanceBasedDelivery = val),
        contentPadding: EdgeInsets.zero,
        activeThumbColor: _kOrange,
        title: const Text(
          'Calculate delivery fee by distance',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: Text(
          _distanceBasedDelivery
              ? 'Active: Distance-based calculation from store pickup to customer.'
              : 'Active: Fixed fee mode using the fallback fee amount.',
          style: TextStyle(color: _kTextMuted, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildDistancePricingCard() {
    return _SectionCard(
      title: '2. Distance-based Charges',
      subtitle: 'Configure base rates and per-kilometer pricing for delivery.',
      icon: Icons.social_distance_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth > 720
              ? (constraints.maxWidth - 36) / 3
              : constraints.maxWidth > 460
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          Widget field(
            TextEditingController controller,
            String label, {
            String? prefix,
            String? suffix,
            String? helper,
          }) {
            return SizedBox(
              width: itemWidth,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  labelText: label,
                  prefixText: prefix,
                  suffixText: suffix,
                  helperText: helper,
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kOrange, width: 2),
                  ),
                ),
              ),
            );
          }

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              field(
                _fallbackFeeController,
                'Fixed fallback fee',
                prefix: 'Rs ',
              ),
              field(
                _baseChargeController,
                'Charge per km',
                prefix: 'Rs ',
                helper: 'Distance × this rate = delivery fee',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFreeDeliveryCard() {
    return _SectionCard(
      title: '3. Free Delivery',
      subtitle:
          'Set a dynamic minimum order threshold. Eligible orders equal to or above this amount automatically receive FREE delivery (₹0 fee).',
      icon: Icons.local_offer_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            value: _freeDeliveryEnabled,
            onChanged: (val) => setState(() => _freeDeliveryEnabled = val),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _kSuccess,
            title: const Text(
              'Enable Free Delivery',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            subtitle: Text(
              _freeDeliveryEnabled
                  ? 'Active: Free delivery will be applied to qualifying orders.'
                  : 'Disabled: All orders pay configured delivery fee.',
              style: TextStyle(color: _kTextMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 280,
            child: TextField(
              controller: _freeDeliveryThresholdController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (val) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Free Delivery Threshold',
                prefixText: 'Rs ',
                helperText:
                    'Orders above or equal to this qualify for free delivery',
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kSuccess, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kOrangeLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: _kOrange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _freeDeliveryEnabled
                        ? () {
                            final raw = _freeDeliveryThresholdController.text
                                .replaceAll(RegExp(r'[^0-9.]'), '')
                                .trim();
                            if (raw.isEmpty) {
                              return 'Customer rule: Please enter a threshold amount (e.g. Rs 199, Rs 299) or enter 0 for all orders.';
                            }
                            final val = double.tryParse(raw);
                            if (val == null || val <= 0) {
                              return 'Customer rule: Free delivery active for all orders (₹0 threshold).';
                            }
                            return 'Customer rule: If cart subtotal >= Rs ${val.toStringAsFixed(0)}, Delivery = FREE.';
                          }()
                        : 'Free delivery is currently disabled. Standard calculation applies.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftChargesCard() {
    return _SectionCard(
      title: '4. Night Delivery Surcharge',
      subtitle:
          'Normal delivery pricing applies during the day. Add an extra surcharge only for deliveries placed during the night window.',
      icon: Icons.access_time_filled_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            value: _shiftChargesEnabled,
            onChanged: (val) => setState(() => _shiftChargesEnabled = val),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _kOrange,
            title: const Text(
              'Enable Night Shift Surcharge',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            subtitle: Text(
              _shiftChargesEnabled
                  ? 'Active: Night surcharge is added to the normal delivery fee.'
                  : 'Disabled: Normal fixed or distance pricing applies all day.',
              style: TextStyle(color: _kTextMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth > 600
                  ? (constraints.maxWidth - 24) / 2
                  : constraints.maxWidth;

              Widget field(
                TextEditingController controller,
                String label, {
                String? prefix,
                String? helper,
                TextInputType? keyboardType,
                bool timePicker = false,
              }) {
                return SizedBox(
                  width: itemWidth,
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    readOnly: timePicker,
                    onTap: timePicker ? () => _pickShiftTime(controller) : null,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: label,
                      prefixText: prefix,
                      helperText: helper,
                      suffixIcon: timePicker
                          ? const Icon(Icons.access_time_rounded)
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kOrange, width: 2),
                      ),
                    ),
                  ),
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  field(
                    _nightChargeController,
                    'Night Surcharge',
                    prefix: 'Rs ',
                    helper: 'Added to normal delivery pricing at night',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  field(
                    _dayShiftStartController,
                    'Night Shift Start (24h)',
                    helper: 'e.g. 22:00 (10:00 PM)',
                    timePicker: true,
                  ),
                  field(
                    _dayShiftEndController,
                    'Night Shift End (24h)',
                    helper: 'e.g. 06:00 (6:00 AM)',
                    timePicker: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Night surcharge applies from ${_dayShiftStartController.text.trim()} to ${_dayShiftEndController.text.trim()} (overnight times are supported).',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: _kTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentConfigCard() {
    final state = context.watch<AppState>();
    final liveFallback = _cleanDouble(
      _fallbackFeeController.text,
      fallback: state.deliveryChargeAmount,
    );
    final liveThreshold = _cleanDouble(
      _freeDeliveryThresholdController.text,
      fallback: state.freeDeliveryThreshold,
    );
    final liveNight = _cleanDouble(
      _nightChargeController.text,
      fallback: state.nightDeliveryCharge,
    );
    final liveBaseCharge = _cleanDouble(
      _baseChargeController.text,
      fallback: state.deliveryBaseCharge,
    );
    final liveStart = _dayShiftStartController.text.trim().isEmpty
        ? state.dayShiftStart
        : _dayShiftStartController.text.trim();
    final liveEnd = _dayShiftEndController.text.trim().isEmpty
        ? state.dayShiftEnd
        : _dayShiftEndController.text.trim();

    return _SectionCard(
      title: '5. Current Configuration (Live Values)',
      subtitle:
          'Live values actively configured on this screen. Saved directly to backend upon saving.',
      icon: Icons.check_circle_outline_rounded,
      child: Column(
        children: [
          _ConfigRow(
            label: 'Mode',
            value: _distanceBasedDelivery ? 'Distance Based' : 'Fixed Fee',
          ),
          _ConfigRow(
            label: 'Fixed Fallback Fee',
            value: 'Rs ${liveFallback.toStringAsFixed(0)}',
          ),
          _ConfigRow(
            label: 'Free Delivery',
            value: _freeDeliveryEnabled
                ? 'Enabled (Threshold: Rs ${liveThreshold.toStringAsFixed(0)})'
                : 'Disabled',
            valueColor: _freeDeliveryEnabled ? _kSuccess : null,
          ),
          _ConfigRow(
            label: 'Shift Pricing',
            value: _shiftChargesEnabled
                ? 'Enabled (Night surcharge: Rs ${liveNight.toStringAsFixed(0)})'
                : 'Disabled',
          ),
          if (_shiftChargesEnabled)
            _ConfigRow(
              label: 'Day Shift Window',
              value: '$liveStart - $liveEnd',
            ),
          _ConfigRow(
            label: 'Charge Per Km',
            value: 'Rs ${liveBaseCharge.toStringAsFixed(2)} / km',
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: _kOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_rounded, size: 22),
        label: Text(
          _isSaving ? 'Saving Charges...' : 'Save Delivery Charges',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kOrangeLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _kOrange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: _kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kTextMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? _kTextDark,
            ),
          ),
        ],
      ),
    );
  }
}

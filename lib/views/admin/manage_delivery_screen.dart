import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import 'admin_logout_confirm.dart';
import 'admin_dashboard_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_orders_screen.dart';
import 'manage_banners_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_products_screen.dart';
import 'manage_users_screen.dart';
import 'stock_screen.dart';
import 'admin_sidebar_drawer.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFE8541A);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kBg = Color(0xFFF6F6F6);
const _kCard = Colors.white;
const _kBorder = Color(0xFFF1D4C8);
const _kTextDark = Color(0xFF1A1A1A);
const _kTextMid = Color(0xFF6B7280);

class ManageDeliveryScreen extends StatefulWidget {
  const ManageDeliveryScreen({super.key});
  static const routeName = '/admin/delivery';

  @override
  State<ManageDeliveryScreen> createState() => _ManageDeliveryScreenState();
}

class _ManageDeliveryScreenState extends State<ManageDeliveryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  // ── Local state — no Future needed ────────────────────────────────────────
  List<_DeliveryPartnerRow> _allPartners = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _filter = 'All';
  num _globalInitialPaymentAmount = 500;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await context.read<AppState>().adminUsers();
      final delivery = await context.read<AppState>().adminDeliveryPartners();
      final globalFee = await context
          .read<AppState>()
          .getDeliveryInitialPaymentSetting();
      if (!mounted) return;
      final deliveryByUserId = <String, Map<String, dynamic>>{};
      for (final item in delivery) {
        final u = item['user'];
        if (u is Map<String, dynamic>) {
          final uid = u['_id']?.toString() ?? u['id']?.toString();
          if (uid != null && uid.isNotEmpty) deliveryByUserId[uid] = item;
        } else if (u is String && u.isNotEmpty) {
          deliveryByUserId[u] = item;
        }
        final did = item['_id']?.toString() ?? item['id']?.toString();
        if (did != null && did.isNotEmpty) {
          deliveryByUserId[did] = item;
        }
      }
      setState(() {
        _globalInitialPaymentAmount = globalFee;
        _allPartners = users
            .where((u) => u.role == UserRoles.deliveryPerson)
            .map(
              (u) => _DeliveryPartnerRow(
                user: u,
                isOnline: _isOnlineFromBackend(
                  user: u,
                  deliveryDoc: deliveryByUserId[u.id],
                ),
                deliveryDoc: deliveryByUserId[u.id],
              ),
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Filter / search ───────────────────────────────────────────────────────
  List<_DeliveryPartnerRow> get _filtered {
    var items = List<_DeliveryPartnerRow>.from(_allPartners);
    if (_filter == 'Online') {
      items = items.where((u) => u.isOnline).toList();
    } else if (_filter == 'Offline') {
      items = items.where((u) => !u.isOnline).toList();
    } else if (_filter == 'Fee Paid') {
      items = items.where((u) => _isPartnerPaid(u.deliveryDoc)).toList();
    } else if (_filter == 'Fee Unpaid') {
      items = items.where((u) => !_isPartnerPaid(u.deliveryDoc)).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      items = items.where((u) {
        final paymentRef = (u.deliveryDoc?['initialPaymentReference'] ?? '')
            .toString()
            .toLowerCase();
        final paymentStatus = _isPartnerPaid(u.deliveryDoc)
            ? 'paid'
            : 'unpaid pending';
        return u.user.name.toLowerCase().contains(q) ||
            u.user.phone.toLowerCase().contains(q) ||
            u.user.id.toLowerCase().contains(q) ||
            (u.user.email ?? '').toLowerCase().contains(q) ||
            paymentRef.contains(q) ||
            paymentStatus.contains(q);
      }).toList();
    }
    return items;
  }

  // ── Add partner ───────────────────────────────────────────────────────────
  Future<void> _addPartner() async {
    final newUser = await showDialog<UserModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PartnerDialog(),
    );
    if (newUser == null || !mounted) return;
    await _load();
    _showSnack('${newUser.name} added');
  }

  // ── Edit partner ──────────────────────────────────────────────────────────
  Future<void> _editPartner(_DeliveryPartnerRow partner) async {
    final updated = await showDialog<UserModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PartnerDialog(
        user: partner.user,
        deliveryDoc: partner.deliveryDoc,
        fallbackAmount: _globalInitialPaymentAmount,
      ),
    );
    if (updated == null || !mounted) return;
    await _load();
    _showSnack('${updated.name} updated');
  }

  // ── Initial Payment Status Update ─────────────────────────────────────────
  Future<void> _updatePaymentStatus(_DeliveryPartnerRow partner) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentStatusDialog(
        partner: partner,
        fallbackAmount: _globalInitialPaymentAmount,
      ),
    );
    if (updated == true && mounted) {
      await _load();
    }
  }

  // ── Global Initial Payment Setting Dialog ─────────────────────────────────
  Future<void> _openEditGlobalAmountDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GlobalInitialPaymentDialog(
        currentAmount: _globalInitialPaymentAmount,
      ),
    );
    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _showStatusDetails(_DeliveryPartnerRow partner) async {
    final appState = context.read<AppState>();
    final loadLogs = () => appState.adminDeliveryStatusDetails(partner.user.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryStatusSheet(
        deliveryPerson: partner.user,
        isOnline: partner.isOnline,
        loadLogs: loadLogs,
      ),
    );
  }

  Future<void> _approvePartner(UserModel user) async {
    setState(() => _loading = true);
    try {
      await context.read<AppState>().updateAdminUser(
        userId: user.id,
        approvalStatus: 'approved',
        status: 'active',
      );
      if (!mounted) return;
      _showSnack('${user.name} approved');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Approve failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rejectPartner(UserModel user) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectPartnerDialog(user: user),
    );
    if (reason == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await context.read<AppState>().updateAdminUser(
        userId: user.id,
        approvalStatus: 'rejected',
        rejectionReason: reason,
      );
      if (!mounted) return;
      _showSnack('${user.name} rejected', error: true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Reject failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Delete partner ────────────────────────────────────────────────────────
  Future<void> _deletePartner(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(name: user.name),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<AppState>().deleteAdminUser(user.id);
      if (!mounted) return;
      await _load();
      _showSnack('${user.name} removed');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Delete failed: $e', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : _kOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      drawer: AdminSidebarDrawer(
        currentRoute: ManageDeliveryScreen.routeName,
        onLogout: () async {
          if (!await confirmAdminLogout(context)) return;
          Navigator.pop(context);
          final logoutRoute = context.read<AppState>().logoutRouteName;
          await context.read<AppState>().logout();
          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, logoutRoute, (_) => false);
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kOrange,
        onPressed: _addPartner,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text(
          'Add Partner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
    );
  }

  Widget _buildBody() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final partners = _filtered;
    final total = _allPartners.length;
    final online = _allPartners
        .where((u) => _statusLabel(u.user, isOnline: u.isOnline) == 'Online')
        .length;
    final offline = _allPartners
        .where((u) => _statusLabel(u.user, isOnline: u.isOnline) == 'Offline')
        .length;
    final paidCount = _allPartners
        .where((u) => _isPartnerPaid(u.deliveryDoc))
        .length;
    final unpaidCount = total - paidCount;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 100 + bottomInset),
      children: [
        // ── Header ──────────────────────────────────────────────────────
        _Header(
          onMenu: () => _scaffoldKey.currentState?.openDrawer(),
          onRefresh: _load,
        ),

        const SizedBox(height: 16),

        // ── Stats row ────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StatCard(
                label: 'Total Fleet',
                value: '$total',
                icon: Icons.groups_rounded,
                color: _kOrange,
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Online',
                value: '$online',
                icon: Icons.wifi_rounded,
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Offline',
                value: '$offline',
                icon: Icons.wifi_off_rounded,
                color: const Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Fee Paid',
                value: '$paidCount',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF059669),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Fee Pending',
                value: '$unpaidCount',
                icon: Icons.pending_actions_rounded,
                color: const Color(0xFFD97706),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Delivery Partner Payment Settings ──────────────────────────────
        _GlobalPaymentSettingCard(
          amount: _globalInitialPaymentAmount,
          onEdit: _openEditGlobalAmountDialog,
        ),

        const SizedBox(height: 16),

        // ── Search ───────────────────────────────────────────────────────
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search by name, ID, phone, ref…',
            prefixIcon: const Icon(Icons.search_rounded, color: _kOrange),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
            filled: true,
            fillColor: _kCard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _kOrange, width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Filter chips ─────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Chip(
                label: 'All ($total)',
                selected: _filter == 'All',
                onTap: () => setState(() => _filter = 'All'),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Online ($online)',
                selected: _filter == 'Online',
                onTap: () => setState(() => _filter = 'Online'),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Offline ($offline)',
                selected: _filter == 'Offline',
                onTap: () => setState(() => _filter = 'Offline'),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Fee Paid ($paidCount)',
                selected: _filter == 'Fee Paid',
                onTap: () => setState(() => _filter = 'Fee Paid'),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Fee Unpaid ($unpaidCount)',
                selected: _filter == 'Fee Unpaid',
                onTap: () => setState(() => _filter = 'Fee Unpaid'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Partner list ─────────────────────────────────────────────────
        if (partners.isEmpty)
          _EmptyState(onAdd: _addPartner)
        else
          ...partners.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _PartnerCard(
                user: u.user,
                isOnline: u.isOnline,
                deliveryDoc: u.deliveryDoc,
                fallbackAmount: _globalInitialPaymentAmount,
                onShowStatus: () => _showStatusDetails(u),
                onEditPayment: () => _updatePaymentStatus(u),
                onApprove: u.user.approvalStatus.toLowerCase() == 'pending'
                    ? () => _approvePartner(u.user)
                    : null,
                onReject: u.user.approvalStatus.toLowerCase() == 'pending'
                    ? () => _rejectPartner(u.user)
                    : null,
                onEdit: () => _editPartner(u),
                onDelete: () => _deletePartner(u.user),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onMenu, required this.onRefresh});
  final VoidCallback onMenu;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onMenu,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _kOrangeLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.menu_rounded, color: _kOrange),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Partners',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                  ),
                ),
                Text(
                  'Manage and track your delivery fleet',
                  style: TextStyle(fontSize: 12, color: _kTextMid),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _kOrangeLight,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.refresh_rounded, color: _kOrange),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kTextMid,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kOrange : _kCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _kOrange : _kBorder),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kOrange.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? Colors.white : _kTextDark,
          ),
        ),
      ),
    );
  }
}

// ─── Partner Card ─────────────────────────────────────────────────────────────

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.user,
    required this.isOnline,
    this.deliveryDoc,
    this.fallbackAmount = 500,
    required this.onShowStatus,
    required this.onEditPayment,
    this.onApprove,
    this.onReject,
    required this.onEdit,
    required this.onDelete,
  });
  final UserModel user;
  final bool isOnline;
  final Map<String, dynamic>? deliveryDoc;
  final num fallbackAmount;
  final VoidCallback onShowStatus;
  final VoidCallback onEditPayment;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 430;
    final status = _statusLabel(user, isOnline: isOnline);
    final vehicle = _vehicleFor(user);
    final isPaid = _isPartnerPaid(deliveryDoc);
    final feeAmount = isPaid
        ? _partnerInitialAmount(deliveryDoc, fallbackAmount)
        : fallbackAmount;
    final paymentRef = (deliveryDoc?['initialPaymentReference'] ?? '')
        .toString();
    final paymentDateStr = deliveryDoc?['initialPaymentCompletedAt'] != null
        ? _formatDate(deliveryDoc!['initialPaymentCompletedAt'])
        : '';
    final statusColor = switch (status) {
      'Online' => const Color(0xFF16A34A),
      _ => const Color(0xFF64748B),
    };
    final statusBg = switch (status) {
      'Online' => const Color(0xFFECFDF5),
      _ => const Color(0xFFF1F5F9),
    };

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: isCompact ? 25 : 28,
                          backgroundColor: _kOrangeLight,
                          backgroundImage: user.avatarUrl.isNotEmpty
                              ? NetworkImage(user.avatarUrl)
                              : null,
                          child: user.avatarUrl.isEmpty
                              ? Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: _kOrange,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _kTextDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '#${user.id.substring(0, 8).toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kTextMid,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              // Payment Badge
                              InkWell(
                                onTap: onEditPayment,
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPaid
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isPaid
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPaid
                                            ? Icons.check_circle_rounded
                                            : Icons.schedule_rounded,
                                        size: 12,
                                        color: isPaid
                                            ? const Color(0xFF047857)
                                            : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isPaid
                                            ? 'PAID • ₹${feeAmount.toInt()}'
                                            : 'UNPAID • ₹${feeAmount.toInt()}',
                                        style: TextStyle(
                                          color: isPaid
                                              ? const Color(0xFF047857)
                                              : const Color(0xFFB45309),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (!isCompact) ...[
                      const SizedBox(width: 10),
                      _PartnerActionButtons(
                        user: user,
                        isPaid: isPaid,
                        onApprove: onApprove,
                        onReject: onReject,
                        onShowStatus: onShowStatus,
                        onEditPayment: onEditPayment,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        vertical: true,
                      ),
                    ],
                  ],
                ),
                if (isCompact) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _PartnerActionButtons(
                      user: user,
                      isPaid: isPaid,
                      onApprove: onApprove,
                      onReject: onReject,
                      onShowStatus: onShowStatus,
                      onEditPayment: onEditPayment,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      vertical: false,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Initial Payment Bar on Card ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isPaid ? const Color(0xFFF9FDF9) : const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPaid
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEF3C7),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isStacked = constraints.maxWidth < 380;

                final iconWidget = Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPaid
                        ? Icons.verified_rounded
                        : Icons.pending_actions_rounded,
                    size: 15,
                    color: isPaid
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB45309),
                  ),
                );

                final infoWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        Text(
                          isPaid ? 'Initial Fee Paid' : 'Initial Fee Required',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isPaid
                                ? const Color(0xFF166534)
                                : const Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          '₹${feeAmount.toInt()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isPaid
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (isPaid && paymentRef.isNotEmpty)
                      Text(
                        'Ref: $paymentRef${paymentDateStr.isNotEmpty ? ' • $paymentDateStr' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (!isPaid)
                      const Text(
                        'Partner cannot go Online until onboarding fee is paid',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                );

                final buttonWidget = FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isPaid
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFF15803D),
                    foregroundColor: isPaid
                        ? const Color(0xFF166534)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onEditPayment,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid
                            ? Icons.verified_rounded
                            : Icons.check_circle_rounded,
                        size: 13,
                        color: isPaid ? const Color(0xFF166534) : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isPaid ? 'Payment Completed' : 'Mark as Paid',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isPaid
                                ? const Color(0xFF166534)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (isStacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          iconWidget,
                          const SizedBox(width: 10),
                          Expanded(child: infoWidget),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: buttonWidget,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 10),
                    Expanded(child: infoWidget),
                    const SizedBox(width: 8),
                    buttonWidget,
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF5F5F5)),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _PartnerMetaChip(
                  icon: Icons.electric_bike_rounded,
                  label: vehicle,
                  foreground: _kTextDark,
                  background: Colors.transparent,
                ),
                _PartnerMetaChip(
                  icon: Icons.phone_rounded,
                  label: user.phone.isEmpty ? 'No phone' : user.phone,
                  foreground: _kTextMid,
                  background: Colors.transparent,
                ),
                if ((user.email ?? '').isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isCompact ? 220 : 320,
                    ),
                    child: _PartnerMetaChip(
                      icon: Icons.email_rounded,
                      label: user.email!,
                      foreground: const Color(0xFF2563EB),
                      background: const Color(0xFFEFF6FF),
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

class _PartnerActionButtons extends StatelessWidget {
  const _PartnerActionButtons({
    required this.user,
    required this.isPaid,
    required this.onShowStatus,
    required this.onEditPayment,
    required this.onEdit,
    required this.onDelete,
    required this.vertical,
    this.onApprove,
    this.onReject,
  });

  final UserModel user;
  final bool isPaid;
  final VoidCallback onShowStatus;
  final VoidCallback onEditPayment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (user.approvalStatus.toLowerCase() == 'pending' &&
          onApprove != null) ...[
        _ActionBtn(
          icon: Icons.verified_rounded,
          color: const Color(0xFF15803D),
          bg: const Color(0xFFEAF7ED),
          tooltip: 'Approve registration',
          onTap: onApprove!,
        ),
        _ActionBtn(
          icon: Icons.cancel_outlined,
          color: const Color(0xFFBE123C),
          bg: const Color(0xFFFFF1F2),
          tooltip: 'Reject registration',
          onTap: onReject!,
        ),
      ],
      _ActionBtn(
        icon: Icons.timeline_rounded,
        color: const Color(0xFF4F46E5),
        bg: const Color(0xFFEFF2FF),
        tooltip: 'Show status',
        onTap: onShowStatus,
      ),
      _ActionBtn(
        icon: Icons.payments_rounded,
        color: isPaid ? const Color(0xFF15803D) : const Color(0xFFD97706),
        bg: isPaid ? const Color(0xFFEAF7ED) : const Color(0xFFFFFBEB),
        tooltip: isPaid
            ? 'Payment Completed (View Details)'
            : 'Mark Initial Payment as Paid',
        onTap: onEditPayment,
      ),
      _ActionBtn(
        icon: Icons.edit_rounded,
        color: _kOrange,
        bg: _kOrangeLight,
        tooltip: 'Edit partner',
        onTap: onEdit,
      ),
      _ActionBtn(
        icon: Icons.delete_outline_rounded,
        color: const Color(0xFFDC2626),
        bg: const Color(0xFFFFEEEE),
        tooltip: 'Delete partner',
        onTap: onDelete,
      ),
    ];

    if (vertical) {
      return Column(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            buttons[i],
          ],
        ],
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

class _PartnerMetaChip extends StatelessWidget {
  const _PartnerMetaChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: background == Colors.transparent
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: foreground == _kTextDark ? _kTextMid : foreground,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color, bg;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ─── Status Sheet ────────────────────────────────────────────────────────────

class _DeliveryStatusSheet extends StatefulWidget {
  const _DeliveryStatusSheet({
    required this.deliveryPerson,
    required this.isOnline,
    required this.loadLogs,
  });

  final UserModel deliveryPerson;
  final bool isOnline;
  final Future<List<Map<String, dynamic>>> Function() loadLogs;

  @override
  State<_DeliveryStatusSheet> createState() => _DeliveryStatusSheetState();
}

class _DeliveryStatusSheetState extends State<_DeliveryStatusSheet> {
  _StatusFilter _filter = _StatusFilter.all;
  late Future<List<Map<String, dynamic>>> _futureLogs;

  @override
  void initState() {
    super.initState();
    _futureLogs = widget.loadLogs();
  }

  void _refresh() {
    setState(() {
      _futureLogs = widget.loadLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Material(
        color: const Color(0xFFF7F7F7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _futureLogs,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _kOrange),
                );
              }

              if (snapshot.hasError) {
                return _SheetError(
                  message: snapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  onRetry: _refresh,
                );
              }

              final logs = snapshot.data ?? const <Map<String, dynamic>>[];
              final sortedLogs = List<Map<String, dynamic>>.from(logs)
                ..sort((a, b) {
                  final aStarted =
                      _parseLocalDate(a['startedAt'] as String?) ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bStarted =
                      _parseLocalDate(b['startedAt'] as String?) ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bStarted.compareTo(aStarted);
                });
              final filteredLogs = sortedLogs
                  .where((log) => _matches(log, _filter))
                  .toList();
              final activeLogs = filteredLogs.where(_isActiveLog).toList();
              final completedLogs = filteredLogs
                  .where((log) => !_isActiveLog(log))
                  .toList();
              final latestLog = sortedLogs.isNotEmpty ? sortedLogs.first : null;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.deliveryPerson.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: _kTextDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status history and timing breakdown',
                              style: TextStyle(
                                color: _kTextMid.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StatusSummaryCard(
                    isOnline: widget.isOnline,
                    latestLog: latestLog,
                  ),
                  const SizedBox(height: 16),
                  _StatusFilterBar(
                    filter: _filter,
                    onChanged: (filter) => setState(() => _filter = filter),
                  ),
                  const SizedBox(height: 16),
                  if (activeLogs.isNotEmpty) ...[
                    const _SheetSectionTitle('In Progress'),
                    const SizedBox(height: 10),
                    ...activeLogs.map((log) => _StatusLogCard(log: log)),
                    const SizedBox(height: 14),
                  ],
                  if (completedLogs.isNotEmpty) ...[
                    const _SheetSectionTitle('Completed'),
                    const SizedBox(height: 10),
                    ...completedLogs.map((log) => _StatusLogCard(log: log)),
                  ] else if (activeLogs.isEmpty)
                    const _StatusEmptyState(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  const _StatusSummaryCard({required this.isOnline, required this.latestLog});

  final bool isOnline;
  final Map<String, dynamic>? latestLog;

  @override
  Widget build(BuildContext context) {
    final active = latestLog != null && _isActiveLog(latestLog!);
    final startedAt = latestLog == null
        ? null
        : _parseLocalDate(latestLog!['startedAt'] as String?);
    final title = isOnline ? 'Online right now' : 'Offline right now';
    final subtitle = active && startedAt != null
        ? 'Active since ${_formatDateTime(startedAt)}'
        : 'No active shift at the moment';

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
              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: _kOrange,
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
                Text(title, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
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

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.filter, required this.onChanged});

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
          selectedColor: _kOrange,
          labelStyle: TextStyle(
            color: selected ? Colors.white : _kTextDark,
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide(color: selected ? _kOrange : _kBorder),
          backgroundColor: Colors.white,
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

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: _kTextDark,
      ),
    );
  }
}

class _SheetError extends StatelessWidget {
  const _SheetError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextDark),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

enum _StatusFilter { all, today, yesterday, week, month }

extension on _StatusFilter {
  String get label => switch (this) {
    _StatusFilter.all => 'All',
    _StatusFilter.today => 'Today',
    _StatusFilter.yesterday => 'Yesterday',
    _StatusFilter.week => 'Week',
    _StatusFilter.month => 'Month',
  };
}

bool _matches(Map<String, dynamic> log, _StatusFilter filter) {
  if (filter == _StatusFilter.all) return true;
  final startedAt = _parseLocalDate(log['startedAt'] as String?);
  if (startedAt == null) return false;
  final now = DateTime.now();
  return switch (filter) {
    _StatusFilter.all => true,
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

// ─── Delete Dialog ────────────────────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(
        Icons.person_off_rounded,
        color: Color(0xFFDC2626),
        size: 44,
      ),
      title: const Text(
        'Delete partner',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Text(
        'Remove "$name" from the delivery team?',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _RejectPartnerDialog extends StatefulWidget {
  const _RejectPartnerDialog({required this.user});
  final UserModel user;

  @override
  State<_RejectPartnerDialog> createState() => _RejectPartnerDialogState();
}

class _RejectPartnerDialogState extends State<_RejectPartnerDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a rejection reason')),
      );
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.cancel_outlined,
              color: Color(0xFFBE123C),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Reject Delivery Partner',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add a short reason for rejecting ${widget.user.name}.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Example: PAN card is unclear or licence is missing...',
                filled: true,
                fillColor: const Color(0xFFFDF8F4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFF1D4C8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFF1D4C8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE8541A)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFBE123C),
          ),
          onPressed: _submit,
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.delivery_dining_rounded,
            size: 56,
            color: Color(0xFFEEEEEE),
          ),
          const SizedBox(height: 12),
          const Text(
            'No partners found',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _kTextMid,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add a delivery partner to get started',
            style: TextStyle(color: _kTextMid, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _kOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text(
              'Add Partner',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusEmptyState extends StatelessWidget {
  const _StatusEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Text(
        'No status records found',
        textAlign: TextAlign.center,
        style: TextStyle(color: _kTextMid, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextMid),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kOrange),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Partner Dialog ───────────────────────────────────────────────────────────
// KEY FIX: returns UserModel directly instead of bool
// Parent updates _allPartners instantly without reload

class _PartnerDialog extends StatefulWidget {
  const _PartnerDialog({
    this.user,
    this.deliveryDoc,
    this.fallbackAmount = 500,
  });
  final UserModel? user;
  final Map<String, dynamic>? deliveryDoc;
  final num fallbackAmount;

  @override
  State<_PartnerDialog> createState() => _PartnerDialogState();
}

class _PartnerDialogState extends State<_PartnerDialog> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.user?.name ?? '',
  );
  late final TextEditingController _phoneCtrl = TextEditingController(
    text: widget.user?.phone ?? '',
  );
  late final TextEditingController _emailCtrl = TextEditingController(
    text: widget.user?.email ?? '',
  );
  late final TextEditingController _avatarCtrl = TextEditingController(
    text: widget.user?.avatarUrl ?? '',
  );
  late final TextEditingController _passwordCtrl = TextEditingController();
  late final TextEditingController _confirmCtrl = TextEditingController();
  late final TextEditingController _vehicleCtrl = TextEditingController(
    text: widget.deliveryDoc?['vehicleNumber']?.toString() ?? '',
  );
  late final TextEditingController _licenseCtrl = TextEditingController(
    text: widget.deliveryDoc?['licenseNumber']?.toString() ?? '',
  );

  late final bool _origPaid;
  late String _paymentStatus;
  late final TextEditingController _paymentRefCtrl;

  Uint8List? _avatarBytes;
  bool _uploading = false;
  String? _uploadingField;
  bool _saving = false;
  String? _uploadError;
  String? _saveError;
  String? _panCardUrl;
  String? _licenseCardUrl;
  String? _aadhaarCardUrl;
  String? _panCardName;
  String? _licenseCardName;
  String? _aadhaarCardName;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final rawStatus = widget.deliveryDoc?['initialPaymentStatus']
        ?.toString()
        .toUpperCase();
    _origPaid = (rawStatus == 'PAID');
    _paymentStatus = _origPaid ? 'PAID' : 'UNPAID';
    _paymentRefCtrl = TextEditingController(
      text: widget.deliveryDoc?['initialPaymentReference']?.toString() ?? '',
    );
    _panCardUrl = widget.deliveryDoc?['panCardUrl']?.toString();
    _licenseCardUrl = widget.deliveryDoc?['licenseCardUrl']?.toString();
    _aadhaarCardUrl = widget.deliveryDoc?['aadhaarCardUrl']?.toString();
    _panCardName = (_panCardUrl ?? '').isNotEmpty ? 'Uploaded file' : null;
    _licenseCardName = (_licenseCardUrl ?? '').isNotEmpty
        ? 'Uploaded file'
        : null;
    _aadhaarCardName = (_aadhaarCardUrl ?? '').isNotEmpty
        ? 'Uploaded file'
        : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _avatarCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _vehicleCtrl.dispose();
    _licenseCtrl.dispose();
    _paymentRefCtrl.dispose();
    super.dispose();
  }

  // ── Pick & upload avatar ──────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    setState(() {
      _uploading = true;
      _uploadError = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) {
        setState(() => _uploading = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      final url = await context.read<AppState>().uploadProductImage(
        picked.path,
        bytes: bytes,
        fileName: picked.name,
      );
      if (!mounted) return;
      setState(() {
        _avatarCtrl.text = url;
        _avatarBytes = bytes;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadError =
            'Upload failed: ${e.toString().replaceFirst('Exception: ', '')}';
        _uploading = false;
      });
    }
  }

  Future<void> _pickDocument({
    required String field,
    required void Function(String url) onSelected,
    required void Function(String name) onNameSelected,
  }) async {
    setState(() {
      _uploadingField = field;
      _saveError = null;
      _uploadError = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) {
        if (mounted) setState(() => _uploadingField = null);
        return;
      }
      final bytes = await picked.readAsBytes();
      final url = await context.read<AppState>().uploadProductImage(
        picked.path,
        bytes: bytes,
        fileName: picked.name,
      );
      if (!mounted) return;
      setState(() {
        onSelected(url);
        onNameSelected(picked.name);
        _uploadingField = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadError =
            'Upload failed: ${e.toString().replaceFirst('Exception: ', '')}';
        _uploadingField = null;
      });
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _saveError = 'Name is required');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _saveError = 'Phone is required');
      return;
    }
    if (_saving) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final state = context.read<AppState>();
      UserModel saved;

      if (!_isEdit) {
        if (_passwordCtrl.text.trim().isEmpty) {
          setState(() => _saveError = 'Password is required');
          return;
        }
        if (_confirmCtrl.text.trim() != _passwordCtrl.text.trim()) {
          setState(() => _saveError = 'Passwords do not match');
          return;
        }
        if (_vehicleCtrl.text.trim().isEmpty) {
          setState(() => _saveError = 'Vehicle number is required');
          return;
        }
        if (_licenseCtrl.text.trim().isEmpty) {
          setState(() => _saveError = 'Licence number is required');
          return;
        }
        if (_licenseCardUrl == null) {
          setState(() => _saveError = 'Licence photo is required');
          return;
        }
        saved = await state.createAdminUser(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          avatarUrl: _avatarCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          role: UserRoles.deliveryPerson,
          vehicleNumber: _vehicleCtrl.text.trim(),
          licenseNumber: _licenseCtrl.text.trim(),
          licenseCardUrl: _licenseCardUrl ?? '',
          panCardUrl: _panCardUrl ?? '',
          aadhaarCardUrl: _aadhaarCardUrl ?? '',
        );
      } else {
        if (_passwordCtrl.text.trim().isNotEmpty &&
            _confirmCtrl.text.trim() != _passwordCtrl.text.trim()) {
          setState(() => _saveError = 'Passwords do not match');
          return;
        }
        saved = await state.updateAdminUser(
          userId: widget.user!.id,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          avatarUrl: _avatarCtrl.text.trim(),
          password: _passwordCtrl.text.trim().isEmpty
              ? null
              : _passwordCtrl.text.trim(),
          role: UserRoles.deliveryPerson,
          status: widget.user!.status,
          vehicleNumber: _vehicleCtrl.text.trim(),
          licenseNumber: _licenseCtrl.text.trim(),
          licenseCardUrl: _licenseCardUrl,
          panCardUrl: _panCardUrl,
          aadhaarCardUrl: _aadhaarCardUrl,
        );

        final deliveryId =
            widget.deliveryDoc?['_id']?.toString() ??
            widget.deliveryDoc?['id']?.toString() ??
            widget.user!.id;
        final newRefStr = _paymentRefCtrl.text.trim();

        // Only allow updating from UNPAID -> PAID (completed payments cannot be revoked)
        if (!_origPaid && _paymentStatus == 'PAID') {
          try {
            await state.updateDeliveryPaymentStatus(
              deliveryPersonId: deliveryId,
              status: 'PAID',
              reference: newRefStr.isEmpty ? null : newRefStr,
              notes: 'Marked as PAID via Partner Edit dialog',
            );
          } catch (e) {
            debugPrint(
              '[ManageDelivery] Failed to update payment status in edit dialog: $e',
            );
          }
        }
      }

      if (!mounted) return;
      // Pop with the saved UserModel — parent updates list instantly
      Navigator.of(context, rootNavigator: true).pop(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saveError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 600;
    final dialogWidth = isMobile ? size.width - 20 : 640.0;
    final dialogHeight = isMobile ? size.height - 24 : size.height * 0.86;

    return AlertDialog(
      backgroundColor: const Color(0xFFF7F7F8),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 22 : 28),
      ),
      titlePadding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 20,
        isMobile ? 16 : 20,
        isMobile ? 16 : 20,
        0,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        isMobile ? 14 : 20,
        12,
        isMobile ? 14 : 20,
        8,
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        isMobile ? 14 : 16,
        0,
        isMobile ? 14 : 16,
        isMobile ? 14 : 20,
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF26522), Color(0xFFD44010)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isEdit ? 'Edit Delivery Partner' : 'Add Delivery Partner',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _kTextDark,
                fontSize: isMobile ? 16 : 17,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              _SectionHeader(
                title: 'Profile',
                subtitle: 'Photo and identity details',
              ),

              const SizedBox(height: 12),

              _AvatarSection(
                bytes: _avatarBytes,
                existingUrl: widget.user?.avatarUrl ?? '',
                uploading: _uploading,
                uploadError: _uploadError,
                onPick: _pickAvatar,
              ),

              const SizedBox(height: 14),

              _SectionHeader(
                title: 'Documents',
                subtitle: 'PAN, licence and Aadhaar verification',
              ),

              const SizedBox(height: 12),

              _DocumentUploadCard(
                title: 'PAN card photo',
                subtitle: 'Upload a clear photo or scan of the PAN card.',
                value: _panCardName ?? '',
                uploading: _uploadingField == 'pan',
                onTap: () => _pickDocument(
                  field: 'pan',
                  onSelected: (url) => _panCardUrl = url,
                  onNameSelected: (name) => _panCardName = name,
                ),
                onClear: _panCardUrl != null
                    ? () {
                        setState(() {
                          _panCardUrl = null;
                          _panCardName = null;
                        });
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              _DocumentUploadCard(
                title: 'Licence photo',
                subtitle:
                    'Upload a clear photo or scan of the driving licence.',
                value: _licenseCardName ?? '',
                uploading: _uploadingField == 'license',
                onTap: () => _pickDocument(
                  field: 'license',
                  onSelected: (url) => _licenseCardUrl = url,
                  onNameSelected: (name) => _licenseCardName = name,
                ),
                onClear: _licenseCardUrl != null
                    ? () {
                        setState(() {
                          _licenseCardUrl = null;
                          _licenseCardName = null;
                        });
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              _DocumentUploadCard(
                title: 'Aadhaar card photo',
                subtitle: 'Upload the front side or a clear scan of Aadhaar.',
                value: _aadhaarCardName ?? '',
                uploading: _uploadingField == 'aadhaar',
                onTap: () => _pickDocument(
                  field: 'aadhaar',
                  onSelected: (url) => _aadhaarCardUrl = url,
                  onNameSelected: (name) => _aadhaarCardName = name,
                ),
                onClear: _aadhaarCardUrl != null
                    ? () {
                        setState(() {
                          _aadhaarCardUrl = null;
                          _aadhaarCardName = null;
                        });
                      }
                    : null,
              ),

              const SizedBox(height: 14),

              _SectionHeader(
                title: 'Basic Details',
                subtitle: 'Contact and vehicle information',
              ),

              const SizedBox(height: 12),

              _DialogField(
                controller: _vehicleCtrl,
                label: 'Vehicle number *',
                icon: Icons.two_wheeler_rounded,
              ),

              const SizedBox(height: 16),

              _DialogField(
                controller: _licenseCtrl,
                label: 'Licence number *',
                icon: Icons.drive_eta_rounded,
              ),

              const SizedBox(height: 16),

              // ── Name ──────────────────────────────────────────────
              _DialogField(
                controller: _nameCtrl,
                label: 'Full name *',
                icon: Icons.person_rounded,
              ),

              // ── Phone ─────────────────────────────────────────────
              _DialogField(
                controller: _phoneCtrl,
                label: 'Phone number *',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),

              // ── Email ─────────────────────────────────────────────
              _DialogField(
                controller: _emailCtrl,
                label: 'Email (optional)',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),

              // ── Password ─────────────────────────────────────────────
              _DialogField(
                controller: _passwordCtrl,
                label: _isEdit
                    ? 'Password (leave blank to keep current)'
                    : 'Password *',
                icon: Icons.lock_rounded,
                obscureText: true,
              ),

              _DialogField(
                controller: _confirmCtrl,
                label: _isEdit
                    ? 'Confirm password (if changing)'
                    : 'Confirm password *',
                icon: Icons.lock_outline_rounded,
                obscureText: true,
              ),

              if (_isEdit) ...[
                const SizedBox(height: 16),
                _SectionHeader(
                  title: 'Initial Onboarding Fee',
                  subtitle: _origPaid
                      ? 'Payment has been completed and verified'
                      : 'Authorize initial onboarding payment',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (_origPaid || _paymentStatus == 'PAID')
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFDBA74),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            (_origPaid || _paymentStatus == 'PAID')
                                ? Icons.check_circle_rounded
                                : Icons.pending_actions_rounded,
                            color: (_origPaid || _paymentStatus == 'PAID')
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEA580C),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Payment Status',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _kTextDark,
                            ),
                          ),
                          const Spacer(),
                          if (_origPaid)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: const Text(
                                'PAID',
                                style: TextStyle(
                                  color: Color(0xFF15803D),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          else
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'UNPAID',
                                  label: Text(
                                    'Unpaid',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                ButtonSegment(
                                  value: 'PAID',
                                  label: Text(
                                    'Mark as Paid',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              selected: {_paymentStatus},
                              onSelectionChanged: (val) {
                                setState(() {
                                  _paymentStatus = val.first;
                                });
                              },
                              style: SegmentedButton.styleFrom(
                                selectedBackgroundColor:
                                    _paymentStatus == 'PAID'
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFFEDD5),
                                selectedForegroundColor:
                                    _paymentStatus == 'PAID'
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFEA580C),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Read-only Fee Amount Display
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _origPaid
                                  ? 'Onboarding Fee (Paid)'
                                  : 'Onboarding Fee (Global Setting)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kTextMid,
                              ),
                            ),
                            Text(
                              '₹${_partnerInitialAmount(widget.deliveryDoc).toInt()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: _kTextDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_origPaid) ...[
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: Color(0xFF15803D),
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Completed onboarding payments cannot be changed to unpaid.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF15803D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (_paymentStatus == 'PAID') ...[
                        const SizedBox(height: 12),
                        _DialogField(
                          controller: _paymentRefCtrl,
                          label: 'Payment Reference / Order ID (optional)',
                          icon: Icons.tag_rounded,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Marking as Paid will authorize this partner to go online. This action is permanent.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // ── Save error ────────────────────────────────────────
              if (_saveError != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        _PartnerDialogActions(
          saving: _saving,
          isEdit: _isEdit,
          onCancel: () => Navigator.pop(context, null),
          onSave: _save,
        ),
      ],
    );
  }
}

class _PartnerDialogActions extends StatelessWidget {
  const _PartnerDialogActions({
    required this.saving,
    required this.isEdit,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final bool isEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final cancelButton = TextButton(
      onPressed: saving ? null : onCancel,
      child: const Text('Cancel', style: TextStyle(color: _kTextMid)),
    );
    final saveButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: _kOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: saving ? null : onSave,
      icon: saving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              isEdit ? Icons.save_rounded : Icons.person_add_rounded,
              size: 18,
            ),
      label: Text(
        saving ? 'Saving…' : (isEdit ? 'Save changes' : 'Add partner'),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    if (isMobile) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [saveButton, const SizedBox(height: 8), cancelButton],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [cancelButton, const SizedBox(width: 8), saveButton],
    );
  }
}

// ─── Avatar Section ───────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.bytes,
    required this.existingUrl,
    required this.uploading,
    required this.uploadError,
    required this.onPick,
  });

  final Uint8List? bytes;
  final String existingUrl;
  final bool uploading;
  final String? uploadError;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasExisting = existingUrl.startsWith('http');

    return GestureDetector(
      onTap: uploading ? null : onPick,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile photo (optional)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kBorder),
            ),
            child: uploading
                ? const Center(
                    child: CircularProgressIndicator(color: _kOrange),
                  )
                : bytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.memory(
                      bytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  )
                : hasExisting
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.network(
                      existingUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _AvatarPlaceholder(),
                    ),
                  )
                : const _AvatarPlaceholder(),
          ),
          if (uploadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                uploadError!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                bytes != null || hasExisting
                    ? '✅ Photo ready — tap to change'
                    : 'Tap to upload a photo',
                style: TextStyle(
                  fontSize: 12,
                  color: bytes != null || hasExisting
                      ? const Color(0xFF16A34A)
                      : _kTextMid,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 32, color: _kOrange),
          SizedBox(height: 6),
          Text(
            'Tap to upload',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _kTextMid,
              fontSize: 13,
            ),
          ),
          Text('PNG or JPG', style: TextStyle(fontSize: 11, color: _kTextMid)),
        ],
      ),
    );
  }
}

// ─── Dialog Field ─────────────────────────────────────────────────────────────

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: _kTextMid),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kOrange, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _DocumentUploadCard extends StatelessWidget {
  const _DocumentUploadCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.uploading,
    required this.onTap,
    required this.onClear,
  });

  final String title;
  final String subtitle;
  final String value;
  final bool uploading;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    return Material(
      color: hasValue ? const Color(0xFFFFF0EB) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: uploading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasValue ? const Color(0xFFF3C3AF) : _kBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: hasValue
                      ? const Color(0xFFFCE7DF)
                      : const Color(0xFFFFF0EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasValue ? Icons.verified_rounded : Icons.upload_file_rounded,
                  color: hasValue ? _kOrange : const Color(0xFFC63A0E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _kTextMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      uploading
                          ? 'Uploading...'
                          : (hasValue ? value : 'Tap to upload'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: hasValue ? _kOrange : _kTextMid,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (uploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(_kOrange),
                  ),
                )
              else if (onClear != null && hasValue) ...[
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(foregroundColor: _kOrange),
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ] else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB4B4C4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: _kTextMid,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Admin Drawer ─────────────────────────────────────────────────────────────

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.onNavigate, required this.onLogout});
  final void Function(String) onNavigate;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin =
        context.read<AppState>().user?.role == UserRoles.superAdmin;

    final items = [
      ('Overview', Icons.dashboard_rounded, AdminDashboardScreen.routeName),
      ('Orders', Icons.receipt_long_rounded, AdminOrdersScreen.routeName),
      if (isSuperAdmin)
        (
          'Notifications',
          Icons.notifications_active_rounded,
          AdminNotificationsScreen.routeName,
        ),
      ('Products', Icons.inventory_2_rounded, ManageProductsScreen.routeName),
      if (isSuperAdmin)
        (
          'Categories',
          Icons.category_rounded,
          ManageCategoriesScreen.routeName,
        ),
      if (isSuperAdmin)
        ('Banners', Icons.slideshow_rounded, ManageBannersScreen.routeName),
      if (isSuperAdmin)
        ('Users', Icons.groups_rounded, ManageUsersScreen.routeName),
      if (isSuperAdmin)
        (
          'Delivery partners',
          Icons.delivery_dining_rounded,
          ManageDeliveryScreen.routeName,
        ),
      ('Stock alerts', Icons.warning_amber_rounded, StockScreen.routeName),
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
                    backgroundColor: _kOrangeLight,
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: _kOrange,
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
                            color: _kTextDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Navigate the control centre',
                          style: TextStyle(color: _kTextMid, fontSize: 12),
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
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final sel = item.$3 == ManageDeliveryScreen.routeName;
                  return Material(
                    color: sel ? _kOrangeLight : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onNavigate(item.$3),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _kOrange.withValues(
                                  alpha: sel ? 0.18 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item.$2,
                                color: sel ? _kOrange : const Color(0xFF555555),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.$1,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: sel ? _kOrange : _kTextDark,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: sel ? _kOrange : const Color(0xFFCCCCCC),
                              size: 18,
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
                    foregroundColor: _kOrange,
                    side: const BorderSide(color: _kOrange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: _kOrangeLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _DeliveryPartnerRow {
  const _DeliveryPartnerRow({
    required this.user,
    required this.isOnline,
    this.deliveryDoc,
  });

  final UserModel user;
  final bool isOnline;
  final Map<String, dynamic>? deliveryDoc;
}

bool _isOnlineFromBackend({
  required UserModel user,
  Map<String, dynamic>? deliveryDoc,
}) {
  final isOnline = deliveryDoc?['isOnline'];
  if (isOnline is bool) return isOnline;
  final deliveryUser = deliveryDoc?['user'];
  if (deliveryUser is Map<String, dynamic>) {
    final deliveryStatus = (deliveryUser['status'] ?? '')
        .toString()
        .toLowerCase();
    if (deliveryStatus == 'online') return true;
    if (deliveryStatus == 'offline') return false;
  }
  return false;
}

String _statusLabel(UserModel user, {required bool isOnline}) {
  return isOnline ? 'Online' : 'Offline';
}

String _vehicleFor(UserModel user) {
  final n = user.name.toLowerCase();
  if (n.contains('bike')) return 'Bike';
  if (n.contains('van')) return 'Van';
  if (n.contains('scooter')) return 'E-Scooter';
  return 'E-Bike';
}

bool _isPartnerPaid(Map<String, dynamic>? deliveryDoc) {
  final status = (deliveryDoc?['initialPaymentStatus'] ?? '')
      .toString()
      .toUpperCase();
  return status == 'PAID';
}

num _partnerInitialAmount(
  Map<String, dynamic>? deliveryDoc, [
  num fallback = 500,
]) {
  final raw = deliveryDoc?['initialPaymentAmount'];
  if (raw is num && raw > 0) return raw;
  if (raw != null) {
    final parsed = num.tryParse(raw.toString());
    if (parsed != null && parsed > 0) return parsed;
  }
  return fallback;
}

String _formatDate(dynamic date) {
  if (date == null) return '';
  final dt = date is DateTime ? date : DateTime.tryParse(date.toString());
  if (dt == null) return date.toString();
  final local = dt.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  final y = local.year;
  final hour = local.hour > 12
      ? local.hour - 12
      : (local.hour == 0 ? 12 : local.hour);
  final min = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour >= 12 ? 'PM' : 'AM';
  return '$d/$m/$y $hour:$min $ampm';
}

// ─── Global Initial Payment Setting Card ──────────────────────────────────────

class _GlobalPaymentSettingCard extends StatelessWidget {
  const _GlobalPaymentSettingCard({required this.amount, required this.onEdit});

  final num amount;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 18,
            vertical: isCompact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 10 : 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: const Color(0xFF2563EB),
                  size: isCompact ? 20 : 24,
                ),
              ),
              SizedBox(width: isCompact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        const Text(
                          'Initial Payment',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _kTextDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: const Text(
                            'GLOBAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${amount.toInt()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Standard onboarding fee for all new delivery partners',
                      style: TextStyle(
                        fontSize: 11,
                        color: _kTextMid,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kTextDark,
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 14,
                    vertical: isCompact ? 8 : 10,
                  ),
                ),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text(
                  'Edit',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Global Initial Payment Setting Dialog ────────────────────────────────────

class _GlobalInitialPaymentDialog extends StatefulWidget {
  const _GlobalInitialPaymentDialog({required this.currentAmount});
  final num currentAmount;

  @override
  State<_GlobalInitialPaymentDialog> createState() =>
      _GlobalInitialPaymentDialogState();
}

class _GlobalInitialPaymentDialogState
    extends State<_GlobalInitialPaymentDialog> {
  late final TextEditingController _amountCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.currentAmount.toInt().toString(),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _amountCtrl.text.trim();
    final amount = num.tryParse(text);
    if (amount == null || amount < 0) {
      setState(() => _error = 'Please enter a valid amount (₹0 or more)');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await context.read<AppState>().updateDeliveryInitialPaymentSetting(
        amount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Initial payment amount updated successfully.'),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.of(context, rootNavigator: true).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.settings_suggest_rounded,
              color: Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Initial Payment Amount',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _kTextDark,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configures the global onboarding fee for all new delivery partner registrations.',
              style: TextStyle(fontSize: 12, color: _kTextMid),
            ),
            const SizedBox(height: 16),
            _DialogField(
              controller: _amountCtrl,
              label: 'Initial Payment Amount (₹)',
              icon: Icons.currency_rupee_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Text(
              'Current value: ₹${widget.currentAmount.toInt()}',
              style: const TextStyle(
                fontSize: 11,
                color: _kTextMid,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: _kTextMid)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _kOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Save Changes',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }
}

// ─── Payment Status Dialog ───────────────────────────────────────────────────

class _PaymentStatusDialog extends StatefulWidget {
  const _PaymentStatusDialog({
    required this.partner,
    this.fallbackAmount = 500,
  });

  final _DeliveryPartnerRow partner;
  final num fallbackAmount;

  @override
  State<_PaymentStatusDialog> createState() => _PaymentStatusDialogState();
}

class _PaymentStatusDialogState extends State<_PaymentStatusDialog> {
  late final bool _isCurrentlyPaid;
  late final num _effectiveAmount;
  late final TextEditingController _referenceCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isCurrentlyPaid = _isPartnerPaid(widget.partner.deliveryDoc);
    _effectiveAmount = _partnerInitialAmount(
      widget.partner.deliveryDoc,
      widget.fallbackAmount,
    );
    _referenceCtrl = TextEditingController(
      text:
          widget.partner.deliveryDoc?['initialPaymentReference']?.toString() ??
          '',
    );
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final docId =
          widget.partner.deliveryDoc?['_id']?.toString() ??
          widget.partner.deliveryDoc?['id']?.toString() ??
          widget.partner.user.id;

      await context.read<AppState>().updateDeliveryPaymentStatus(
        deliveryPersonId: docId,
        status: 'PAID',
        amount: _effectiveAmount,
        reference: _referenceCtrl.text.trim().isEmpty
            ? null
            : _referenceCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Initial payment marked as paid successfully.'),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.of(context, rootNavigator: true).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 500;
    final user = widget.partner.user;
    final shortId = '#${user.id.substring(0, 8).toUpperCase()}';
    final paymentRef =
        widget.partner.deliveryDoc?['initialPaymentReference']?.toString() ??
        '';
    final paymentDateStr =
        widget.partner.deliveryDoc?['initialPaymentCompletedAt'] != null
        ? _formatDate(widget.partner.deliveryDoc!['initialPaymentCompletedAt'])
        : '';
    final paymentSource =
        widget.partner.deliveryDoc?['initialPaymentSource']?.toString() ?? '';

    return AlertDialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isCurrentlyPaid
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isCurrentlyPaid
                  ? Icons.verified_rounded
                  : Icons.payments_rounded,
              color: _isCurrentlyPaid
                  ? const Color(0xFF047857)
                  : const Color(0xFFD97706),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCurrentlyPaid
                      ? 'Initial Payment Details'
                      : 'Mark Initial Payment as Paid',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                  ),
                ),
                Text(
                  _isCurrentlyPaid
                      ? 'Verified partner onboarding payment'
                      : 'Authorize partner to start working and go online',
                  style: const TextStyle(fontSize: 12, color: _kTextMid),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Partner Card Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _kOrangeLight,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: _kOrange,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _kTextDark,
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                shortId,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: _kTextMid,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                user.phone,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _kTextMid,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isCurrentlyPaid
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _isCurrentlyPaid
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Text(
                        _isCurrentlyPaid ? 'PAID' : 'UNPAID',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _isCurrentlyPaid
                              ? const Color(0xFF047857)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Read-only Fee Container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(
                        Icons.currency_rupee_rounded,
                        size: 20,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCurrentlyPaid
                                ? 'Onboarding Fee Paid'
                                : 'Initial Payment Amount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kTextMid,
                            ),
                          ),
                          Text(
                            '₹${_effectiveAmount.toInt()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _kTextDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        _isCurrentlyPaid ? 'VERIFIED' : 'GLOBAL SETTING',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _kTextMid,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (_isCurrentlyPaid) ...[
                // Details for already paid partner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: Color(0xFF047857),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payment Complete & Verified',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This delivery partner has fulfilled the onboarding payment requirement and is eligible to accept delivery orders and go online.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFA7F3D0)),
                      const SizedBox(height: 10),
                      if (paymentRef.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text(
                              'Reference / ID: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF065F46),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                paymentRef,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (paymentDateStr.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text(
                              'Payment Date: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF065F46),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                paymentDateStr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (paymentSource.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text(
                              'Payment Source: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF065F46),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                paymentSource,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      const SizedBox(height: 4),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: Color(0xFF047857),
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Completed onboarding payments cannot be reverted to unpaid.',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Unpaid partner - prompt & inputs
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Are you sure you want to mark this partner as Paid?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'This confirms onboarding payment and authorizes the partner to go online. Note: Once marked as Paid, this payment cannot be reverted to unpaid.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: Color(0xFF78350F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                _DialogField(
                  controller: _referenceCtrl,
                  label: 'Payment Reference / Order ID (Optional)',
                  icon: Icons.receipt_long_rounded,
                ),

                const SizedBox(height: 12),

                _DialogField(
                  controller: _notesCtrl,
                  label: 'Admin Audit Notes (Optional)',
                  icon: Icons.edit_note_rounded,
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_isCurrentlyPaid)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kTextDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          )
        else ...[
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _kTextMid)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Confirm & Mark as Paid',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ],
    );
  }
}

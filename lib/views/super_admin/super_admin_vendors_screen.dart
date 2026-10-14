import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/vendor_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../widgets/pagination_controls.dart';
import '../../features/operations/services/location_service.dart';
import '../admin/admin_sidebar_drawer.dart';

String _formatVendorDisplayId(String? vendorId, String? id) {
  final normalized = (vendorId ?? '').trim();
  final upper = normalized.toUpperCase();
  if (upper.startsWith('DMD-VENDOR-')) return upper;

  final source = (id ?? normalized).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  if (source.isEmpty) return 'DMD-VENDOR-0000';
  final suffix = source.length >= 4
      ? source.substring(source.length - 4)
      : source.padLeft(4, '0');
  return 'DMD-VENDOR-${suffix.toUpperCase()}';
}

class SuperAdminVendorsScreen extends StatefulWidget {
  const SuperAdminVendorsScreen({super.key});

  static const routeName = '/super-admin/vendors';

  @override
  State<SuperAdminVendorsScreen> createState() =>
      _SuperAdminVendorsScreenState();
}

class _SuperAdminVendorsScreenState extends State<SuperAdminVendorsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<VendorModel>> _vendorsFuture;
  String _query = '';
  String _selectedFilter = 'All';
  final Set<String> _updatingVendors = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _filterOptions = const [
    'All',
    'Pending',
    'Approved',
    'Rejected',
    'Suspended',
  ];

  @override
  void initState() {
    super.initState();
    _vendorsFuture = _loadVendors();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  Future<List<VendorModel>> _loadVendors() {
    return context.read<AppState>().adminVendors();
  }

  List<VendorModel> _filteredVendors(List<VendorModel> vendors) {
    final query = _query.trim().toLowerCase();
    var filtered = vendors;

    if (_selectedFilter != 'All') {
      filtered = filtered.where((vendor) {
        return vendor.approvalStatus.toLowerCase() ==
            _selectedFilter.toLowerCase();
      }).toList();
    }

    if (query.isNotEmpty) {
      filtered = filtered.where((vendor) {
        final displayId = _formatVendorDisplayId(vendor.vendorId, vendor.id);
        return vendor.name.toLowerCase().contains(query) ||
            vendor.vendorId.toLowerCase().contains(query) ||
            displayId.toLowerCase().contains(query) ||
            vendor.ownerName.toLowerCase().contains(query) ||
            vendor.phone.toLowerCase().contains(query) ||
            (vendor.email ?? '').toLowerCase().contains(query) ||
            vendor.gstin.toLowerCase().contains(query) ||
            vendor.city.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _createVendor() async {
    final created = await showDialog<VendorModel?>(
      context: context,
      useSafeArea: true,
      builder: (context) => const _VendorFormDialog(),
    );
    if (!mounted || created == null) return;
    _showSnackBar(
      '${created.name} created successfully',
      Icons.check_circle,
      const Color(0xFFE8541A),
    );
    setState(() => _vendorsFuture = _loadVendors());
  }

  Future<void> _editVendor(VendorModel vendor) async {
    final updated = await showDialog<VendorModel?>(
      context: context,
      useSafeArea: true,
      builder: (context) => _VendorFormDialog(vendor: vendor),
    );
    if (!mounted || updated == null) return;
    _showSnackBar(
      '${updated.name} updated successfully',
      Icons.check_circle,
      const Color(0xFFE8541A),
    );
    setState(() => _vendorsFuture = _loadVendors());
  }

  Future<void> _viewVendor(VendorModel vendor) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _VendorDetailsDialog(vendor: vendor),
    );
  }

  Future<void> _approveVendor(VendorModel vendor) async {
    await _updateApprovalStatus(
      vendor,
      approvalStatus: 'approved',
      snackMessage: '${vendor.name} approved',
    );
  }

  Future<void> _suspendVendor(VendorModel vendor) async {
    await _updateApprovalStatus(
      vendor,
      approvalStatus: 'suspended',
      snackMessage: '${vendor.name} suspended',
    );
  }

  Future<void> _rejectVendor(VendorModel vendor) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectVendorDialog(vendor: vendor),
    );
    if (reason == null) return;
    await _updateApprovalStatus(
      vendor,
      approvalStatus: 'rejected',
      rejectionReason: reason,
      snackMessage: '${vendor.name} rejected',
    );
  }

  Future<void> _updateApprovalStatus(
    VendorModel vendor, {
    required String approvalStatus,
    String rejectionReason = '',
    required String snackMessage,
  }) async {
    setState(() => _updatingVendors.add(vendor.id));
    try {
      await context.read<AppState>().updateVendor(
        vendorId: vendor.id,
        approvalStatus: approvalStatus,
        rejectionReason: rejectionReason,
      );
      if (!mounted) return;
      _showSnackBar(snackMessage, Icons.verified_user, const Color(0xFFE8541A));
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(
        error.message,
        Icons.error_outline,
        const Color(0xFFBE123C),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingVendors.remove(vendor.id);
          _vendorsFuture = _loadVendors();
        });
      }
    }
  }

  Future<void> _toggleStatus(VendorModel vendor) async {
    final nextStatus = vendor.status.toLowerCase() == 'active'
        ? 'inactive'
        : 'active';
    setState(() => _updatingVendors.add(vendor.id));
    try {
      await context.read<AppState>().updateVendor(
        vendorId: vendor.id,
        status: nextStatus,
      );
      if (!mounted) return;
      _showSnackBar(
        nextStatus == 'active'
            ? '${vendor.name} activated'
            : '${vendor.name} deactivated',
        nextStatus == 'active'
            ? Icons.verified_user
            : Icons.pause_circle_outline,
        nextStatus == 'active'
            ? const Color(0xFFE8541A)
            : const Color(0xFFB45309),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(
        error.message,
        Icons.error_outline,
        const Color(0xFFBE123C),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingVendors.remove(vendor.id);
          _vendorsFuture = _loadVendors();
        });
      }
    }
  }

  Future<void> _deleteVendor(VendorModel vendor) async {
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteVendorDialog(vendor: vendor),
    );
    if (confirmed != true) return;

    setState(() => _updatingVendors.add(vendor.id));
    try {
      await state.deleteVendor(vendor.id);
      if (!mounted) return;
      _showSnackBar(
        '${vendor.name} deleted',
        Icons.delete,
        const Color(0xFFBE123C),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(
        error.message,
        Icons.error_outline,
        const Color(0xFFBE123C),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingVendors.remove(vendor.id);
          _vendorsFuture = _loadVendors();
        });
      }
    }
  }

  Future<void> _refreshVendors() async {
    setState(() => _vendorsFuture = _loadVendors());
    _animationController
      ..reset()
      ..forward();
    await _vendorsFuture;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vendors refreshed from backend'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF6F6F6),
      drawer: AdminSidebarDrawer(
        currentRoute: SuperAdminVendorsScreen.routeName,
        onLogout: () async {
          final logoutRoute = context.read<AppState>().logoutRouteName;
          await context.read<AppState>().logout();
          if (!context.mounted) return;
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamedAndRemoveUntil(logoutRoute, (route) => false);
        },
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            _VendorsHero(onRefresh: _refreshVendors, onAdd: _createVendor),
            const SizedBox(height: 16),
            FutureBuilder<List<VendorModel>>(
              future: _vendorsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _VendorsError(message: snapshot.error.toString());
                }
                if (!snapshot.hasData) {
                  return const _LoadingSkeleton();
                }

                final vendors = snapshot.data!;
                final filteredVendors = _filteredVendors(vendors);

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _VendorsSummary(vendors: vendors),
                      const SizedBox(height: 20),
                      _SearchAndFilterBar(
                        controller: _searchController,
                        onSearchChanged: (value) =>
                            setState(() => _query = value),
                        onClear: _query.isEmpty
                            ? null
                            : () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                        selectedFilter: _selectedFilter,
                        filterOptions: _filterOptions,
                        onFilterChanged: (filter) =>
                            setState(() => _selectedFilter = filter),
                      ),
                      const SizedBox(height: 16),
                      PaginatedCollection<VendorModel>(
                        items: filteredVendors,
                        builder: (visibleVendors) => _VendorsTable(
                          vendors: visibleVendors,
                          totalVendors: vendors.length,
                          updatingVendorIds: _updatingVendors,
                          onView: _viewVendor,
                          onEdit: _editVendor,
                          onApprove: _approveVendor,
                          onSuspend: _suspendVendor,
                          onReject: _rejectVendor,
                          onToggleStatus: _toggleStatus,
                          onDelete: _deleteVendor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorsHero extends StatelessWidget {
  const _VendorsHero({required this.onRefresh, required this.onAdd});

  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFDF8F4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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
              child: Builder(
                builder: (menuContext) => IconButton.filledTonal(
                  onPressed: () => Scaffold.of(menuContext).openDrawer(),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF0EB),
                    foregroundColor: const Color(0xFFE8541A),
                  ),
                  icon: const Icon(Icons.menu),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    onPressed: onAdd,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFE8541A),
                      foregroundColor: Colors.white,
                    ),
                    tooltip: 'Add vendor',
                    icon: const Icon(Icons.add_business),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: onRefresh,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF0EB),
                      foregroundColor: const Color(0xFFE8541A),
                    ),
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
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
                    'Vendor Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create and manage vendor accounts with their business details from one place.',
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

class _VendorsSummary extends StatelessWidget {
  const _VendorsSummary({required this.vendors});

  final List<VendorModel> vendors;

  @override
  Widget build(BuildContext context) {
    final active = vendors
        .where((vendor) => vendor.status.toLowerCase() == 'active')
        .length;
    final inactive = vendors
        .where((vendor) => vendor.status.toLowerCase() == 'inactive')
        .length;
    final pending = vendors
        .where((vendor) => vendor.approvalStatus.toLowerCase() == 'pending')
        .length;
    final approved = vendors
        .where((vendor) => vendor.approvalStatus.toLowerCase() == 'approved')
        .length;
    final products = vendors.fold<int>(
      0,
      (sum, vendor) => sum + vendor.productCount,
    );
    final orders = vendors.fold<int>(
      0,
      (sum, vendor) => sum + vendor.orderCount,
    );

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8541A), Color(0xFFFF8A5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8541A).withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vendor Directory',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Businesses onboarded onto the platform.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryPill(
                  label: 'Total',
                  value: vendors.length,
                  icon: Icons.storefront_outlined,
                ),
                _SummaryPill(
                  label: 'Active',
                  value: active,
                  icon: Icons.check_circle_outline,
                ),
                _SummaryPill(
                  label: 'Pending',
                  value: pending,
                  icon: Icons.hourglass_bottom,
                ),
                _SummaryPill(
                  label: 'Approved',
                  value: approved,
                  icon: Icons.verified_outlined,
                ),
                _SummaryPill(
                  label: 'Inactive',
                  value: inactive,
                  icon: Icons.pause_circle_outline,
                ),
                _SummaryPill(
                  label: 'Products',
                  value: products,
                  icon: Icons.inventory_2_outlined,
                ),
                _SummaryPill(
                  label: 'Orders',
                  value: orders,
                  icon: Icons.receipt_long_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.controller,
    required this.onSearchChanged,
    required this.onClear,
    required this.selectedFilter,
    required this.filterOptions,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClear;
  final String selectedFilter;
  final List<String> filterOptions;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1D4C8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8541A).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search vendors by name, ID, owner, or city...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFFE8541A),
                  size: 22,
                ),
                suffixIcon: onClear == null
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, color: Color(0xFFE8541A)),
                        onPressed: onClear,
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          Container(height: 40, width: 1, color: const Color(0xFFF1D4C8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: selectedFilter,
              underline: const SizedBox(),
              icon: const Icon(
                Icons.filter_list,
                color: Color(0xFFE8541A),
                size: 24,
              ),
              style: const TextStyle(
                color: Color(0xFFE8541A),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              borderRadius: BorderRadius.circular(12),
              items: filterOptions.map((filter) {
                return DropdownMenuItem(value: filter, child: Text(filter));
              }).toList(),
              onChanged: (value) {
                if (value != null) onFilterChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorsTable extends StatelessWidget {
  const _VendorsTable({
    required this.vendors,
    required this.totalVendors,
    required this.updatingVendorIds,
    required this.onView,
    required this.onEdit,
    required this.onApprove,
    required this.onSuspend,
    required this.onReject,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final List<VendorModel> vendors;
  final int totalVendors;
  final Set<String> updatingVendorIds;
  final Future<void> Function(VendorModel vendor) onView;
  final Future<void> Function(VendorModel vendor) onEdit;
  final Future<void> Function(VendorModel vendor) onApprove;
  final Future<void> Function(VendorModel vendor) onSuspend;
  final Future<void> Function(VendorModel vendor) onReject;
  final Future<void> Function(VendorModel vendor) onToggleStatus;
  final Future<void> Function(VendorModel vendor) onDelete;

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return const _EmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1D4C8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8541A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Text(
                  'All Vendors',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8541A), Color(0xFFFF8A5C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${vendors.length} of $totalVendors',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFFFF7F2)),
              dataRowMinHeight: 76,
              dataRowMaxHeight: 88,
              horizontalMargin: 24,
              columnSpacing: 32,
              headingTextStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE8541A),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
              columns: const [
                DataColumn(label: Text('VENDOR')),
                DataColumn(label: Text('CONTACT')),
                DataColumn(label: Text('LOCATION')),
                DataColumn(label: Text('GSTIN')),
                DataColumn(label: Text('ACTIVITY')),
                DataColumn(label: Text('APPROVAL')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('CREATED')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: vendors.map((vendor) {
                final updating = updatingVendorIds.contains(vendor.id);
                return DataRow(
                  cells: [
                    DataCell(_VendorIdentity(vendor: vendor)),
                    DataCell(_ContactDetails(vendor: vendor)),
                    DataCell(_LocationDetails(vendor: vendor)),
                    DataCell(
                      Text(
                        vendor.gstin.isEmpty ? '-' : vendor.gstin.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    DataCell(_ActivityBadge(vendor: vendor)),
                    DataCell(_ApprovalBadge(status: vendor.approvalStatus)),
                    DataCell(_StatusBadge(status: vendor.status)),
                    DataCell(Text(_formatDate(vendor.createdAt))),
                    DataCell(
                      updating
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFE8541A),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionButton(
                                  tooltip: 'View vendor details',
                                  icon: Icons.visibility_outlined,
                                  color: const Color(0xFFE8541A),
                                  onPressed: () => onView(vendor),
                                ),
                                _ActionButton(
                                  tooltip: 'Edit vendor',
                                  icon: Icons.edit_outlined,
                                  color: const Color(0xFF2563EB),
                                  onPressed: () => onEdit(vendor),
                                ),
                                if (vendor.approvalStatus.toLowerCase() !=
                                    'approved')
                                  _ActionButton(
                                    tooltip: 'Approve vendor',
                                    icon: Icons.verified_outlined,
                                    color: const Color(0xFF15803D),
                                    onPressed: () => onApprove(vendor),
                                  )
                                else
                                  _ActionButton(
                                    tooltip: 'Suspend vendor',
                                    icon: Icons.block_outlined,
                                    color: const Color(0xFFB45309),
                                    onPressed: () => onSuspend(vendor),
                                  ),
                                _ActionButton(
                                  tooltip:
                                      vendor.approvalStatus.toLowerCase() ==
                                          'rejected'
                                      ? 'Mark as pending'
                                      : 'Reject vendor',
                                  icon: Icons.cancel_outlined,
                                  color: const Color(0xFFBE123C),
                                  onPressed: () => onReject(vendor),
                                ),
                                _ActionButton(
                                  tooltip:
                                      vendor.status.toLowerCase() == 'active'
                                      ? 'Deactivate vendor'
                                      : 'Activate vendor',
                                  icon: vendor.status.toLowerCase() == 'active'
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline,
                                  color: vendor.status.toLowerCase() == 'active'
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFFE8541A),
                                  onPressed: () => onToggleStatus(vendor),
                                ),
                                _ActionButton(
                                  tooltip: 'Delete vendor',
                                  icon: Icons.delete_outline,
                                  color: const Color(0xFFBE123C),
                                  onPressed: () => onDelete(vendor),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          color: color,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        ),
      ),
    );
  }
}

class _VendorIdentity extends StatelessWidget {
  const _VendorIdentity({required this.vendor});

  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    final initial = vendor.name.trim().isEmpty
        ? '?'
        : vendor.name.trim().substring(0, 1).toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8541A), Color(0xFFFF8A5C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE8541A).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vendor.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8541A),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ID: ${_formatVendorDisplayId(vendor.vendorId, vendor.id)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFE8541A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails({required this.vendor});

  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.person_outline,
              size: 14,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              vendor.ownerName.isEmpty ? '-' : vendor.ownerName,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.phone, size: 14, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              vendor.phone.isEmpty ? '-' : vendor.phone,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.email, size: 14, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              vendor.email?.isNotEmpty == true ? vendor.email! : '-',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationDetails extends StatelessWidget {
  const _LocationDetails({required this.vendor});

  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    final city = vendor.city.isEmpty ? '-' : vendor.city;
    final pincode = vendor.pincode.isEmpty ? '' : ' ${vendor.pincode}';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 14,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              city,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          pincode.trim().isEmpty
              ? (vendor.address.isEmpty ? '-' : vendor.address)
              : pincode,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF64748B),
            fontSize: 12,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.vendor});

  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${vendor.productCount} products',
            style: const TextStyle(
              color: Color(0xFFE8541A),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${vendor.orderCount} orders',
            style: const TextStyle(
              color: Color(0xFFE8541A),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active';
    final color = isActive ? const Color(0xFFE8541A) : const Color(0xFFB45309);
    final bgColor = isActive
        ? const Color(0xFFFFF0EB)
        : const Color(0xFFFFF7E6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _titleCase(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'approved' => const Color(0xFF15803D),
      'rejected' => const Color(0xFFBE123C),
      'suspended' => const Color(0xFFB45309),
      _ => const Color(0xFFE8541A),
    };
    final bgColor = color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _titleCase(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1D4C8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 72,
            color: Color(0xFFE8541A),
          ),
          const SizedBox(height: 16),
          Text(
            'No vendors found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or add a new vendor',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _DeleteVendorDialog extends StatelessWidget {
  const _DeleteVendorDialog({required this.vendor});

  final VendorModel vendor;

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
              Icons.delete_outline,
              color: Color(0xFFBE123C),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Delete Vendor',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      content: Text(
        'Delete ${vendor.name}? This action cannot be undone. The vendor record will be permanently removed.',
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Color(0xFF475569),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFBE123C),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Delete',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _RejectVendorDialog extends StatefulWidget {
  const _RejectVendorDialog({required this.vendor});

  final VendorModel vendor;

  @override
  State<_RejectVendorDialog> createState() => _RejectVendorDialogState();
}

class _RejectVendorDialogState extends State<_RejectVendorDialog> {
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
            'Reject Vendor',
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
              'Add a short reason for rejecting ${widget.vendor.name}.',
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
                hintText: 'Example: GST document is unclear or missing...',
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFBE123C),
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

List<VendorBusinessHour> _defaultAdminVendorBusinessHours() => List.generate(
  7,
  (day) => VendorBusinessHour(
    day: day,
    isOpen: true,
    openTime: '08:00',
    closeTime: '22:00',
  ),
);

List<VendorBusinessHour> _normalizedAdminVendorBusinessHours(
  List<VendorBusinessHour> hours,
) {
  if (hours.length == 7) return hours;
  final byDay = {for (final hour in hours) hour.day: hour};
  return List.generate(
    7,
    (day) =>
        byDay[day] ??
        VendorBusinessHour(
          day: day,
          isOpen: true,
          openTime: '08:00',
          closeTime: '22:00',
        ),
  );
}

class _AdminBusinessHoursEditor extends StatelessWidget {
  const _AdminBusinessHoursEditor({
    required this.hours,
    required this.onChanged,
  });

  final List<VendorBusinessHour> hours;
  final ValueChanged<List<VendorBusinessHour>> onChanged;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  Future<void> _pickTime(BuildContext context, int index, bool opening) async {
    final current = opening ? hours[index].openTime : hours[index].closeTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? (opening ? 8 : 22),
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    onChanged(
      hours
          .map(
            (hour) => opening
                ? hour.copyWith(openTime: value)
                : hour.copyWith(closeTime: value),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(hours.length, (index) {
            final hour = hours[index];
            return FilterChip(
              selected: hour.isOpen,
              label: Text(_days[index]),
              onSelected: (value) {
                final updated = [...hours];
                updated[index] = hour.copyWith(isOpen: value);
                onChanged(updated);
              },
              selectedColor: const Color(0xFFFFF0EB),
              checkmarkColor: const Color(0xFFE8541A),
              side: const BorderSide(color: Color(0xFFF1D4C8)),
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickTime(context, 0, true),
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Open ${hours.first.openTime}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickTime(context, 0, false),
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Close ${hours.first.closeTime}'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VendorFormDialog extends StatefulWidget {
  const _VendorFormDialog({this.vendor});

  final VendorModel? vendor;

  @override
  State<_VendorFormDialog> createState() => _VendorFormDialogState();
}

class _VendorFormDialogState extends State<_VendorFormDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _vendorIdController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _businessTypeController;
  late final TextEditingController _gstController;
  late final TextEditingController _panController;
  late final TextEditingController _addressController;
  late final TextEditingController _pickupAddressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _bankHolderController;
  late final TextEditingController _bankNumberController;
  late final TextEditingController _ifscController;
  bool _saving = false;
  bool get _isEditing => widget.vendor != null;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  String? _storeLogo;
  String? _gstCertificate;
  String? _panCard;
  String? _cancelledCheque;
  String? _shopImageUrl;
  String? _storeLogoName;
  String? _gstCertificateName;
  String? _panCardName;
  String? _cancelledChequeName;
  String? _shopImageName;
  String? _uploadingField;
  List<VendorBusinessHour> _businessHours = _defaultAdminVendorBusinessHours();
  double? _pickupLatitude;
  double? _pickupLongitude;
  bool _capturingPickupLocation = false;

  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor;
    _nameController = TextEditingController(text: vendor?.name ?? '');
    _vendorIdController = TextEditingController(text: vendor?.vendorId ?? '');
    _ownerNameController = TextEditingController(text: vendor?.ownerName ?? '');
    _phoneController = TextEditingController(text: vendor?.phone ?? '');
    _emailController = TextEditingController(text: vendor?.email ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _businessTypeController = TextEditingController(
      text: vendor?.businessType ?? '',
    );
    _gstController = TextEditingController(text: vendor?.gstin ?? '');
    _panController = TextEditingController(text: vendor?.panNumber ?? '');
    _addressController = TextEditingController(text: vendor?.address ?? '');
    _pickupAddressController = TextEditingController(
      text: vendor?.pickupAddress ?? '',
    );
    _pickupLatitude = vendor?.pickupLatitude;
    _pickupLongitude = vendor?.pickupLongitude;
    _cityController = TextEditingController(text: vendor?.city ?? '');
    _stateController = TextEditingController(text: vendor?.state ?? '');
    _pincodeController = TextEditingController(text: vendor?.pincode ?? '');
    _bankHolderController = TextEditingController(
      text: vendor?.bankAccountHolderName ?? '',
    );
    _bankNumberController = TextEditingController(
      text: vendor?.bankAccountNumber ?? '',
    );
    _ifscController = TextEditingController(text: vendor?.ifscCode ?? '');
    _storeLogo = vendor?.logoUrl.isNotEmpty == true ? vendor!.logoUrl : null;
    _shopImageUrl = vendor?.shopImageUrl.isNotEmpty == true
        ? vendor!.shopImageUrl
        : null;
    _businessHours = _normalizedAdminVendorBusinessHours(
      vendor?.businessHours ?? const [],
    );
    _gstCertificate = vendor?.gstCertificateUrl.isNotEmpty == true
        ? vendor!.gstCertificateUrl
        : null;
    _panCard = vendor?.panCardUrl.isNotEmpty == true
        ? vendor!.panCardUrl
        : null;
    _cancelledCheque = vendor?.cancelledChequeUrl.isNotEmpty == true
        ? vendor!.cancelledChequeUrl
        : null;
    _storeLogoName = _storeLogo == null ? null : 'Uploaded file';
    _shopImageName = _shopImageUrl == null ? null : 'Uploaded banner';
    _gstCertificateName = _gstCertificate == null ? null : 'Uploaded file';
    _panCardName = _panCard == null ? null : 'Uploaded file';
    _cancelledChequeName = _cancelledCheque == null ? null : 'Uploaded file';

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vendorIdController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessTypeController.dispose();
    _gstController.dispose();
    _panController.dispose();
    _addressController.dispose();
    _pickupAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _bankHolderController.dispose();
    _bankNumberController.dispose();
    _ifscController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _capturePickupLocation() async {
    setState(() => _capturingPickupLocation = true);
    try {
      final location = await LocationService().currentLocation();
      if (!mounted) return;
      setState(() {
        _pickupLatitude = location.latitude;
        _pickupLongitude = location.longitude;
      });
      _showError('Pickup location saved');
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _capturingPickupLocation = false);
    }
  }

  Future<void> _pickAsset({
    required String field,
    required List<XTypeGroup> acceptedTypeGroups,
    required void Function(String value) onSelected,
    required void Function(String value) onNameSelected,
  }) async {
    try {
      setState(() => _uploadingField = field);
      final api = context.read<AppState>().apiService;
      final file = await openFile(acceptedTypeGroups: acceptedTypeGroups);
      if (file == null) return;
      final uploaded = kIsWeb
          ? await api.uploadImage(
              '/auth/vendor/upload-image',
              bytes: await file.readAsBytes(),
              fileName: file.name,
              fieldName: 'image',
            )
          : await api.uploadImage(
              '/auth/vendor/upload-image',
              filePath: file.path,
              fileName: file.name,
              fieldName: 'image',
            );
      final url = uploaded['url']?.toString();
      if (url == null || url.isEmpty) {
        throw StateError('Upload failed');
      }
      onSelected(url);
      onNameSelected(file.name);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showError(
        'Upload failed: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _uploadingField = null);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Vendor name is required');
      return;
    }
    if (!_isEditing) {
      final password = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();
      if (password.isEmpty || confirmPassword.isEmpty) {
        _showError('Password and confirm password are required');
        return;
      }
      if (password != confirmPassword) {
        _showError('Passwords do not match');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final state = context.read<AppState>();
      late final VendorModel savedVendor;
      if (_isEditing) {
        savedVendor = await state.updateVendor(
          vendorId: widget.vendor!.id,
          name: name,
          ownerName: _ownerNameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          businessType: _businessTypeController.text.trim(),
          gstin: _gstController.text.trim(),
          panNumber: _panController.text.trim(),
          address: _addressController.text.trim(),
          pickupAddress: _pickupAddressController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          pincode: _pincodeController.text.trim(),
          bankAccountHolderName: _bankHolderController.text.trim(),
          bankAccountNumber: _bankNumberController.text.trim(),
          ifscCode: _ifscController.text.trim(),
          logoUrl: _storeLogo ?? '',
          gstCertificateUrl: _gstCertificate ?? '',
          panCardUrl: _panCard ?? '',
          cancelledChequeUrl: _cancelledCheque ?? '',
          shopImageUrl: _shopImageUrl ?? '',
          businessHours: _businessHours,
          pickupLatitude: _pickupLatitude,
          pickupLongitude: _pickupLongitude,
        );
      } else {
        savedVendor = await state.createVendor(
          name: name,
          vendorId: _vendorIdController.text.trim(),
          ownerName: _ownerNameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          confirmPassword: _confirmPasswordController.text.trim(),
          businessType: _businessTypeController.text.trim(),
          gstin: _gstController.text.trim(),
          panNumber: _panController.text.trim(),
          address: _addressController.text.trim(),
          pickupAddress: _pickupAddressController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          pincode: _pincodeController.text.trim(),
          bankAccountHolderName: _bankHolderController.text.trim(),
          bankAccountNumber: _bankNumberController.text.trim(),
          ifscCode: _ifscController.text.trim(),
          logoUrl: _storeLogo ?? '',
          gstCertificateUrl: _gstCertificate ?? '',
          panCardUrl: _panCard ?? '',
          cancelledChequeUrl: _cancelledCheque ?? '',
          shopImageUrl: _shopImageUrl ?? '',
          businessHours: _businessHours,
          pickupLatitude: _pickupLatitude,
          pickupLongitude: _pickupLongitude,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(savedVendor);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } on StateError catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to save vendor: ${error.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFBE123C),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isMobile = screenSize.width < 600;
    final dialogWidth = isMobile ? screenSize.width - 20 : 760.0;
    final dialogHeight = isMobile
        ? screenSize.height - 24
        : screenSize.height * 0.86;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 24,
          vertical: isMobile ? 12 : 24,
        ),
        contentPadding: EdgeInsets.fromLTRB(
          isMobile ? 14 : 24,
          8,
          isMobile ? 14 : 24,
          0,
        ),
        actionsPadding: EdgeInsets.fromLTRB(
          isMobile ? 14 : 24,
          10,
          isMobile ? 14 : 24,
          isMobile ? 14 : 18,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 22 : 28),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8541A), Color(0xFFFF8A5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _isEditing ? Icons.edit_outlined : Icons.add_business,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _isEditing ? 'Edit Vendor' : 'Add Vendor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
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
              children: [
                _FormSection(
                  title: 'Owner Details',
                  subtitle: 'Same details as vendor registration',
                  children: [
                    _buildTextField(
                      controller: _ownerNameController,
                      label: 'Owner Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Store / Business Name *',
                      icon: Icons.storefront_rounded,
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveFieldRow(
                      children: [
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Mobile Number',
                          icon: Icons.phone_iphone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_isEditing) ...[
                  _FormSection(
                    title: 'Login Credentials',
                    subtitle: 'Used by the vendor to sign in',
                    children: [
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFFE8541A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        icon: Icons.lock_reset_rounded,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFFE8541A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                _FormSection(
                  title: 'Business Details',
                  subtitle: 'Registration and address information',
                  children: [
                    _buildTextField(
                      controller: _businessTypeController,
                      label: 'Business Type',
                      icon: Icons.category_rounded,
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveFieldRow(
                      children: [
                        _buildTextField(
                          controller: _gstController,
                          label: 'GST Number',
                          icon: Icons.receipt_long_rounded,
                        ),
                        _buildTextField(
                          controller: _panController,
                          label: 'PAN Number',
                          icon: Icons.badge_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Store Address',
                      icon: Icons.location_on_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _pickupAddressController,
                      label: 'Pickup Address',
                      icon: Icons.local_shipping_rounded,
                    ),
                    const SizedBox(height: 14),
                    _LocationCard(
                      title: 'Pickup exact location',
                      subtitle:
                          'Use the vendor store pin for accurate pickup navigation.',
                      latitude: _pickupLatitude,
                      longitude: _pickupLongitude,
                      capturing: _capturingPickupLocation,
                      onCapture: _capturePickupLocation,
                      onClear:
                          _pickupLatitude != null || _pickupLongitude != null
                          ? () {
                              setState(() {
                                _pickupLatitude = null;
                                _pickupLongitude = null;
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveFieldRow(
                      children: [
                        _buildTextField(
                          controller: _cityController,
                          label: 'City',
                          icon: Icons.location_city_rounded,
                        ),
                        _buildTextField(
                          controller: _stateController,
                          label: 'State',
                          icon: Icons.map_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _pincodeController,
                      label: 'Pincode',
                      icon: Icons.local_post_office_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FormSection(
                  title: 'Store Availability',
                  subtitle: 'Open days and shop timing visible to customers',
                  children: [
                    _AdminBusinessHoursEditor(
                      hours: _businessHours,
                      onChanged: (hours) =>
                          setState(() => _businessHours = hours),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FormSection(
                  title: 'Bank Details',
                  subtitle: 'For vendor payouts',
                  children: [
                    _buildTextField(
                      controller: _bankHolderController,
                      label: 'Bank Account Holder Name',
                      icon: Icons.person_pin_circle_rounded,
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveFieldRow(
                      children: [
                        _buildTextField(
                          controller: _bankNumberController,
                          label: 'Bank Account Number',
                          icon: Icons.account_balance_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(
                          controller: _ifscController,
                          label: 'IFSC Code',
                          icon: Icons.code_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FormSection(
                  title: 'Document Uploads',
                  subtitle: 'Store logo, shop banner, GST, PAN, and cheque',
                  children: [
                    _UploadTile(
                      title: 'Store Logo',
                      value: _storeLogoName,
                      uploading: _uploadingField == 'logo',
                      onTap: () => _pickAsset(
                        field: 'logo',
                        acceptedTypeGroups: const [
                          XTypeGroup(
                            label: 'Images',
                            extensions: ['jpg', 'jpeg', 'png', 'webp'],
                          ),
                        ],
                        onSelected: (value) => _storeLogo = value,
                        onNameSelected: (value) => _storeLogoName = value,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _UploadTile(
                      title: 'Shop Banner Photo',
                      value: _shopImageName,
                      uploading: _uploadingField == 'shop_banner',
                      onTap: () => _pickAsset(
                        field: 'shop_banner',
                        acceptedTypeGroups: const [
                          XTypeGroup(
                            label: 'Images',
                            extensions: ['jpg', 'jpeg', 'png', 'webp'],
                          ),
                        ],
                        onSelected: (value) => _shopImageUrl = value,
                        onNameSelected: (value) => _shopImageName = value,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _UploadTile(
                      title: 'GST Certificate',
                      value: _gstCertificateName,
                      uploading: _uploadingField == 'gst',
                      onTap: () => _pickAsset(
                        field: 'gst',
                        acceptedTypeGroups: const [
                          XTypeGroup(
                            label: 'Documents',
                            extensions: ['jpg', 'jpeg', 'png', 'pdf'],
                          ),
                        ],
                        onSelected: (value) => _gstCertificate = value,
                        onNameSelected: (value) => _gstCertificateName = value,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _UploadTile(
                      title: 'PAN Card',
                      value: _panCardName,
                      uploading: _uploadingField == 'pan',
                      onTap: () => _pickAsset(
                        field: 'pan',
                        acceptedTypeGroups: const [
                          XTypeGroup(
                            label: 'Documents',
                            extensions: ['jpg', 'jpeg', 'png', 'pdf'],
                          ),
                        ],
                        onSelected: (value) => _panCard = value,
                        onNameSelected: (value) => _panCardName = value,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _UploadTile(
                      title: 'Cancelled Cheque / Bank Proof',
                      value: _cancelledChequeName,
                      uploading: _uploadingField == 'cheque',
                      onTap: () => _pickAsset(
                        field: 'cheque',
                        acceptedTypeGroups: const [
                          XTypeGroup(
                            label: 'Documents',
                            extensions: ['jpg', 'jpeg', 'png', 'pdf'],
                          ),
                        ],
                        onSelected: (value) => _cancelledCheque = value,
                        onNameSelected: (value) => _cancelledChequeName = value,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          _VendorFormActions(
            saving: _saving,
            isEditing: _isEditing,
            onCancel: () => Navigator.of(context, rootNavigator: true).pop(),
            onSave: _save,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
    bool obscureText = false,
    String? helper,
    Widget? suffixIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1D4C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFFE8541A)),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                helper,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  const _ResponsiveFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _VendorFormActions extends StatelessWidget {
  const _VendorFormActions({
    required this.saving,
    required this.isEditing,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final bool isEditing;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final cancelButton = TextButton(
      onPressed: saving ? null : onCancel,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Cancel',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
    final saveButton = FilledButton(
      onPressed: saving ? null : onSave,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE8541A),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: saving
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isEditing ? Icons.save_outlined : Icons.add_business,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isEditing ? 'Save Changes' : 'Create Vendor',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
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
      children: [cancelButton, const SizedBox(width: 10), saveButton],
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1D4C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.capturing,
    required this.onCapture,
    required this.onClear,
  });

  final String title;
  final String subtitle;
  final double? latitude;
  final double? longitude;
  final bool capturing;
  final VoidCallback onCapture;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasLocation = latitude != null && longitude != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1D4C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9DD),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFFE8541A),
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
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasLocation
                ? 'Saved pin: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
                : 'No exact pin saved yet.',
            style: TextStyle(
              color: hasLocation
                  ? const Color(0xFF166534)
                  : const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: capturing ? null : onCapture,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8541A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: capturing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.gps_fixed_rounded, size: 18),
                  label: Text(
                    capturing ? 'Capturing...' : 'Use current location',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE8541A),
                    side: const BorderSide(color: Color(0xFFF3C3AF)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.title,
    required this.value,
    required this.uploading,
    required this.onTap,
  });

  final String title;
  final String? value;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final uploaded = !uploading && value != null && value!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: uploaded ? const Color(0xFFFFF0EB) : const Color(0xFFFDF8F4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: uploaded
                  ? const Color(0xFFF3C3AF)
                  : const Color(0xFFF1D4C8),
              width: 1.3,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: uploaded
                      ? const Color(0xFFFCE7DF)
                      : const Color(0xFFFFF0EB),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  uploaded
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  color: uploaded
                      ? const Color(0xFFE8541A)
                      : const Color(0xFFC63A0E),
                  size: 19,
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
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      uploading
                          ? 'Uploading...'
                          : (value == null || value!.isEmpty
                                ? 'Tap to upload'
                                : value!),
                      style: TextStyle(
                        color: uploaded
                            ? const Color(0xFFE8541A)
                            : const Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (uploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Color(0xFFE8541A)),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB4B4C4),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE8541A)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(5, (index) => _SkeletonRow()),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _VendorsError extends StatelessWidget {
  const _VendorsError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Color(0xFFBE123C)),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Vendors',
            style: TextStyle(
              color: Color(0xFFBE123C),
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF9F1239),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _titleCase(String value) {
  if (value.isEmpty) return '-';
  return value.substring(0, 1).toUpperCase() + value.substring(1).toLowerCase();
}

class _VendorDetailsDialog extends StatelessWidget {
  const _VendorDetailsDialog({required this.vendor});

  final VendorModel vendor;

  @override
  Widget build(BuildContext context) {
    final attachments = <_VendorAttachment>[
      _VendorAttachment(
        label: 'Store Logo',
        url: vendor.logoUrl,
        kind: _AttachmentKind.image,
      ),
      _VendorAttachment(
        label: 'GST Certificate',
        url: vendor.gstCertificateUrl,
        kind: _AttachmentKind.document,
      ),
      _VendorAttachment(
        label: 'PAN Card',
        url: vendor.panCardUrl,
        kind: _AttachmentKind.document,
      ),
      _VendorAttachment(
        label: 'Cancelled Cheque',
        url: vendor.cancelledChequeUrl,
        kind: _AttachmentKind.document,
      ),
    ];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            color: const Color(0xFFF6F6F6),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE8541A), Color(0xFFFF8A5C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            vendor.name.trim().isEmpty
                                ? '?'
                                : vendor.name.trim()[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vendor.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vendor ID: ${_formatVendorDisplayId(vendor.vendorId, vendor.id)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Export vendor details',
                        onPressed: () => _exportVendorDetails(context, vendor),
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _InfoChip(
                              icon: Icons.verified_user_outlined,
                              label: _titleCase(vendor.approvalStatus),
                              color: const Color(0xFFE8541A),
                            ),
                            _InfoChip(
                              icon: vendor.status.toLowerCase() == 'active'
                                  ? Icons.check_circle_outline
                                  : Icons.pause_circle_outline,
                              label: _titleCase(vendor.status),
                              color: vendor.status.toLowerCase() == 'active'
                                  ? const Color(0xFFE8541A)
                                  : const Color(0xFFB45309),
                            ),
                            _InfoChip(
                              icon: Icons.inventory_2_outlined,
                              label: '${vendor.productCount} products',
                              color: const Color(0xFF2563EB),
                            ),
                            _InfoChip(
                              icon: Icons.receipt_long_outlined,
                              label: '${vendor.orderCount} orders',
                              color: const Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _SectionTitle(title: 'Business Details'),
                        const SizedBox(height: 12),
                        _DetailGrid(
                          items: [
                            _DetailItem('Owner Name', vendor.ownerName),
                            _DetailItem('Email', vendor.email ?? ''),
                            _DetailItem('Phone', vendor.phone),
                            _DetailItem('Business Type', vendor.businessType),
                            _DetailItem('GSTIN', vendor.gstin),
                            _DetailItem('PAN Number', vendor.panNumber),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SectionTitle(title: 'Addresses'),
                        const SizedBox(height: 12),
                        _DetailGrid(
                          items: [
                            _DetailItem('Address', vendor.address),
                            _DetailItem('Pickup Address', vendor.pickupAddress),
                            _DetailItem('City', vendor.city),
                            _DetailItem('State', vendor.state),
                            _DetailItem('Pincode', vendor.pincode),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SectionTitle(title: 'Banking'),
                        const SizedBox(height: 12),
                        _DetailGrid(
                          items: [
                            _DetailItem(
                              'Account Holder',
                              vendor.bankAccountHolderName,
                            ),
                            _DetailItem(
                              'Account Number',
                              vendor.bankAccountNumber,
                            ),
                            _DetailItem('IFSC Code', vendor.ifscCode),
                            _DetailItem(
                              'Commission %',
                              vendor.commissionPercent > 0
                                  ? vendor.commissionPercent.toStringAsFixed(2)
                                  : '0',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SectionTitle(title: 'Documents & Images'),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth >= 700
                                ? 2
                                : 1;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: attachments.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    // Leave enough vertical room for the
                                    // document title, preview and the
                                    // explicit Download document button.
                                    childAspectRatio: crossAxisCount == 1
                                        ? 1.25
                                        : 1.15,
                                  ),
                              itemBuilder: (context, index) {
                                return _AttachmentCard(
                                  attachment: attachments[index],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _SectionTitle(title: 'Timeline'),
                        const SizedBox(height: 12),
                        _DetailGrid(
                          items: [
                            _DetailItem(
                              'Created At',
                              _formatDate(vendor.createdAt),
                            ),
                            _DetailItem(
                              'Updated At',
                              _formatDate(vendor.updatedAt),
                            ),
                            _DetailItem('Approved By', vendor.approvedBy ?? ''),
                            _DetailItem(
                              'Approved At',
                              _formatDate(vendor.approvedAt),
                            ),
                            _DetailItem(
                              'Rejection Reason',
                              vendor.rejectionReason,
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w900,
        color: const Color(0xFFE8541A),
        letterSpacing: -0.2,
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});

  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 700;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: twoColumns
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth,
                  child: _DetailCard(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.item});

  final _DetailItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1D4C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.value.isEmpty ? '-' : item.value,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  const _DetailItem(this.label, this.value);

  final String label;
  final String value;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.attachment});

  final _VendorAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final hasUrl = attachment.url.trim().isNotEmpty;
    return InkWell(
      onTap: hasUrl ? () => _openExternalUrl(context, attachment.url) : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1D4C8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0EB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      attachment.kind == _AttachmentKind.image
                          ? Icons.image_outlined
                          : Icons.description_outlined,
                      color: const Color(0xFFE8541A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasUrl ? 'Tap to open' : 'Not uploaded',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasUrl)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _openExternalUrl(context, attachment.url),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE8541A),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Download document',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    width: double.infinity,
                    child: hasUrl
                        ? attachment.kind == _AttachmentKind.image
                              ? Image.network(
                                  attachment.url,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const _AttachmentFallback();
                                  },
                                )
                              : const _AttachmentFallback(
                                  icon: Icons.picture_as_pdf_outlined,
                                  title: 'Document preview',
                                  subtitle: 'Open file to view document',
                                )
                        : const _AttachmentFallback(
                            title: 'No file uploaded',
                            subtitle: 'Vendor has not submitted this file',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentFallback extends StatelessWidget {
  const _AttachmentFallback({
    this.icon = Icons.insert_drive_file_outlined,
    this.title = 'Preview unavailable',
    this.subtitle = 'Open file to inspect',
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: const Color(0xFFE8541A)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AttachmentKind { image, document }

class _VendorAttachment {
  const _VendorAttachment({
    required this.label,
    required this.url,
    required this.kind,
  });

  final String label;
  final String url;
  final _AttachmentKind kind;
}

Future<void> _openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invalid document link')));
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open document')));
  }
}

Future<void> _exportVendorDetails(
  BuildContext context,
  VendorModel vendor,
) async {
  final report =
      '''DoorMart Vendor Details

Vendor ID: ${_formatVendorDisplayId(vendor.vendorId, vendor.id)}
Store name: ${vendor.name}
Owner name: ${vendor.ownerName}
Email: ${vendor.email ?? ''}
Phone: ${vendor.phone}
Business type: ${vendor.businessType}
GSTIN: ${vendor.gstin}
PAN: ${vendor.panNumber}

Address: ${vendor.address}
Pickup address: ${vendor.pickupAddress}
City: ${vendor.city}
State: ${vendor.state}
Pincode: ${vendor.pincode}

Account holder: ${vendor.bankAccountHolderName}
Account number: ${vendor.bankAccountNumber}
IFSC: ${vendor.ifscCode}
Commission: ${vendor.commissionPercent.toStringAsFixed(2)}%

GST certificate: ${vendor.gstCertificateUrl}
PAN card: ${vendor.panCardUrl}
Cancelled cheque: ${vendor.cancelledChequeUrl}
''';

  final uri = Uri.dataFromString(
    report,
    mimeType: 'text/plain',
    encoding: utf8,
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to export vendor details')),
    );
  }
}

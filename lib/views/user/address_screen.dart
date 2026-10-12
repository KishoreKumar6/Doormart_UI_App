import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/address_model.dart';
import '../../providers/app_state.dart';
import 'add_edit_address_screen.dart';

const _accent = Color(0xFFFF6A13);
const _bg = Color(0xFFF7F8FC);
const _card = Colors.white;
const _border = Color(0xFFE8EAF2);
const _textDark = Color(0xFF1B2330);
const _textMid = Color(0xFF667085);

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});
  static const routeName = '/address';

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  late Future<List<AddressModel>> _future;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().loadAddresses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = context.read<AppState>().loadAddresses();
    });
    await _future;
  }

  List<AddressModel> _filter(List<AddressModel> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((item) {
      return item.label.toLowerCase().contains(q) ||
          item.line1.toLowerCase().contains(q) ||
          item.city.toLowerCase().contains(q) ||
          item.pincode.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: const SizedBox(height: kBottomNavigationBarHeight),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _card,
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
                        color: _textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Saved Addresses',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEditAddressScreen(),
                        ),
                      );
                      if (result == true) await _refresh();
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _card,
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
                        Icons.add_rounded,
                        size: 24,
                        color: _textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: FutureBuilder<List<AddressModel>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: CircularProgressIndicator(color: _accent),
                          ),
                        );
                      }
                      final addresses = _filter(
                        snapshot.data ?? const <AddressModel>[],
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SearchRow(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                          const SizedBox(height: 16),
                          if (addresses.isEmpty)
                            _EmptyAddressState(
                              onAdd: () async {
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AddEditAddressScreen(),
                                  ),
                                );
                                if (result == true) await _refresh();
                              },
                            )
                          else
                            ...addresses.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AddressTile(
                                  address: item,
                                  onEdit: () async {
                                    final result = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AddEditAddressScreen(address: item),
                                      ),
                                    );
                                    if (result == true) await _refresh();
                                  },
                                  onDelete: () async {
                                    await context
                                        .read<AppState>()
                                        .deleteAddress(item.id);
                                    await _refresh();
                                  },
                                  onSetDefault: () async {
                                    await context
                                        .read<AppState>()
                                        .setDefaultAddress(item.id);
                                    await _refresh();
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          _AddAddressCard(
                            onTap: () async {
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddEditAddressScreen(),
                                ),
                              );
                              if (result == true) await _refresh();
                            },
                          ),
                        ],
                      );
                    },
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

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Search your addresses...',
              prefixIcon: const Icon(Icons.search_rounded, color: _textMid),
              filled: true,
              fillColor: _card,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _accent, width: 1.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final AddressModel address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    final icon = switch (address.label.toLowerCase()) {
      'home' => Icons.home_rounded,
      'work' => Icons.apartment_rounded,
      'gym' => Icons.fitness_center_rounded,
      _ => Icons.location_on_rounded,
    };
    final accent = switch (address.label.toLowerCase()) {
      'home' => const Color(0xFFFF7A1A),
      'work' => const Color(0xFF4F7DF3),
      'gym' => const Color(0xFF667085),
      _ => const Color(0xFF7A7F8C),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      address.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  address.line1,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: _textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address.shortAddress,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: _textMid,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(
                        foregroundColor: _textDark,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
              if (value == 'default') onSetDefault();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
              const PopupMenuItem(value: 'default', child: Text('Set default')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddAddressCard extends StatelessWidget {
  const _AddAddressCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _accent.withValues(alpha: 0.25),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: const [
            CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFFFFF1E8),
              child: Icon(Icons.add_rounded, color: _accent),
            ),
            SizedBox(height: 10),
            Text(
              'ADD NEW ADDRESS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: _textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAddressState extends StatelessWidget {
  const _EmptyAddressState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.location_off_rounded, size: 42, color: _textMid),
          const SizedBox(height: 12),
          const Text(
            'No saved addresses yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _textDark,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add one to speed up checkout and order delivery.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textMid),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: onAdd,
            child: const Text('Add Address'),
          ),
        ],
      ),
    );
  }
}

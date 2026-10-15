import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/product_model.dart';

/// Whether the store/vendor that sells [product] is currently closed.
///
/// Products whose `vendorIsOpen` is `null` (unknown, e.g. the endpoint did not
/// attach vendor metadata) are treated as open so an available product is
/// never incorrectly blocked.
bool isStoreClosedForProduct(dynamic product) {
  if (product is ProductModel) return product.vendorIsOpen == false;
  try {
    return product.vendorIsOpen == false;
  } catch (_) {
    return false;
  }
}

/// Label shown on a closed product, e.g. `Opens at 9:00 AM` or `Store closed`.
String closedStoreLabelForProduct(dynamic product) {
  String? openTime;
  if (product is ProductModel) {
    openTime = product.vendorTodayOpenTime;
  } else {
    try {
      openTime = product.vendorTodayOpenTime as String?;
    } catch (_) {
      openTime = null;
    }
  }
  final formatted = _formatClockTime(openTime);
  return formatted.isEmpty ? 'Store closed' : 'Opens at $formatted';
}

String _formatClockTime(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final parts = value.trim().split(':');
  if (parts.length < 2) return value.trim();
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value.trim();
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
}

/// A drop-in [Stack] child that slightly blurs everything painted behind it,
/// dims it and shows a "Closed" pill.
///
/// Add it as the **last** child of the product image [Stack] so it sits above
/// the photo. It paints nothing when the store is open.
class ClosedStoreOverlay extends StatelessWidget {
  const ClosedStoreOverlay({
    super.key,
    this.label = 'Store closed',
    this.blurSigma = 2,
    this.dimOpacity = 0.30,
    this.icon = Icons.lock_outline_rounded,
  });

  final String label;
  final double blurSigma;
  final double dimOpacity;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            color: Colors.black.withValues(alpha: dimOpacity),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10),
            child: _ClosedPill(label: label, icon: icon),
          ),
        ),
      ),
    );
  }
}

class _ClosedPill extends StatelessWidget {
  const _ClosedPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE8541A)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

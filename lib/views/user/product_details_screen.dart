import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../widgets/closed_store_overlay.dart';
import '../../widgets/product_price_breakdown.dart';
import '../../providers/app_state.dart';
import '../../widgets/toast_widget.dart';
import '../feature_placeholder_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, this.product});

  static const routeName = '/product-details';

  final ProductModel? product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _selectedIndex = 0;
  int _quantity = 1;

  ProductModel? _resolveProduct(BuildContext context) {
    if (widget.product != null) return widget.product;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ProductModel) return args;
    if (args is Map<String, dynamic>) {
      try {
        return ProductModel.fromJson(args);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  ProductUnitVariant _selectedVariant(ProductModel product) {
    final variants = product.unitVariants;
    if (variants.isEmpty) {
      return ProductUnitVariant(
        unit: product.unit,
        price: product.price,
        discountCost: product.mrp,
        stock: product.stock,
      );
    }
    final index = _selectedIndex < 0 || _selectedIndex >= variants.length
        ? 0
        : _selectedIndex;
    return variants[index];
  }

  void _selectVariant(ProductModel product, int index) {
    final variants = product.unitVariants;
    if (index < 0 || index >= variants.length) return;
    final stock = variants[index].stock;
    setState(() {
      _selectedIndex = index;
      if (stock > 0 && _quantity > stock) {
        _quantity = stock;
      }
      if (_quantity < 1) _quantity = 1;
    });
  }

  void _increment(ProductModel product) {
    final variant = _selectedVariant(product);
    final stock = variant.stock > 0 ? variant.stock : product.stock;
    if (stock > 0 && _quantity >= stock) return;
    setState(() => _quantity++);
  }

  void _decrement() {
    if (_quantity <= 1) return;
    setState(() => _quantity--);
  }

  Future<void> _addToCart(ProductModel product) async {
    final variant = _selectedVariant(product);
    final state = context.read<AppState>();
    final ok = await state.addToCart(
      product,
      quantity: _quantity,
      unit: variant.unit,
      price: variant.price,
      discountCost: variant.discountCost,
      stock: variant.stock,
    );
    if (!mounted) return;
    if (ok) {
      showToast(context, '${product.name} added to cart');
      return;
    }
    showToast(context, state.error ?? 'Unable to add to cart');
  }

  @override
  Widget build(BuildContext context) {
    final product = _resolveProduct(context);
    if (product == null) {
      return const Scaffold(
        body: FeaturePlaceholderScreen(
          title: 'Product Details',
          icon: Icons.inventory_2,
          description:
              'Image, price, MRP, discount, stock, quantity selector, and similar products.',
        ),
      );
    }

    final variant = _selectedVariant(product);
    final variants = product.unitVariants.isEmpty
        ? [
            ProductUnitVariant(
              unit: product.unit,
              price: product.price,
              discountCost: product.mrp,
              stock: product.stock,
            ),
          ]
        : product.unitVariants;
    final selectedPrice = variant.price > 0 ? variant.price : product.price;
    final selectedMrp = variant.discountCost > selectedPrice
        ? variant.discountCost
        : product.mrp > selectedPrice
        ? product.mrp
        : selectedPrice * 1.12;
    final selectedStock = variant.stock > 0 ? variant.stock : product.stock;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFEFEFEF),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                    if (product.vendorIsOpen == false)
                      ClosedStoreOverlay(
                        label: closedStoreLabelForProduct(product),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product.category,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ProductPriceBreakdown(
                  product: product,
                  basePrice: selectedPrice,
                  showBreakdown: false,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rs ${selectedMrp.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF9CA3AF),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              selectedStock > 0 ? '$selectedStock in stock' : 'Out of stock',
              style: TextStyle(
                color: selectedStock > 10
                    ? const Color(0xFF0F9D58)
                    : const Color(0xFFE8541A),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Available units',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: variants.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final selected = index == _selectedIndex;
                final label = _unitLabel(item.unit);
                return InkWell(
                  onTap: () => _selectVariant(product, index),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFFF0EB) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFE8541A)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? const Color(0xFFE8541A)
                                : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rs ${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.stock > 0
                              ? '${item.stock} stock'
                              : 'Out of stock',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            if (product.description.trim().isNotEmpty) ...[
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
            ],
            Row(
              children: [
                _StepButton(icon: Icons.remove_rounded, onTap: _decrement),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _StepButton(
                  icon: Icons.add_rounded,
                  onTap: () => _increment(product),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: selectedStock == 0
                      ? null
                      : () => _addToCart(product),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8541A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    selectedStock == 0 ? 'Out of stock' : 'Add to cart',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'More packs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            ...variants.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _unitLabel(item.unit),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Price Rs ${item.price.toStringAsFixed(0)} • Discount Rs ${item.discountCost.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${item.stock} stock',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
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

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, color: const Color(0xFFE8541A)),
      ),
    );
  }
}

String _unitLabel(String value) {
  final unit = value.trim();
  if (unit.isEmpty) return 'item';
  if (RegExp(r'^\d').hasMatch(unit)) return unit;
  return '1 $unit';
}

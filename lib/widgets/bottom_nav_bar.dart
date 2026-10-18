import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/app_state.dart';
import '../views/user/cart_screen.dart';
import '../views/user/my_orders_screen.dart';
import '../views/user/wishlist_screen.dart';
import '../views/user/profile_screen.dart';
import '../views/user/user_home_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFE8541A);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kTextMid = Color(0xFFAAAAAA);
const _kTextDark = Color(0xFF1A1A1A);

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  // ── Navigation helper ──────────────────────────────────────────────────────
  static void navigate(BuildContext context, int index) {
    final routeName = switch (index) {
      0 => UserHomeScreen.routeName,
      1 => MyOrdersScreen.routeName,
      2 => CartScreen.routeName,
      3 => WishlistScreen.routeName,
      4 => ProfileScreen.routeName,
      _ => UserHomeScreen.routeName,
    };
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => route.settings.name == UserHomeScreen.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        // Hide for delivery role
        if (state.user?.role == UserRoles.deliveryPerson) {
          return const SizedBox.shrink();
        }

        final cartCount = state.cartCount;
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.09),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 68,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // ── Nav bar background with notch ──────────────────────
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _NotchClipper(),
                      child: Container(color: Colors.white),
                    ),
                  ),

                  // ── Nav items row ──────────────────────────────────────
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Home
                        _NavItem(
                          icon: Icons.home_rounded,
                          activeIcon: Icons.home_rounded,
                          label: 'Home',
                          isSelected: index == 0,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTap(0);
                          },
                        ),

                        // Orders
                        _NavItem(
                          icon: Icons.receipt_long_outlined,
                          activeIcon: Icons.receipt_long_rounded,
                          label: 'Orders',
                          isSelected: index == 1,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTap(1);
                          },
                        ),

                        // Centre gap for FAB
                        const SizedBox(width: 72),

                        // Wishlist
                        _NavItem(
                          icon: Icons.favorite_border_rounded,
                          activeIcon: Icons.favorite_rounded,
                          label: 'Wishlist',
                          isSelected: index == 3,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTap(3);
                          },
                        ),

                        // Profile
                        _NavItem(
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: 'Profile',
                          isSelected: index == 4,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTap(4);
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Centre cart FAB ────────────────────────────────────
                  Positioned(
                    top: -22,
                    child: _CartFab(
                      cartCount: cartCount,
                      isSelected: index == 2,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onTap(2);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Cart FAB ─────────────────────────────────────────────────────────────────

class _CartFab extends StatefulWidget {
  const _CartFab({
    required this.cartCount,
    required this.isSelected,
    required this.onTap,
  });

  final int cartCount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_CartFab> createState() => _CartFabState();
}

class _CartFabState extends State<_CartFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _s = Tween<double>(
    begin: 1.0,
    end: 0.88,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // FAB circle
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF26522), Color(0xFFE8401A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kOrange.withValues(alpha: 0.42),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: widget.isSelected
                    ? Border.all(color: Colors.white, width: 2.5)
                    : null,
              ),
              child: const Icon(
                Icons.shopping_bag_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),

            // Cart count badge
            if (widget.cartCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedScale(
                  scale: widget.cartCount > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _kOrange, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        widget.cartCount > 99 ? '99+' : '${widget.cartCount}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: _kOrange,
                          height: 1,
                        ),
                      ),
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

// ─── Nav Item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 1.18,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !old.isSelected) {
      _c.forward(from: 0);
    } else if (!widget.isSelected && old.isSelected) {
      _c.reverse();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isSelected) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with animated pill background
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: widget.isSelected ? 44 : 28,
              height: 28,
              decoration: BoxDecoration(
                color: widget.isSelected ? _kOrangeLight : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      widget.isSelected ? widget.activeIcon : widget.icon,
                      key: ValueKey(widget.isSelected),
                      size: 22,
                      color: widget.isSelected ? _kOrange : _kTextMid,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 3),

            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: widget.isSelected
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: widget.isSelected ? _kOrange : _kTextMid,
              ),
              child: Text(widget.label),
            ),

            // Active dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(top: 2),
              width: widget.isSelected ? 4 : 0,
              height: widget.isSelected ? 4 : 0,
              decoration: const BoxDecoration(
                color: _kOrange,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Notch Clipper ────────────────────────────────────────────────────────────

class _NotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const notchRadius = 40.0;
    final cx = size.width / 2;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(cx - notchRadius - 16, 0);

    // Smooth left entry curve
    path.cubicTo(
      cx - notchRadius - 4,
      0,
      cx - notchRadius,
      6,
      cx - notchRadius + 2,
      notchRadius * 0.52,
    );

    // Bottom arc of notch
    path.arcToPoint(
      Offset(cx + notchRadius - 2, notchRadius * 0.52),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    // Smooth right exit curve
    path.cubicTo(
      cx + notchRadius,
      6,
      cx + notchRadius + 4,
      0,
      cx + notchRadius + 16,
      0,
    );

    path
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(_NotchClipper old) => false;
}

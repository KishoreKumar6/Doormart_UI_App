import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants.dart';
import '../../providers/app_state.dart';
import '../../features/delivery/screens/delivery_home_screen.dart';
import '../../features/delivery/screens/delivery_status_screen.dart';
import '../../views/user/user_home_screen.dart';
import '../../views/user/login_screen.dart';
import '../../views/admin/admin_dashboard_screen.dart';
import '../../views/super_admin/super_admin_dashboard_screen.dart';
import '../../views/vendor/vendor_dashboard_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  static const routeName = '/auth-gate';

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final VideoPlayerController _controller;
  late final Future<void> _videoInitFuture;
  bool _checking = true;
  Widget? _target;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.asset('assets/animations/doormart_splash.mp4')
          ..setLooping(true)
          ..setVolume(0.0);
    _videoInitFuture = _controller.initialize().then((_) => _controller.play());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _validate();
  }

  Future<void> _validate() async {
    if (!_checking) return;
    final state = context.read<AppState>();
    try {
      if (!state.initialized) {
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return !state.initialized;
        });
      }
      final role = state.user?.role;
      final token = state.token;
      if (token == null || role == null) {
        _target = const LoginScreen();
        return;
      }
      final approvalStatus = (state.user?.approvalStatus ?? 'approved')
          .toLowerCase();
      _target = switch (role) {
        UserRoles.deliveryPerson =>
          approvalStatus == 'approved'
              ? const DeliveryHomeScreen()
              : const DeliveryStatusScreen(),
        UserRoles.admin => const AdminDashboardScreen(),
        UserRoles.vendor => const VendorDashboardScreen(),
        UserRoles.superAdmin => const SuperAdminDashboardScreen(),
        UserRoles.user => const UserHomeScreen(),
        _ => null,
      };
    } catch (_) {
      _target = null;
    }
    if (!mounted) return;
    setState(() => _checking = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => _target ?? const LoginScreen()),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ColoredBox(
        color: Colors.white,
        child: FutureBuilder<void>(
          future: _videoInitFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                !_controller.value.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFE8541A)),
              );
            }

            if (_controller.value.hasError) {
              return Center(
                child: Image.asset(
                  'assets/images/banners/grocery_bag.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.contain,
                ),
              );
            }

            return Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: VideoPlayer(_controller),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

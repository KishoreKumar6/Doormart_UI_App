import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../providers/app_state.dart';
import 'login_screen.dart';
import '../../features/delivery/screens/delivery_home_screen.dart';
import '../../features/delivery/screens/delivery_status_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../super_admin/super_admin_dashboard_screen.dart';
import '../vendor/vendor_dashboard_screen.dart';
import 'user_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  static const routeName = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _videoInitFuture;
  bool _navigated = false;

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
    final state = context.watch<AppState>();
    if (_navigated || !state.initialized) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final approvalStatus = (state.user?.approvalStatus ?? 'approved')
          .toLowerCase();
      final target = switch (state.user?.role) {
        'delivery_person' =>
          approvalStatus == 'approved'
              ? const DeliveryHomeScreen()
              : const DeliveryStatusScreen(),
        'admin' => const AdminDashboardScreen(),
        'vendor' => const VendorDashboardScreen(),
        'super_admin' => const SuperAdminDashboardScreen(),
        'user' => const UserHomeScreen(),
        _ => const LoginScreen(),
      };
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => target));
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

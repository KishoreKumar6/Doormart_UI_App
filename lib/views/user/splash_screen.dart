import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../providers/app_state.dart';
import '../../services/app_update_service.dart';
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final VideoPlayerController _controller;
  late final Future<void> _videoInitFuture;
  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
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
    _motionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    if (_navigated || !state.initialized) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Single navigation path: _finishStartup performs the optional update
      // check and then routes to the role-specific dashboard exactly once.
      await _finishStartup(state);
    });
  }

  Future<void> _finishStartup(AppState state) async {
    final update = await AppUpdateService(
      apiService: state.apiService,
    ).checkForUpdate();
    if (!mounted) return;
    if (update != null) {
      final shouldLeaveSplash = await showDialog<bool>(
        context: context,
        barrierDismissible: !update.forceUpdate,
        builder: (dialogContext) => PopScope(
          canPop: !update.forceUpdate,
          child: _PremiumUpdateDialog(
            update: update,
            onLater: () => Navigator.pop(dialogContext, false),
            onUpdate: () async {
              await AppUpdateService(
                apiService: state.apiService,
              ).openStore(update);
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
          ),
        ),
      );
      if (update.forceUpdate || shouldLeaveSplash == true) return;
    }

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFBF8), Color(0xFFFFF1EA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _motionController,
                  builder: (context, child) {
                    final value = Curves.easeInOut.transform(
                      _motionController.value,
                    );
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 70 + (value * 16),
                          right: -45,
                          child: _GlowOrb(
                            size: 180,
                            color: const Color(0xFFFFB08D).withValues(
                              alpha: 0.24,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 70 - (value * 12),
                          left: -55,
                          child: _GlowOrb(
                            size: 210,
                            color: const Color(0xFFFFD6C5).withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, -5 + (value * 10)),
                          child: child,
                        ),
                      ],
                    );
                  },
                  child: FutureBuilder<void>(
                    future: _videoInitFuture,
                    builder: (context, snapshot) {
                      final ready =
                          snapshot.connectionState == ConnectionState.done &&
                          _controller.value.isInitialized &&
                          !_controller.value.hasError;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 158,
                            height: 158,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.90),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFD8C8),
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22E8541A),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: ready
                                  ? VideoPlayer(_controller)
                                  : Image.asset(
                                      'assets/images/doormartLogo.jpeg',
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'DoorMart',
                            style: TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'DELIVERY',
                            style: TextStyle(
                              color: Color(0xFFE8541A),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.2,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFFE8541A),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Preparing your delivery',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Powered by',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Image.asset(
                      'assets/images/least_action_company.png',
                      height: 58,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 40, spreadRadius: 12),
          ],
        ),
      ),
    );
  }
}

class _PremiumUpdateDialog extends StatelessWidget {
  const _PremiumUpdateDialog({
    required this.update,
    required this.onLater,
    required this.onUpdate,
  });

  final AppUpdateInfo update;
  final VoidCallback onLater;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE8541A), Color(0xFFC63F12)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Image.asset(
                          'assets/images/doormartLogo.jpeg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'A fresh DoorMart is ready',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      update.forceUpdate
                          ? 'Update now to continue shopping smoothly.'
                          : 'Enjoy a faster, smoother shopping experience.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _VersionPill(
                            label: 'Current',
                            version: update.currentVersion,
                            muted: true,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFFE8541A),
                          ),
                        ),
                        Expanded(
                          child: _VersionPill(
                            label: 'New version',
                            version: update.latestVersion,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: update.hasStoreUrl ? onUpdate : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE8541A),
                          disabledBackgroundColor: const Color(0xFFE5E7EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          update.hasStoreUrl
                              ? 'Update now'
                              : 'Store link unavailable',
                        ),
                      ),
                    ),
                    if (!update.forceUpdate) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onLater,
                        child: const Text(
                          'Maybe later',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill({
    required this.label,
    required this.version,
    this.muted = false,
  });
  final String label;
  final String version;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF3F4F6) : const Color(0xFFFFF0EB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: muted ? const Color(0xFFE5E7EB) : const Color(0xFFFFD5C6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A9490),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'v$version',
            style: TextStyle(
              color: muted ? const Color(0xFF374151) : const Color(0xFFE8541A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

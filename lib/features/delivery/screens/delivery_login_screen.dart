import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../services/api_service.dart';
import '../../../../models/user_model.dart';
import '../../../../providers/app_state.dart';
import '../../../../services/session_service.dart';
import '../../../../views/user/forgot_password_screen.dart';
import '../providers/delivery_provider.dart';
import 'delivery_home_screen.dart';
import 'delivery_register_screen.dart';
import 'delivery_status_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFE8541A);
const _kOrangeDeep = Color(0xFFD44010);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kBg = Color(0xFFF7F7F8);
const _kCard = Colors.white;
const _kTextDark = Color(0xFF1A1A2E);
const _kTextMid = Color(0xFF8A8A9A);
const _kBorder = Color(0xFFE5E5EA);
const _kRed = Color(0xFFEF4444);

class DeliveryLoginScreen extends StatefulWidget {
  const DeliveryLoginScreen({super.key});
  static const routeName = '/delivery/login';

  @override
  State<DeliveryLoginScreen> createState() => _DeliveryLoginScreenState();
}

class _DeliveryLoginScreenState extends State<DeliveryLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  // ── Entry animation ────────────────────────────────────────────────────────
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entryCtrl,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── Orange hero header ───────────────────────────────────
              _HeroHeader(),

              // ── Form card ─────────────────────────────────────────────
              FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcome card
                          const _WelcomeCard(),

                          const SizedBox(height: 24),

                          _FieldLabel('Email or phone number'),
                          const SizedBox(height: 8),
                          _Field(
                            controller: _identifier,
                            hint: 'partner@doormart.com',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter email or phone'
                                : null,
                          ),

                          const SizedBox(height: 16),

                          _FieldLabel('Password'),
                          const SizedBox(height: 8),
                          _Field(
                            controller: _password,
                            hint: 'Enter your password',
                            icon: Icons.lock_rounded,
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: _kTextMid,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter password'
                                : null,
                          ),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(ForgotPasswordScreen.routeName);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: _kOrange,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 4),
                            _ErrorBanner(message: _error!),
                          ],

                          const SizedBox(height: 22),

                          // Login button
                          _PrimaryBtn(
                            label: 'Login as Partner',
                            icon: Icons.login_rounded,
                            loading: _loading,
                            onTap: _login,
                          ),

                          const SizedBox(height: 24),

                          _SignupPrompt(
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(DeliveryRegisterScreen.routeName),
                          ),

                          const SizedBox(height: 18),

                          // Info strip
                          const _InfoStrip(),

                          const SizedBox(height: 24),

                          // Support row
                          Center(
                            child: GestureDetector(
                              onTap: () {},
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.support_agent_rounded,
                                    size: 16,
                                    color: _kTextMid,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Need help? Contact partner support',
                                    style: TextStyle(
                                      color: _kTextMid,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final provider = context.read<DeliveryProvider>();

    try {
      final value = _identifier.text.trim();
      await provider.login(
        email: value.contains('@') ? value : null,
        phone: value.contains('@') ? null : value,
        password: _password.text.trim(),
      );
      if (!mounted) return;

      final appState = context.read<AppState>();
      final authUser = provider.authUser;
      if (authUser != null && provider.authToken != null) {
        final deliveryPerson = provider.deliveryPerson;
        final mergedUser = Map<String, dynamic>.from(authUser);
        if ((mergedUser['avatarUrl']?.toString().trim() ?? '').isEmpty &&
            (deliveryPerson?.avatarUrl?.trim() ?? '').isNotEmpty) {
          mergedUser['avatarUrl'] = deliveryPerson!.avatarUrl;
        }
        appState.token = provider.authToken;
        appState.user = UserModel.fromJson(mergedUser);
        await appState.refreshProfile();
        await SessionService().saveSession(
          token: provider.authToken!,
          user: appState.user!,
        );
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final approvalStatus =
          (context.read<AppState>().user?.approvalStatus ?? 'pending')
              .toLowerCase();
      Navigator.of(context).pushReplacementNamed(
        approvalStatus == 'approved'
            ? DeliveryHomeScreen.routeName
            : DeliveryStatusScreen.routeName,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        setState(() => _error = 'Invalid email or password');
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Hero Header ──────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF26522), Color(0xFFD44010)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative circles
            Positioned(
              top: -30,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),

            Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Logo badge
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Doormart',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '🚴 Delivery Partner Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                // White curve transition
                Container(
                  height: 28,
                  decoration: const BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Welcome Card ─────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kOrangeLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kOrange.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF26522), Color(0xFFD44010)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _kOrange.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('🚀', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, Partner!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Login to start your delivery shift',
                  style: TextStyle(fontSize: 12.5, color: _kTextMid),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _kTextDark,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ─── Input field ──────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        style: const TextStyle(
          color: _kTextDark,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: _kTextMid.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(icon, color: _kOrange, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 46),
          suffixIcon: suffix,
          errorStyle: const TextStyle(
            color: _kRed,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_rounded, color: _kRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _kRed,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Primary button ───────────────────────────────────────────────────────────

class _PrimaryBtn extends StatefulWidget {
  const _PrimaryBtn({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );
  late final Animation<double> _s = Tween<double>(
    begin: 1.0,
    end: 0.96,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.loading ? null : (_) => _c.forward(),
      onTapUp: widget.loading
          ? null
          : (_) {
              _c.reverse();
              widget.onTap();
            },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: widget.loading
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFF26522), Color(0xFFD44010)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: widget.loading ? const Color(0xFFE0E0E0) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.loading
                ? []
                : [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.38),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
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

// ─── Info Strip ───────────────────────────────────────────────────────────────

class _InfoStrip extends StatelessWidget {
  const _InfoStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.shield_rounded, 'Verified\nPartners'),
      (Icons.payments_rounded, 'Instant\nPayouts'),
      (Icons.schedule_rounded, 'Flexible\nShifts'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kOrangeLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kOrange.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          return Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(item.$1, color: _kOrange, size: 20),
              ),
              const SizedBox(height: 7),
              Text(
                item.$2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _kTextDark,
                  height: 1.3,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Signup prompt ───────────────────────────────────────────────────────────

class _SignupPrompt extends StatelessWidget {
  const _SignupPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: RichText(
          text: const TextSpan(
            style: TextStyle(
              color: _kTextMid,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            children: [
              TextSpan(text: 'New partner? '),
              TextSpan(
                text: 'Create account',
                style: TextStyle(
                  color: _kOrangeDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

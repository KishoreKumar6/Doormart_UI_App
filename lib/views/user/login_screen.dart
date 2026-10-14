import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';

import '../../core/utils/validators.dart';
import '../../providers/app_state.dart';
import '../../widgets/toast_widget.dart';
import 'forgot_password_screen.dart';
import 'user_home_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFE8541A);
const _kOrangeDeep = Color(0xFFD44010);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kBg = Color(0xFFF7F7F8);
const _kCard = Colors.white;
const _kTextDark = Color(0xFF1A1A2E);
const _kTextMid = Color(0xFF8A8A9A);
const _kBorder = Color(0xFFE5E5EA);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ── Tab ──────────────────────────────────────────────────────────────────
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  // ── Form keys ─────────────────────────────────────────────────────────────
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  // ── Login controllers ──────────────────────────────────────────────────────
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  final _loginOtpCtrl = TextEditingController();
  bool _otpSent = false;
  _LoginMode _loginMode = _LoginMode.password;
  bool _obscureLoginPass = true;

  // ── Signup controllers ─────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agreed = false;
  bool _loading = false;

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
    _tabCtrl.dispose();
    _entryCtrl.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _loginOtpCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── Password strength ──────────────────────────────────────────────────────
  int _strength(String pwd) {
    if (pwd.isEmpty) return 0;
    var s = 0;
    if (pwd.length >= 6) s++;
    if (pwd.length >= 10 &&
        RegExp(r'[A-Z]').hasMatch(pwd) &&
        RegExp(r'[0-9]').hasMatch(pwd)) {
      s++;
    }
    if (pwd.length >= 8 && RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pwd)) {
      s++;
    }
    return s.clamp(0, 3);
  }

  String get _loginIdentifier => _loginEmailCtrl.text.trim();

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = message.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return 'The server took too long to respond. Please try again.';
    }
    if (message.isEmpty) return 'Something went wrong. Please try again.';
    return message;
  }

  void _showError(Object error) {
    showErrorToast(context, _friendlyError(error));
  }

  String? _loginIdentifierValidation() {
    if (_loginMode == _LoginMode.password) {
      return Validators.emailOrPhone(
        _loginIdentifier,
        emptyMessage: 'Enter your email or phone',
      );
    }
    return Validators.email(_loginIdentifier, emptyMessage: 'Enter your email');
  }

  Future<void> _sendLoginOtp() async {
    final validation = _loginIdentifierValidation();
    if (validation != null) {
      showErrorToast(context, validation);
      return;
    }

    setState(() {
      _loading = true;
    });
    try {
      await context.read<AppState>().sendOtp(
        email: _loginIdentifier.toLowerCase(),
      );
      if (!mounted) return;
      setState(() => _otpSent = true);
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) {
      showErrorToast(context, 'Please correct the highlighted fields.');
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      if (_loginMode == _LoginMode.otp && !_otpSent) {
        await context.read<AppState>().sendOtp(
          email: _loginIdentifier.toLowerCase(),
        );
        if (!mounted) return;
        setState(() => _otpSent = true);
        return;
      }
      final identifier = _loginIdentifier;
      final isEmail = identifier.contains('@');
      final normalizedPhone = Validators.normalizePhone(identifier);
      if (_loginMode == _LoginMode.password) {
        await context.read<AppState>().loginWithPassword(
          email: isEmail ? identifier.toLowerCase() : null,
          phone: isEmail ? null : normalizedPhone,
          password: _loginPassCtrl.text.trim(),
        );
      } else {
        await context.read<AppState>().verifyOtp(
          email: _loginIdentifier.toLowerCase(),
          otp: _loginOtpCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(UserHomeScreen.routeName, (route) => false);
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    if (_loading) return;
    HapticFeedback.mediumImpact();
    await context.read<AppState>().logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(UserHomeScreen.routeName, (route) => false);
  }

  Future<void> _signUp() async {
    if (!_signupFormKey.currentState!.validate()) {
      showErrorToast(context, 'Please correct the highlighted fields.');
      return;
    }
    if (!_agreed) {
      showErrorToast(
        context,
        'Please agree to the Terms of Service and Privacy Policy.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AppState>().register(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        addressLabel: 'Home',
        addressLine1: '',
        city: '',
        pincode: '',
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(UserHomeScreen.routeName, (route) => false);
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 620
                ? 600.0
                : constraints.maxWidth;
            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: _HeroHeader(
                    tabCtrl: _tabCtrl,
                    compact: false,
                    showTabs: false,
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _AuthTabsHeaderDelegate(tabCtrl: _tabCtrl),
                ),
              ],
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kOrange.withValues(alpha: 0.10),
                            blurRadius: 28,
                            spreadRadius: 2,
                            offset: const Offset(0, -5),
                          ),
                          const BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: TabBarView(
                            controller: _tabCtrl,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              // ── Login tab ─────────────────────────────────
                              _LoginTab(
                                formKey: _loginFormKey,
                                emailCtrl: _loginEmailCtrl,
                                passCtrl: _loginPassCtrl,
                                otpCtrl: _loginOtpCtrl,
                                otpSent: _otpSent,
                                loginMode: _loginMode,
                                obscurePass: _obscureLoginPass,
                                onTogglePass: () => setState(
                                  () => _obscureLoginPass = !_obscureLoginPass,
                                ),
                                onChangeMode: (mode) {
                                  setState(() {
                                    _loginMode = mode;
                                    _otpSent = false;
                                  });
                                },
                                loading: _loading,
                                onLogin: _login,
                                onGuest: _continueAsGuest,
                                onGoRegister: () => _tabCtrl.animateTo(1),
                                onGoForgotPassword: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed(ForgotPasswordScreen.routeName);
                                },
                                onResendOtp: _sendLoginOtp,
                              ),

                              // ── Sign up tab ───────────────────────────────
                              _SignupTab(
                                formKey: _signupFormKey,
                                nameCtrl: _nameCtrl,
                                emailCtrl: _emailCtrl,
                                phoneCtrl: _phoneCtrl,
                                passCtrl: _passCtrl,
                                confirmPassCtrl: _confirmPassCtrl,
                                obscurePass: _obscurePass,
                                obscureConfirm: _obscureConfirm,
                                onTogglePass: () => setState(
                                  () => _obscurePass = !_obscurePass,
                                ),
                                onToggleConfirm: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                                agreed: _agreed,
                                onToggleAgreed: () =>
                                    setState(() => _agreed = !_agreed),
                                loading: _loading,
                                strength: _strength(_passCtrl.text),
                                onPasswordChanged: () => setState(() {}),
                                onSignUp: _signUp,
                                onGoLogin: () => _tabCtrl.animateTo(0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Hero Header ──────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.tabCtrl,
    this.compact = false,
    this.showTabs = true,
  });
  final TabController tabCtrl;
  final bool compact;
  final bool showTabs;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF172033), Color(0xFFE8541A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'DoorMart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(height: 42, child: _AuthTabBar(tabCtrl: tabCtrl)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF172033), Color(0xFF263A58), Color(0xFFE8541A)],
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
              right: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: -40,
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

                // Back + logo row
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
                      const Spacer(),
                      // Logo badge
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Floating 3D brand badge
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: -0.13, end: 0.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutBack,
                  builder: (context, angle, child) => Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateY(angle)
                      ..rotateX(-angle * 0.45),
                    child: child,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Offset layers create a visible 3D extrusion.
                      for (final offset in [
                        const Offset(0, 8),
                        const Offset(0, 5),
                        const Offset(0, 2),
                      ])
                        Transform.translate(
                          offset: offset,
                          child: Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB83B12),
                              borderRadius: BorderRadius.circular(27),
                            ),
                          ),
                        ),
                      Container(
                        width: 86,
                        height: 86,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(27),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 25,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: Image.asset(
                            'assets/images/doormartLogo.jpeg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Title
                const Text(
                  'DoorMart Delivery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fresh groceries  •  delivered with care',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 32),

                if (showTabs) ...[
                  // Tab bar — sits at bottom of header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0x33000000),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _AuthTabBar(tabCtrl: tabCtrl),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // White curve at bottom of header
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

class _AuthTabBar extends StatelessWidget {
  const _AuthTabBar({required this.tabCtrl});

  final TabController tabCtrl;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: tabCtrl,
      indicator: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: _kOrange,
      unselectedLabelColor: Colors.white,
      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      tabs: const [
        Tab(text: 'Log In'),
        Tab(text: 'Sign Up'),
      ],
    );
  }
}

class _AuthTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _AuthTabsHeaderDelegate({required this.tabCtrl});

  final TabController tabCtrl;

  @override
  double get minExtent => 70;

  @override
  double get maxExtent => 70;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF263A58),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: _AuthTabBar(tabCtrl: tabCtrl),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AuthTabsHeaderDelegate oldDelegate) => false;
}

// ─── Login Tab ────────────────────────────────────────────────────────────────

class _LoginTab extends StatelessWidget {
  const _LoginTab({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.otpCtrl,
    required this.otpSent,
    required this.loginMode,
    required this.obscurePass,
    required this.onTogglePass,
    required this.onChangeMode,
    required this.loading,
    required this.onLogin,
    required this.onGuest,
    required this.onGoRegister,
    required this.onGoForgotPassword,
    required this.onResendOtp,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController otpCtrl;
  final bool otpSent;
  final _LoginMode loginMode;
  final bool obscurePass;
  final VoidCallback onTogglePass;
  final ValueChanged<_LoginMode> onChangeMode;
  final bool loading;
  final VoidCallback onLogin;
  final VoidCallback onGuest;
  final VoidCallback onGoRegister;
  final VoidCallback onGoForgotPassword;
  final Future<void> Function() onResendOtp;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        32 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            _WelcomeCard(
              emoji: '👋',
              title: 'Welcome back!',
              subtitle: 'Login to order fresh groceries',
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Password'),
                    selected: loginMode == _LoginMode.password,
                    onSelected: (_) => onChangeMode(_LoginMode.password),
                    selectedColor: _kOrangeLight,
                    labelStyle: TextStyle(
                      color: loginMode == _LoginMode.password
                          ? _kOrange
                          : _kTextDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Email OTP'),
                    selected: loginMode == _LoginMode.otp,
                    onSelected: (_) => onChangeMode(_LoginMode.otp),
                    selectedColor: _kOrangeLight,
                    labelStyle: TextStyle(
                      color: loginMode == _LoginMode.otp
                          ? _kOrange
                          : _kTextDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            _FieldLabel(
              loginMode == _LoginMode.password
                  ? 'Email or phone number'
                  : 'Email address',
            ),
            const SizedBox(height: 8),
            _Field(
              controller: emailCtrl,
              hint: loginMode == _LoginMode.password
                  ? 'you@example.com or 9876543210'
                  : 'you@example.com',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (loginMode == _LoginMode.password) {
                  return Validators.emailOrPhone(v);
                }
                return Validators.email(v, emptyMessage: 'Enter your email');
              },
            ),

            const SizedBox(height: 16),

            if (loginMode == _LoginMode.password) ...[
              _FieldLabel('Password'),
              const SizedBox(height: 8),
              _Field(
                controller: passCtrl,
                hint: 'Enter your password',
                icon: Icons.lock_rounded,
                obscure: obscurePass,
                suffix: _EyeToggle(
                  obscure: obscurePass,
                  onToggle: onTogglePass,
                ),
                validator: (v) => Validators.password(v),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onGoForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: _kOrange,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ] else ...[
              _FieldLabel('OTP'),
              const SizedBox(height: 8),
              _Field(
                controller: otpCtrl,
                hint: 'Enter the 6 digit OTP',
                icon: Icons.password_rounded,
                keyboardType: TextInputType.number,
                validator: (v) => otpSent
                    ? Validators.requiredText(v, message: 'Enter OTP')
                    : null,
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: otpSent ? onResendOtp : null,
                  style: TextButton.styleFrom(
                    foregroundColor: _kOrange,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Resend OTP',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            _PrimaryBtn(
              label: loginMode == _LoginMode.password
                  ? 'Login with Password'
                  : (otpSent ? 'Verify OTP' : 'Send OTP'),
              icon: loginMode == _LoginMode.password
                  ? Icons.login_rounded
                  : (otpSent ? Icons.verified_rounded : Icons.send_rounded),
              loading: loading,
              onTap: onLogin,
            ),

            const SizedBox(height: 12),

            _GuestBtn(loading: loading, onTap: onGuest),

            const SizedBox(height: 24),

            _SwitchPrompt(
              question: "Don't have an account? ",
              action: 'Sign Up',
              onTap: onGoRegister,
            ),
          ],
        ),
      ),
    );
  }
}

enum _LoginMode { password, otp }

// ─── Sign Up Tab ──────────────────────────────────────────────────────────────

class _SignupTab extends StatelessWidget {
  const _SignupTab({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.confirmPassCtrl,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.agreed,
    required this.onToggleAgreed,
    required this.loading,
    required this.strength,
    required this.onPasswordChanged,
    required this.onSignUp,
    required this.onGoLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmPassCtrl;
  final bool obscurePass;
  final bool obscureConfirm;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;
  final bool agreed;
  final VoidCallback onToggleAgreed;
  final bool loading;
  final int strength;
  final VoidCallback onPasswordChanged;
  final VoidCallback onSignUp;
  final VoidCallback onGoLogin;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        32 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeCard(
              emoji: '✨',
              title: 'Create account',
              subtitle: 'Join Doormart for fast grocery delivery',
            ),

            const SizedBox(height: 24),

            // ── Full name ────────────────────────────────────────────
            _FieldLabel('Full name'),
            const SizedBox(height: 8),
            _Field(
              controller: nameCtrl,
              hint: 'Jane Doe',
              icon: Icons.person_rounded,
              keyboardType: TextInputType.name,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter your full name';
                }
                if (v.trim().length < 2) return 'Name is too short';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Email ────────────────────────────────────────────────
            _FieldLabel('Email address'),
            const SizedBox(height: 8),
            _Field(
              controller: emailCtrl,
              hint: 'you@example.com',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter your email';
                }
                if (!RegExp(
                  r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$',
                ).hasMatch(v.trim())) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Phone ────────────────────────────────────────────────
            _FieldLabel('Phone number'),
            const SizedBox(height: 8),
            _Field(
              controller: phoneCtrl,
              hint: '+91 98765 43210',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter your phone number';
                }
                final digits = v.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 10) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Password ─────────────────────────────────────────────
            _FieldLabel('Password'),
            const SizedBox(height: 8),
            _Field(
              controller: passCtrl,
              hint: 'At least 6 characters',
              icon: Icons.lock_rounded,
              obscure: obscurePass,
              suffix: _EyeToggle(obscure: obscurePass, onToggle: onTogglePass),
              onChanged: (_) => onPasswordChanged(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Create a password';
                if (v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 8),

            // Password strength bar
            if (passCtrl.text.isNotEmpty) _StrengthBar(strength: strength),

            const SizedBox(height: 16),

            // ── Confirm password ──────────────────────────────────────
            _FieldLabel('Confirm password'),
            const SizedBox(height: 8),
            _Field(
              controller: confirmPassCtrl,
              hint: 'Re-enter your password',
              icon: Icons.lock_outlined,
              obscure: obscureConfirm,
              suffix: _EyeToggle(
                obscure: obscureConfirm,
                onToggle: onToggleConfirm,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Confirm your password';
                }
                if (v != passCtrl.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ── Terms ─────────────────────────────────────────────────
            _TermsRow(agreed: agreed, onToggle: onToggleAgreed),

            const SizedBox(height: 20),

            _PrimaryBtn(
              label: 'Create Account',
              icon: Icons.person_add_rounded,
              loading: loading,
              onTap: onSignUp,
            ),

            const SizedBox(height: 24),

            _SwitchPrompt(
              question: 'Already have an account? ',
              action: 'Log In',
              onTap: onGoLogin,
            ),

            const SizedBox(height: 20),

            // Perks strip
            const _PerksStrip(),
          ],
        ),
      ),
    );
  }
}

// ─── Welcome Card ─────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
  final String emoji, title, subtitle;

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
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _kTextDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: _kTextMid),
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
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
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
        onChanged: onChanged,
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

// ─── Eye toggle ───────────────────────────────────────────────────────────────

class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.obscure, required this.onToggle});
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: _kTextMid,
        size: 20,
      ),
      onPressed: onToggle,
    );
  }
}

// ─── Password strength bar ────────────────────────────────────────────────────

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.strength});
  final int strength;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (strength) {
      1 => ('Weak', _kRed),
      2 => ('Fair', const Color(0xFFF59E0B)),
      _ => ('Strong', _kGreen),
    };

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(3, (i) {
              final filled = i < strength;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: filled ? color : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Terms row ────────────────────────────────────────────────────────────────

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.agreed, required this.onToggle});
  final bool agreed;
  final VoidCallback onToggle;

  void _showPolicySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.86,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Terms of Service & Privacy Policy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _kTextDark,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(sheetContext),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0EB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: _kOrange,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: const [
                          _PolicyBlock(
                            title: 'Terms of Service',
                            body:
                                'By using Doormart, you agree to use the app responsibly, provide accurate information, and comply with applicable laws. Orders, offers, availability, and delivery times may change based on stock, location, and operational conditions.',
                          ),
                          _PolicyBlock(
                            title: 'Account Responsibility',
                            body:
                                'You are responsible for keeping your login details secure and for any activity carried out under your account. Please notify support immediately if you suspect unauthorised access.',
                          ),
                          _PolicyBlock(
                            title: 'Privacy Policy',
                            body:
                                'We collect the information needed to process orders, deliver items, provide support, and improve the service. This includes name, phone number, email, delivery address, and order history.',
                          ),
                          _PolicyBlock(
                            title: 'How We Use Data',
                            body:
                                'Your information helps us fulfil orders, coordinate delivery, communicate order updates, prevent fraud, and support product improvements. We do not sell your personal data.',
                          ),
                          _PolicyBlock(
                            title: 'Sharing & Security',
                            body:
                                'We only share information with trusted service providers and delivery personnel when required to complete your order or operate the app. We use reasonable safeguards, but no system is completely secure.',
                          ),
                          _PolicyBlock(
                            title: 'Updates',
                            body:
                                'We may update these terms and the privacy policy from time to time. Continued use of the app after updates means you accept the revised terms.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              gradient: agreed
                  ? const LinearGradient(
                      colors: [Color(0xFFF26522), Color(0xFFD44010)],
                    )
                  : null,
              color: agreed ? null : _kCard,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: agreed ? Colors.transparent : _kBorder,
                width: 1.5,
              ),
              boxShadow: agreed
                  ? [
                      BoxShadow(
                        color: _kOrange.withValues(alpha: 0.30),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: agreed
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: _kTextMid,
                  fontSize: 12.5,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: "I agree to Doormart's "),
                  TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                      color: _kOrange,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _showPolicySheet(context),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      color: _kOrange,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _showPolicySheet(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyBlock extends StatelessWidget {
  const _PolicyBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Colors.black.withValues(alpha: 0.70),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Or divider ───────────────────────────────────────────────────────────────

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

class _GuestBtn extends StatefulWidget {
  const _GuestBtn({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  State<_GuestBtn> createState() => _GuestBtnState();
}

class _GuestBtnState extends State<_GuestBtn>
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _kOrange.withValues(alpha: 0.28),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline_rounded, color: _kOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Continue as Guest',
                  style: TextStyle(
                    color: _kOrangeDeep,
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

// ─── Switch prompt ────────────────────────────────────────────────────────────

class _SwitchPrompt extends StatelessWidget {
  const _SwitchPrompt({
    required this.question,
    required this.action,
    required this.onTap,
  });
  final String question, action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13.5),
            children: [
              TextSpan(
                text: question,
                style: const TextStyle(color: _kTextMid),
              ),
              TextSpan(
                text: action,
                style: const TextStyle(
                  color: _kOrange,
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

// ─── Perks strip (signup only) ────────────────────────────────────────────────

class _PerksStrip extends StatelessWidget {
  const _PerksStrip();

  @override
  Widget build(BuildContext context) {
    const perks = [
      (Icons.bolt_rounded, '10 min\nDelivery'),
      (Icons.verified_rounded, 'Fresh\nProducts'),
      (Icons.local_offer_rounded, 'Best\nPrices'),
      (Icons.support_agent_rounded, '24/7\nSupport'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kOrangeLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kOrange.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why Doormart?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: perks.map((p) {
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
                    child: Icon(p.$1, color: _kOrange, size: 20),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    p.$2,
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
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../providers/app_state.dart';

const _kOrange = Color(0xFFE8541A);
const _kBg = Color(0xFFF7F7F8);
const _kCard = Colors.white;
const _kTextDark = Color(0xFF1A1A2E);
const _kTextMid = Color(0xFF8A8A9A);
const _kBorder = Color(0xFFE5E5EA);
const _kRed = Color(0xFFEF4444);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  static const routeName = '/forgot-password';

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _otpSent = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _motionController.dispose();
    super.dispose();
  }

  String get _identifier => _identifierCtrl.text.trim();

  String get _normalizedIdentifier {
    final value = _identifier;
    if (value.contains('@')) return value.toLowerCase();
    return Validators.normalizePhone(value);
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().sendPasswordResetOtp(
        identifier: _normalizedIdentifier,
      );
      if (!mounted) return;
      setState(() => _otpSent = true);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().resetPasswordWithOtp(
        identifier: _normalizedIdentifier,
        otp: _otpCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ForgotPasswordAppBar(),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6A2A), Color(0xFFE8541A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: _kOrange.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _motionController,
                        builder: (context, child) {
                          final t = Curves.easeInOut.transform(
                            _motionController.value,
                          );
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0015)
                              ..rotateY(-0.10 + (t * 0.20))
                              ..rotateX(0.04 - (t * 0.08)),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB83B12),
                                    borderRadius: BorderRadius.circular(19),
                                  ),
                                ),
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                      color: Colors.white54,
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x44000000),
                                        blurRadius: 12,
                                        offset: Offset(0, 7),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.lock_reset_rounded,
                                    color: Colors.white,
                                    size: 29,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reset your password',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'We’ll email you a secure OTP to continue.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _StepCard(otpSent: _otpSent),
                const SizedBox(height: 20),
                _FieldLabel('Registered email address'),
                const SizedBox(height: 8),
                _Field(
                  controller: _identifierCtrl,
                  hint: 'Enter your email address',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => Validators.email(v),
                ),
                const SizedBox(height: 16),
                if (_otpSent) ...[
                  _FieldLabel('OTP'),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _otpCtrl,
                    hint: 'Enter the OTP sent to your registered email',
                    icon: Icons.pin_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        Validators.requiredText(v, message: 'Enter the OTP'),
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('New password'),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _passCtrl,
                    hint: 'Create a new password',
                    icon: Icons.lock_rounded,
                    obscure: _obscurePass,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: _kTextMid,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: (v) {
                      final basic = Validators.password(
                        v,
                        minLength: 8,
                        message: 'Enter a new password',
                      );
                      if (basic != null) return basic;
                      final password = v!.trim();
                      if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
                          !RegExp(r'\d').hasMatch(password)) {
                        return 'Use at least 8 characters with a letter and number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('Confirm password'),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _confirmCtrl,
                    hint: 'Re-enter your new password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscureConfirm,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: _kTextMid,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) {
                      final required = Validators.requiredText(
                        v,
                        message: 'Confirm your password',
                      );
                      if (required != null) return required;
                      if (v != _passCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 24),
                _PrimaryBtn(
                  label: _otpSent ? 'Reset Password' : 'Send OTP',
                  icon: _otpSent
                      ? Icons.lock_reset_rounded
                      : Icons.send_rounded,
                  loading: _loading,
                  onTap: _otpSent ? _resetPassword : _sendOtp,
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _otpSent = false;
                              _otpCtrl.clear();
                              _passCtrl.clear();
                              _confirmCtrl.clear();
                              _error = null;
                            });
                          },
                    child: const Text('Change email / resend OTP'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .07),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              size: 26,
              color: _kTextDark,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'Forgot password',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: _kTextDark,
            letterSpacing: -.4,
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.otpSent});
  final bool otpSent;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _kBorder),
    ),
    child: Row(
      children: [
        _Step(number: '1', label: 'Email', active: !otpSent),
        Expanded(
          child: Container(height: 2, color: otpSent ? _kOrange : _kBorder),
        ),
        _Step(number: '2', label: 'Verify & reset', active: otpSent),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.label,
    required this.active,
  });
  final String number;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 15,
        backgroundColor: active ? _kOrange : _kBorder,
        child: Text(
          number,
          style: TextStyle(
            color: active ? Colors.white : _kTextMid,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: active ? _kOrange : _kTextMid,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      color: _kTextDark,
      fontSize: 14,
    ),
  );
}

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
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    validator: validator,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: _kTextMid),
      suffixIcon: suffix,
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kRed.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kRed.withValues(alpha: 0.18)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: _kRed, fontWeight: FontWeight.w700),
    ),
  );
}

class _PrimaryBtn extends StatelessWidget {
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
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

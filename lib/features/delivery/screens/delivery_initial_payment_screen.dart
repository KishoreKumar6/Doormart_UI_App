import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupi.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfupipayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/toast_widget.dart';
import '../providers/delivery_provider.dart';
import '../services/cashfree_web_bridge.dart';
import 'delivery_home_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFE8541A);
const _kOrangeLight = Color(0xFFFFF0EB);
const _kBg = Color(0xFFF7F7F7);
const _kCard = Colors.white;
const _kTextDark = Color(0xFF1A1A1A);
const _kTextMid = Color(0xFF888888);
const _kGreen = Color(0xFF22C55E);
const _kGreenLight = Color(0xFFDCFCE7);
const _kBorder = Color(0xFFEEEEEE);

class DeliveryInitialPaymentScreen extends StatefulWidget {
  const DeliveryInitialPaymentScreen({super.key});
  static const routeName = '/delivery/payment';

  @override
  State<DeliveryInitialPaymentScreen> createState() =>
      _DeliveryInitialPaymentScreenState();
}

class _DeliveryInitialPaymentScreenState
    extends State<DeliveryInitialPaymentScreen>
    with WidgetsBindingObserver {
  final CFPaymentGatewayService _gatewayService = CFPaymentGatewayService();

  bool _isProcessing = false;
  bool _isVerifying = false;
  String? _pendingOrderId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gatewayService.setCallback(_onPaymentVerified, _onPaymentError);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<DeliveryProvider>();
      await provider.syncInitialPaymentStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _isProcessing &&
        !_isVerifying &&
        _pendingOrderId != null &&
        _pendingOrderId!.isNotEmpty) {
      unawaited(_verifyPaymentWithBackend(_pendingOrderId!));
    }
  }

  void _onPaymentVerified(String orderId) {
    final effectiveOrderId = orderId.isNotEmpty
        ? orderId
        : (_pendingOrderId ?? '');
    if (effectiveOrderId.isNotEmpty) {
      unawaited(_verifyPaymentWithBackend(effectiveOrderId));
    }
  }

  void _onPaymentError(CFErrorResponse errorResponse, String orderId) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _isVerifying = false;
    });
    final msg = (errorResponse.getMessage() ?? '').trim();
    final message = msg.isNotEmpty
        ? msg
        : 'Payment was not completed. Please retry.';
    setState(() {
      _errorMessage = message;
    });
    showToast(context, message);
  }

  static CFEnvironment _parseEnvironment(String? env) {
    if (env == null || env.isEmpty) return CFEnvironment.SANDBOX;
    final clean = env.trim().toUpperCase();
    if (clean == 'PROD' || clean == 'PRODUCTION') {
      return CFEnvironment.PRODUCTION;
    }
    return CFEnvironment.SANDBOX;
  }

  Future<void> _handleProceedToPay() async {
    final provider = context.read<DeliveryProvider>();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final initiateData = await provider.initiateInitialPayment();
      final orderId = initiateData['orderId'] as String? ?? '';
      final paymentSessionId =
          initiateData['paymentSessionId'] as String? ?? '';
      final paymentUrl = initiateData['paymentUrl'] as String?;
      final envString = initiateData['environment'] as String?;
      final environment = _parseEnvironment(envString);

      if (orderId.isEmpty) {
        throw StateError('Order ID missing from payment initiation response.');
      }

      _pendingOrderId = orderId;

      // On Web: use Cashfree Web JS SDK v3 checkout modal
      if (kIsWeb) {
        if (paymentSessionId.isNotEmpty) {
          final webResult = await launchCashfreeWebCheckout(
            paymentSessionId: paymentSessionId,
            environment: envString ?? 'sandbox',
          );
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            // ALWAYS verify with backend first - Cashfree might have captured the payment
            // even if the browser modal reported closed / cancelled / error.
            final verified = await _verifyPaymentWithBackend(
              orderId,
              silentFail: true,
            );
            if (!verified && mounted) {
              final error = webResult['error'];
              if (error != null && error.toString().isNotEmpty) {
                final errorMsg = error.toString();
                setState(() {
                  _errorMessage = errorMsg;
                });
                showToast(context, errorMsg);
              }
            }
          }
          return;
        } else if (paymentUrl != null && paymentUrl.isNotEmpty) {
          final uri = Uri.parse(paymentUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
            }
          }
          return;
        } else {
          throw StateError('Payment session ID or URL not available.');
        }
      }

      // Native fallback if session ID is empty
      if (paymentSessionId.isEmpty &&
          paymentUrl != null &&
          paymentUrl.isNotEmpty) {
        final uri = Uri.parse(paymentUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        }
        return;
      }

      // Mobile native PG flow with Cashfree SDK
      final session = CFSessionBuilder()
          .setEnvironment(environment)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      final upi = CFUPIBuilder()
          .setChannel(CFUPIChannel.INTENT_WITH_UI)
          .build();
      final payment = CFUPIPaymentBuilder()
          .setSession(session)
          .setUPI(upi)
          .build();

      _gatewayService.doPayment(payment);
    } on CFException catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = error.message;
      });
      showToast(context, error.message);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isProcessing = false;
        _errorMessage = msg;
      });
      showToast(context, msg);
    }
  }

  Future<bool> _verifyPaymentWithBackend(
    String orderId, {
    bool silentFail = false,
  }) async {
    if (_isVerifying) return false;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final provider = context.read<DeliveryProvider>();
    final verified = await provider.verifyInitialPayment(orderId);

    if (!mounted) return verified;
    setState(() {
      _isProcessing = false;
      _isVerifying = false;
    });

    if (verified) {
      showToast(
        context,
        'Payment verified successfully! You are now eligible to go online.',
      );
      HapticFeedback.mediumImpact();
    } else if (!silentFail) {
      final err =
          provider.initialPaymentError ??
          'Payment verification pending or failed. Please check status again.';
      setState(() {
        _errorMessage = err;
      });
      showToast(context, err);
    }
    return verified;
  }

  Future<void> _handleSimulateSandboxPayment(String orderId) async {
    if (_isVerifying) return;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final provider = context.read<DeliveryProvider>();
    final verified = await provider.simulateSandboxPayment(orderId);

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _isVerifying = false;
    });

    if (verified) {
      showToast(
        context,
        'Sandbox payment verified! You are now eligible to go online.',
      );
      HapticFeedback.mediumImpact();
    } else {
      final err =
          provider.initialPaymentError ??
          'Sandbox payment simulation failed. Please retry.';
      setState(() {
        _errorMessage = err;
      });
      showToast(context, err);
    }
  }

  Future<void> _handleQuickSandboxActivation() async {
    final provider = context.read<DeliveryProvider>();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final initiateData = await provider.initiateInitialPayment();
      final orderId = initiateData['orderId'] as String? ?? '';
      if (orderId.isEmpty) {
        throw StateError('Order ID missing from response.');
      }
      _pendingOrderId = orderId;
      await _handleSimulateSandboxPayment(orderId);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isProcessing = false;
        _errorMessage = msg;
      });
      showToast(context, msg);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour =
        (local.hour > 12
                ? local.hour - 12
                : (local.hour == 0 ? 12 : local.hour))
            .toString()
            .padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year at $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final isPaid = provider.isInitialPaymentPaid;
    final amount = provider.initialPaymentAmount;
    final completedAt =
        provider.initialPaymentCompletedAt ??
        provider.deliveryPerson?.initialPaymentCompletedAt;
    final method =
        provider.initialPaymentMethod ??
        provider.deliveryPerson?.initialPaymentMethod;
    final reference =
        provider.initialPaymentReference ??
        provider.deliveryPerson?.initialPaymentReference;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _kTextDark),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(
                context,
              ).pushReplacementNamed(DeliveryHomeScreen.routeName);
            }
          },
          tooltip: 'Back',
        ),
        title: const Text(
          'Partner Onboarding Fee',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _kTextDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _kOrange,
          onRefresh: () async {
            await provider.syncInitialPaymentStatus();
            if (_pendingOrderId != null && !isPaid) {
              await _verifyPaymentWithBackend(_pendingOrderId!);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: isPaid
                    ? _buildPaidView(
                        context: context,
                        amount: amount,
                        completedAt: completedAt,
                        method: method,
                        reference: reference,
                      )
                    : _buildUnpaidView(
                        context: context,
                        provider: provider,
                        amount: amount,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaidView({
    required BuildContext context,
    required double amount,
    DateTime? completedAt,
    String? method,
    String? reference,
  }) {
    final formattedMethod = (method != null && method.isNotEmpty)
        ? (method.toLowerCase() == 'cashfree'
              ? 'Cashfree Payments'
              : method.toUpperCase())
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Hero Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: _kGreenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _kGreen,
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Payment Verified & Authorized',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _kTextDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your delivery partner onboarding fee has been received and verified. Your account is authorized to start working. You can toggle your work status to Active anytime from the dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.45, color: _kTextMid),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kGreenLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: _kGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'STATUS: AUTHORIZED TO WORK',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _kGreen,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Receipt Details Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kOrangeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: _kOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Receipt Summary',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _kTextDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow(
                'Fee Amount',
                '₹${amount > 0 ? amount.toStringAsFixed(0) : "500"}',
                bold: true,
              ),
              const Divider(height: 20, color: _kBorder),
              _detailRow(
                'Payment Status',
                'PAID',
                valueColor: _kGreen,
                bold: true,
              ),
              if (completedAt != null) ...[
                const Divider(height: 20, color: _kBorder),
                _detailRow('Date & Time', _formatDate(completedAt)),
              ],
              if (formattedMethod != null) ...[
                const Divider(height: 20, color: _kBorder),
                _detailRow('Method', formattedMethod),
              ],
              if (reference != null && reference.isNotEmpty) ...[
                const Divider(height: 20, color: _kBorder),
                _detailRow(
                  'Reference / Order ID',
                  reference,
                  isMonospace: true,
                  copyable: true,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: reference));
                    HapticFeedback.lightImpact();
                    showToast(context, 'Order ID copied to clipboard');
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Continue Button
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              DeliveryHomeScreen.routeName,
              (route) => false,
            );
          },
          icon: const Icon(Icons.dashboard_rounded, size: 20),
          label: const Text(
            'Go to Delivery Dashboard',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildUnpaidView({
    required BuildContext context,
    required DeliveryProvider provider,
    required double amount,
  }) {
    final effectiveAmount = amount > 0 ? amount : 500.0;
    final isLoading =
        _isProcessing ||
        _isVerifying ||
        provider.initialPaymentLoading ||
        provider.initialPaymentVerifying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Error banner if any
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: const Color(0xFF991B1B),
                  onPressed: () => setState(() => _errorMessage = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Header Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: _kOrangeLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: _kOrange,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'One-Time Activation Fee',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'To activate customer delivery requests and enable going online, complete the one-time partner onboarding fee below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.45, color: _kTextMid),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL PAYABLE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: _kTextMid,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${effectiveAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: _kOrange,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'One-time platform activation',
                      style: TextStyle(
                        fontSize: 12,
                        color: _kTextMid,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // What You Get Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What is included:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 14),
              _benefitItem(
                Icons.check_circle_outline_rounded,
                'Order Access',
                'Instantly receive nearby pickup & drop requests.',
              ),
              const SizedBox(height: 12),
              _benefitItem(
                Icons.toggle_on_rounded,
                'Go Online Anytime',
                'Toggle active shift status whenever you are ready to earn.',
              ),
              const SizedBox(height: 12),
              _benefitItem(
                Icons.account_balance_wallet_outlined,
                'Full Earnings & Tips',
                'Earn per delivery trip with transparent in-app payouts.',
              ),
              const SizedBox(height: 12),
              _benefitItem(
                Icons.support_agent_rounded,
                'Partner Support',
                'Direct hotline assistance for delivery issues.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Cashfree Trust Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF475569),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '100% Secure Payment processed via Cashfree Payments (UPI, Cards, NetBanking)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Action Buttons
        ElevatedButton(
          onPressed: isLoading ? null : _handleProceedToPay,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            disabledBackgroundColor: _kOrange.withValues(alpha: 0.6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isVerifying ? 'Verifying Payment...' : 'Processing...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Pay ₹${effectiveAmount.toStringAsFixed(0)} Now',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
        ),

        if (_pendingOrderId != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: isLoading
                ? null
                : () => _verifyPaymentWithBackend(_pendingOrderId!),
            child: const Text(
              'Already paid? Check verification status',
              style: TextStyle(
                color: _kOrange,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: isLoading
                ? null
                : () => _handleSimulateSandboxPayment(_pendingOrderId!),
            icon: const Icon(
              Icons.bolt_rounded,
              size: 18,
              color: Color(0xFF0284C7),
            ),
            label: const Text(
              '[Test] Complete Sandbox Payment Now',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFBAE6FD)),
              backgroundColor: const Color(0xFFF0F9FF),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLoading ? null : _handleQuickSandboxActivation,
            icon: const Icon(
              Icons.bolt_rounded,
              size: 18,
              color: Color(0xFF0284C7),
            ),
            label: const Text(
              '[Test] Quick Sandbox Activation (Instant Test)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFBAE6FD)),
              backgroundColor: const Color(0xFFF0F9FF),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _benefitItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _kOrange, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _kTextMid,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
    bool isMonospace = false,
    bool copyable = false,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextMid,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: copyable
                ? InkWell(
                    onTap: onCopy,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              value,
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: bold
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: valueColor ?? _kTextDark,
                                fontFamily: isMonospace ? 'monospace' : null,
                                letterSpacing: isMonospace ? -0.3 : 0,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: _kOrange,
                          ),
                        ],
                      ),
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                      color: valueColor ?? _kTextDark,
                      fontFamily: isMonospace ? 'monospace' : null,
                      letterSpacing: isMonospace ? -0.3 : 0,
                      height: 1.4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

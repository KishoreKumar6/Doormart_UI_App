import 'dart:math' as math;
import 'package:flutter/material.dart';

class WalkingMascotWidget extends StatefulWidget {
  const WalkingMascotWidget({super.key});

  @override
  State<WalkingMascotWidget> createState() => _WalkingMascotWidgetState();
}

class _WalkingMascotWidgetState extends State<WalkingMascotWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const int _stepsPerTrip = 10;
  static const double _mascotWidth = 64;
  static const double _mascotHeight = 70;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _pingPong(double value) {
    if (value < 0.5) {
      return value * 2;
    }
    return (1 - value) * 2;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final trackWidth = math.max(0.0, screenWidth - _mascotWidth);

    return SizedBox(
      width: screenWidth,
      height: _mascotHeight + 8,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final goingRight = t < 0.5;
            final progress = _pingPong(t);
            final dx = progress * trackWidth;

            final phase = t * _stepsPerTrip * 2 * math.pi * 2;
            final legSwing = math.sin(phase);
            final armSwing = math.sin(phase + math.pi);
            final bounce = math.sin(phase * 2).abs() * 3.2;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: dx,
                  bottom: 0,
                  child: Semantics(
                    label: 'Walking grocery mascot',
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scale(goingRight ? 1.0 : -1.0, 1.0),
                      child: CustomPaint(
                        size: const Size(_mascotWidth, _mascotHeight),
                        painter: _BabyMascotPainter(
                          legSwing: legSwing,
                          armSwing: armSwing,
                          bounce: bounce,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BabyMascotPainter extends CustomPainter {
  _BabyMascotPainter({
    required this.legSwing,
    required this.armSwing,
    required this.bounce,
  });

  final double legSwing;
  final double armSwing;
  final double bounce;

  static const Color skin = Color(0xFFFFD9B3);
  static const Color skinShade = Color(0xFFF5B98A);
  static const Color onesie = Color(0xFF6FCF97);
  static const Color onesieShade = Color(0xFF4FB37C);
  static const Color hair = Color.fromARGB(255, 10, 5, 2);
  static const Color cheek = Color(0xFFFF9E9E);
  static const Color bagColor = Color(0xFFC98A4B);
  static const Color bagShade = Color(0xFFAE7238);
  static const Color leafGreen = Color(0xFF6FBF73);
  static const Color carrotOrange = Color(0xFFFF9F43);
  static const Color shadowColor = Color(0x33000000);

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double groundY = size.height - 6;
    final double bodyTopY = groundY - 34 - bounce;
    final double hipY = groundY - 20 - bounce;
    final double headCenterY = bodyTopY - 12;

    _drawShadow(canvas, cx, groundY, bounce);

    _drawLeg(canvas, Offset(cx - 3, hipY), -legSwing, groundY, back: true);
    _drawArm(canvas, Offset(cx - 6, bodyTopY + 4), -armSwing, back: true);

    final bodyRect = Rect.fromCenter(
      center: Offset(cx, (bodyTopY + hipY) / 2 + 2),
      width: 24,
      height: 26,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(12)),
      Paint()..color = onesie,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bodyRect.deflate(3).translate(0, 4),
        const Radius.circular(10),
      ),
      Paint()..color = onesieShade.withValues(alpha: 0.35),
    );

    final buttonPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (int i = 0; i < 2; i++) {
      canvas.drawCircle(Offset(cx, bodyTopY + 6 + i * 7), 1.6, buttonPaint);
    }

    _drawLeg(canvas, Offset(cx + 3, hipY), legSwing, groundY, back: false);

    final headCenter = Offset(cx, headCenterY);
    canvas.drawCircle(headCenter, 13, Paint()..color = skin);
    canvas.drawCircle(
      Offset(cx - 12, headCenterY + 1),
      3.2,
      Paint()..color = skin,
    );
    canvas.drawCircle(
      Offset(cx + 12, headCenterY + 1),
      3.2,
      Paint()..color = skin,
    );

    final hairPath = Path()
      ..moveTo(cx - 9, headCenterY - 9)
      ..quadraticBezierTo(cx, headCenterY - 22, cx + 9, headCenterY - 9)
      ..quadraticBezierTo(cx, headCenterY - 13, cx - 9, headCenterY - 9)
      ..close();

    canvas.drawPath(hairPath, Paint()..color = hair);

    final curlPath = Path()
      ..moveTo(cx - 1, headCenterY - 18)
      ..quadraticBezierTo(cx + 4, headCenterY - 24, cx + 1, headCenterY - 16);

    canvas.drawPath(
      curlPath,
      Paint()
        ..color = hair
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      Offset(cx - 6.5, headCenterY + 3.5),
      2.1,
      Paint()..color = cheek.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      Offset(cx + 6.5, headCenterY + 3.5),
      2.1,
      Paint()..color = cheek.withValues(alpha: 0.7),
    );

    final eyePaint = Paint()..color = const Color(0xFF3B2A20);
    canvas.drawCircle(Offset(cx - 4.2, headCenterY), 1.5, eyePaint);
    canvas.drawCircle(Offset(cx + 4.2, headCenterY), 1.5, eyePaint);

    final smilePath = Path()
      ..moveTo(cx - 3.5, headCenterY + 5)
      ..quadraticBezierTo(cx, headCenterY + 8.5, cx + 3.5, headCenterY + 5);

    canvas.drawPath(
      smilePath,
      Paint()
        ..color = const Color(0xFF3B2A20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    _drawArm(canvas, Offset(cx + 6, bodyTopY + 4), armSwing, back: false);
    _drawGroceryBag(canvas, Offset(cx + 6, bodyTopY + 4), armSwing);
  }

  void _drawShadow(Canvas canvas, double cx, double groundY, double bounce) {
    final double scale = (1 - bounce / 6).clamp(0.6, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + 4),
        width: 30 * scale,
        height: 6 * scale,
      ),
      Paint()..color = shadowColor,
    );
  }

  void _drawLeg(
    Canvas canvas,
    Offset hip,
    double swing,
    double groundY, {
    required bool back,
  }) {
    final double angle = swing * 0.6;
    final double legLength = groundY - hip.dy;

    final Offset foot = Offset(
      hip.dx + math.sin(angle) * legLength * 0.6,
      hip.dy + math.cos(angle) * legLength,
    );

    canvas.drawLine(
      hip,
      foot,
      Paint()
        ..color = back ? skinShade.withValues(alpha: 0.9) : skin
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(foot, 4.2, Paint()..color = back ? onesieShade : onesie);
  }

  void _drawArm(
    Canvas canvas,
    Offset shoulder,
    double swing, {
    required bool back,
  }) {
    final double angle = swing * 0.5;
    const double armLength = 16;

    final Offset hand = Offset(
      shoulder.dx + math.sin(angle) * armLength * 0.5,
      shoulder.dy + math.cos(angle) * armLength,
    );

    canvas.drawLine(
      shoulder,
      hand,
      Paint()
        ..color = back ? skinShade.withValues(alpha: 0.85) : skin
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawGroceryBag(Canvas canvas, Offset shoulder, double swing) {
    final double angle = swing * 0.5;
    const double armLength = 16;

    final Offset hand = Offset(
      shoulder.dx + math.sin(angle) * armLength * 0.5,
      shoulder.dy + math.cos(angle) * armLength,
    );

    canvas.save();
    canvas.translate(hand.dx, hand.dy + 6);
    canvas.rotate(angle * 0.4);

    final bagRect = Rect.fromCenter(center: Offset.zero, width: 16, height: 18);

    final bagRRect = RRect.fromRectAndCorners(
      bagRect,
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(2),
      bottomLeft: const Radius.circular(5),
      bottomRight: const Radius.circular(5),
    );

    canvas.drawRRect(bagRRect, Paint()..color = bagColor);
    canvas.drawRRect(
      bagRRect.deflate(2),
      Paint()..color = bagShade.withValues(alpha: 0.3),
    );

    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -8), width: 12, height: 4),
      Paint()..color = bagShade,
    );

    canvas.drawCircle(const Offset(-3, -10), 3, Paint()..color = carrotOrange);

    final leafPath = Path()
      ..moveTo(3, -9)
      ..quadraticBezierTo(6, -16, 2, -17)
      ..quadraticBezierTo(0, -13, 3, -9)
      ..close();

    canvas.drawPath(leafPath, Paint()..color = leafGreen);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BabyMascotPainter oldDelegate) {
    return oldDelegate.legSwing != legSwing ||
        oldDelegate.armSwing != armSwing ||
        oldDelegate.bounce != bounce;
  }
}

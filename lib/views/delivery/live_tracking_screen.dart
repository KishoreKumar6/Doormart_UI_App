import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_page.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  static const routeName = '/delivery/live-tracking';

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _sharingLocation = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Live tracking',
      children: [
        _TrackingHero(
          controller: _controller,
          sharingLocation: _sharingLocation,
          onToggleSharing: () {
            setState(() => _sharingLocation = !_sharingLocation);
          },
        ),
        const SizedBox(height: 14),
        const _TrackingStats(),
        const SizedBox(height: 14),
        const _CurrentDeliveryCard(),
        const SizedBox(height: 14),
        const _RouteTimeline(),
        const SizedBox(height: 14),
        const _LocationStreamCard(),
        const SizedBox(height: 14),
        const _TrackingActions(),
      ],
    );
  }
}

class _TrackingHero extends StatelessWidget {
  const _TrackingHero({
    required this.controller,
    required this.sharingLocation,
    required this.onToggleSharing,
  });

  final AnimationController controller;
  final bool sharingLocation;
  final VoidCallback onToggleSharing;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          height: 330,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF10231F),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10231F).withValues(alpha: .2),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapMotionPainter(progress: controller.value),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                right: 18,
                child: Row(
                  children: [
                    _LivePill(active: sharingLocation),
                    const Spacer(),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .14),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onToggleSharing,
                      icon: Icon(
                        sharingLocation
                            ? Icons.location_on
                            : Icons.location_off,
                      ),
                      tooltip: 'Toggle location sharing',
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: _HeroInfoPanel(progress: controller.value),
              ),
              Positioned(
                right: 34,
                top: 86,
                child: _RiderPulse(progress: controller.value),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.sensors : Icons.pause_circle_outline,
            size: 16,
            color: const Color(0xFFE8FF72),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Live stream active' : 'Location paused',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroInfoPanel extends StatelessWidget {
  const _HeroInfoPanel({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Order #DM4821',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '12 min',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFE8FF72),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Anna Nagar pickup to T. Nagar delivery',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: .72),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: .58 + (math.sin(progress * math.pi * 2) + 1) * .05,
            minHeight: 5,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: Colors.white.withValues(alpha: .14),
            color: const Color(0xFFE8FF72),
          ),
        ],
      ),
    );
  }
}

class _TrackingStats extends StatelessWidget {
  const _TrackingStats();

  @override
  Widget build(BuildContext context) {
    final stats = [
      _TrackStat('ETA', '12m', Icons.timer_outlined, Color(0xFF173B33)),
      _TrackStat('Distance', '3.8 km', Icons.route_outlined, Color(0xFF2556A4)),
      _TrackStat('Speed', '28 km/h', Icons.speed, Color(0xFFC78417)),
    ];

    return Row(
      children: stats
          .map(
            (stat) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: stat == stats.last ? 0 : 10),
                child: _StatTile(stat: stat),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final _TrackStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2DED0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(stat.icon, color: stat.color, size: 20),
          Text(
            stat.value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF16231F),
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          Text(
            stat.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF66706B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentDeliveryCard extends StatelessWidget {
  const _CurrentDeliveryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2DED0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current delivery',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF16231F),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          const _AddressRow(
            icon: Icons.storefront_outlined,
            title: 'Pickup',
            address: 'DoorMart Hub, Anna Nagar West',
            color: Color(0xFF173B33),
          ),
          const SizedBox(height: 12),
          const _AddressRow(
            icon: Icons.home_outlined,
            title: 'Drop',
            address: '24, South Boag Road, T. Nagar',
            color: Color(0xFF2556A4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Navigate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.title,
    required this.address,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String address;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF66706B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF16231F),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline();

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TimelineStep('Order accepted', 'Location shared with dispatch', true),
      _TimelineStep('Pickup reached', 'Store handoff completed', true),
      _TimelineStep('On the way', 'Rider moving toward customer', true),
      _TimelineStep('Delivered', 'Awaiting customer confirmation', false),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2DED0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route timeline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF16231F),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...steps.map((step) => _TimelineRow(step: step)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step});

  final _TimelineStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: step.done
                  ? const Color(0xFF173B33)
                  : const Color(0xFFECE7D8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.done ? Icons.check : Icons.more_horiz,
              size: 15,
              color: step.done ? Colors.white : const Color(0xFF66706B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: Color(0xFF16231F),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF66706B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationStreamCard extends StatelessWidget {
  const _LocationStreamCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCFE1DC)),
      ),
      child: const Row(
        children: [
          Icon(Icons.sensors, color: Color(0xFF173B33)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Location updates are emitted to backend through Socket.IO every few seconds.',
              style: TextStyle(
                color: Color(0xFF173B33),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingActions extends StatelessWidget {
  const _TrackingActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.my_location,
            label: 'Recenter',
            color: const Color(0xFF173B33),
            onTap: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.report_outlined,
            label: 'Issue',
            color: const Color(0xFFC2410C),
            onTap: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.share_location,
            label: 'Share',
            color: const Color(0xFF2556A4),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiderPulse extends StatelessWidget {
  const _RiderPulse({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scale = .92 + (math.sin(progress * math.pi * 2) + 1) * .06;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE8FF72).withValues(alpha: .18),
          border: Border.all(
            color: const Color(0xFFE8FF72).withValues(alpha: .35),
          ),
        ),
        child: const Icon(
          Icons.delivery_dining,
          color: Color(0xFFE8FF72),
          size: 34,
        ),
      ),
    );
  }
}

class _MapMotionPainter extends CustomPainter {
  const _MapMotionPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: .07)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final activePaint = Paint()
      ..color = const Color(0xFFE8FF72).withValues(alpha: .7)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..strokeWidth = 1;

    final drift = math.sin(progress * math.pi * 2) * 12;
    for (var x = -20.0; x < size.width + 20; x += 42) {
      canvas.drawLine(
        Offset(x + drift, 0),
        Offset(x - 34, size.height),
        gridPaint,
      );
    }
    for (var y = 20.0; y < size.height; y += 42) {
      canvas.drawLine(
        Offset(0, y - drift),
        Offset(size.width, y + 18),
        gridPaint,
      );
    }

    final route = Path()
      ..moveTo(22, size.height - 92)
      ..cubicTo(
        size.width * .26,
        size.height - 180,
        size.width * .48,
        size.height - 120 + drift,
        size.width * .64,
        138,
      )
      ..cubicTo(
        size.width * .78,
        78,
        size.width * .88,
        112,
        size.width - 24,
        66,
      );

    canvas.drawPath(route, roadPaint);
    final metric = route.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * .72), activePaint);

    for (final point in [
      Offset(28, size.height - 94),
      Offset(size.width * .64, 138),
      Offset(size.width - 28, 68),
    ]) {
      canvas.drawCircle(point, 7, Paint()..color = const Color(0xFFE8FF72));
      canvas.drawCircle(
        point,
        18,
        Paint()..color = const Color(0xFFE8FF72).withValues(alpha: .12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapMotionPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _TrackStat {
  const _TrackStat(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _TimelineStep {
  const _TimelineStep(this.title, this.subtitle, this.done);

  final String title;
  final String subtitle;
  final bool done;
}

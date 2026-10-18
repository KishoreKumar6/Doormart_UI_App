import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../app_page.dart';

// ── Color tokens ──────────────────────────────────────────
const _p800 = Color(0xff3C3489);
const _p600 = Color(0xff534AB7);
const _p200 = Color(0xffAFA9EC);
const _p50 = Color(0xffEEEDFE);

const _c600 = Color(0xff993C1D);
const _c200 = Color(0xffF0997B);
const _c50 = Color(0xffFAECE7);

const _a600 = Color(0xff854F0B);
const _a50 = Color(0xffFAEEDA);

// ── Models ────────────────────────────────────────────────
enum EarningPeriod { today, week, month }

class _DayBar {
  final String day;
  final double earned;
  final double tip;
  const _DayBar(this.day, this.earned, this.tip);
}

class _Trip {
  final String from, to, time;
  final double km, amount, tip;
  final int minutes;
  final Color accent, iconBg;
  const _Trip({
    required this.from,
    required this.to,
    required this.time,
    required this.km,
    required this.amount,
    required this.minutes,
    this.tip = 0,
    required this.accent,
    required this.iconBg,
  });
}

class _Goal {
  final String label, display;
  final IconData icon;
  final Color iconBg, accent;
  final double current, target;
  const _Goal({
    required this.label,
    required this.display,
    required this.icon,
    required this.iconBg,
    required this.accent,
    required this.current,
    required this.target,
  });
}

class _Badge {
  final String name, sub;
  final IconData icon;
  final Color bg, fg;
  final bool locked;
  const _Badge({
    required this.name,
    required this.sub,
    required this.icon,
    required this.bg,
    required this.fg,
    this.locked = false,
  });
}

// ── Screen ────────────────────────────────────────────────
class DeliveryEarningsScreen extends StatefulWidget {
  const DeliveryEarningsScreen({super.key});
  static const routeName = '/delivery/earnings';

  @override
  State<DeliveryEarningsScreen> createState() => _DeliveryEarningsScreenState();
}

class _DeliveryEarningsScreenState extends State<DeliveryEarningsScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late AnimationController _counterCtrl;
  late AnimationController _progressCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _barCtrl;

  EarningPeriod _period = EarningPeriod.week;

  // ── Static data ───────────────────────────────────────
  static const _weekBars = [
    _DayBar('Mon', 1100, 80),
    _DayBar('Tue', 1450, 120),
    _DayBar('Wed', 980, 60),
    _DayBar('Thu', 1600, 200),
    _DayBar('Fri', 1800, 180),
    _DayBar('Sat', 1400, 90),
    _DayBar('Sun', 870, 70),
  ];

  static const _trips = [
    _Trip(
      from: 'Koramangala',
      to: 'HSR Layout',
      km: 4.2,
      minutes: 18,
      amount: 92,
      time: '2:34 PM',
      accent: _c600,
      iconBg: _c50,
    ),
    _Trip(
      from: 'Indiranagar',
      to: 'Whitefield',
      km: 11.7,
      minutes: 34,
      amount: 184,
      tip: 15,
      time: '12:10 PM',
      accent: _p600,
      iconBg: _p50,
    ),
    _Trip(
      from: 'MG Road',
      to: 'Jayanagar',
      km: 6.0,
      minutes: 22,
      amount: 118,
      time: '10:05 AM',
      accent: _a600,
      iconBg: _a50,
    ),
  ];

  static const _goals = [
    _Goal(
      label: '40 deliveries',
      display: '38 / 40',
      icon: Icons.delivery_dining,
      iconBg: _p50,
      accent: _p600,
      current: 38,
      target: 40,
    ),
    _Goal(
      label: 'Earn ₹9,000',
      display: 'Done',
      icon: Icons.currency_rupee,
      iconBg: _c50,
      accent: _c600,
      current: 9200,
      target: 9000,
    ),
    _Goal(
      label: 'Online 30 hrs',
      display: '21 / 30 h',
      icon: Icons.access_time,
      iconBg: _a50,
      accent: _a600,
      current: 21,
      target: 30,
    ),
  ];

  static const _badges = [
    _Badge(
      name: 'Top earner',
      sub: 'This week',
      icon: Icons.star_rounded,
      bg: _p50,
      fg: _p600,
    ),
    _Badge(
      name: 'Speed run',
      sub: '30+ orders',
      icon: Icons.bolt,
      bg: _c50,
      fg: _c600,
    ),
    _Badge(
      name: 'On a streak',
      sub: '7 days',
      icon: Icons.local_fire_department,
      bg: _a50,
      fg: _a600,
    ),
    _Badge(
      name: 'Night owl',
      sub: '10 night trips',
      icon: Icons.lock_outline,
      bg: Color(0xffF1EFE8),
      fg: Color(0xff888780),
      locked: true,
    ),
  ];

  // ── Period data ───────────────────────────────────────
  Map<String, dynamic> get _pd => {
    EarningPeriod.today: {
      'total': 1850.0,
      'sub': 'Today · 11 deliveries',
      'base': 1420.0,
      'incentive': 230.0,
      'tips': 200.0,
    },
    EarningPeriod.week: {
      'total': 9200.0,
      'sub': 'Oct 4–10 · 38 deliveries',
      'base': 7100.0,
      'incentive': 1400.0,
      'tips': 700.0,
    },
    EarningPeriod.month: {
      'total': 32400.0,
      'sub': 'October · 128 deliveries',
      'base': 25000.0,
      'incentive': 4800.0,
      'tips': 2600.0,
    },
  }[_period]!;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _counterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _entranceCtrl.forward();
      _counterCtrl.forward();
      _progressCtrl.forward();
      _barCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _counterCtrl.dispose();
    _progressCtrl.dispose();
    _pulseCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  // ── Animation helpers ─────────────────────────────────
  Widget _staggered({
    required Widget child,
    required double begin,
    required double end,
  }) => FadeTransition(
    opacity: Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    ),
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _entranceCtrl,
              curve: Interval(begin, end, curve: Curves.easeOutCubic),
            ),
          ),
      child: child,
    ),
  );

  Widget _counter({
    required double target,
    required TextStyle style,
    String pre = '₹',
  }) => AnimatedBuilder(
    animation: CurvedAnimation(
      parent: _counterCtrl,
      curve: Curves.easeOutCubic,
    ),
    builder: (_, __) =>
        Text('$pre${(target * _counterCtrl.value).toInt()}', style: style),
  );

  Widget _shimmer(double h) => AnimatedBuilder(
    animation: _pulseCtrl,
    builder: (_, __) => Container(
      height: h,
      decoration: BoxDecoration(
        color: Colors.grey.shade200.withOpacity(0.4 + _pulseCtrl.value * 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );

  // ── Period tabs ───────────────────────────────────────
  Widget _tabs() {
    final items = {
      EarningPeriod.today: 'Today',
      EarningPeriod.week: 'This week',
      EarningPeriod.month: 'Month',
    };
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: items.entries.map((e) {
          final on = _period == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _period = e.key);
                _counterCtrl
                  ..reset()
                  ..forward();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: on ? _p600 : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                    color: on ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────
  Widget _hero() {
    final d = _pd;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: _p50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL EARNED',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: _p600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _counter(
                target: d['total'],
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: _p800,
                  height: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, color: _p600, size: 13),
                    SizedBox(width: 4),
                    Text(
                      '+14%',
                      style: TextStyle(
                        fontSize: 11,
                        color: _p600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(d['sub'], style: const TextStyle(fontSize: 12, color: _p600)),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────
  Widget _stats() {
    final d = _pd;
    Widget card(String lbl, double amt, IconData ico, Color bg, Color fg) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: bg,
                  child: Icon(ico, color: fg, size: 14),
                ),
                const SizedBox(height: 7),
                _counter(
                  target: amt,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lbl,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
    return Row(
      children: [
        card('Base pay', d['base'], Icons.delivery_dining, _c50, _c600),
        const SizedBox(width: 8),
        card('Incentives', d['incentive'], Icons.bolt, _p50, _p600),
        const SizedBox(width: 8),
        card('Tips', d['tips'], Icons.currency_rupee, _a50, _a600),
      ],
    );
  }

  // ── Bar chart ─────────────────────────────────────────
  Widget _chart() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daily earnings',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                _dot(_p200, 'Earned'),
                const SizedBox(width: 10),
                _dot(_c200, 'Tips'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _weekBars
                .map(
                  (b) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: AnimatedBuilder(
                              animation: CurvedAnimation(
                                parent: _barCtrl,
                                curve: Curves.easeOutCubic,
                              ),
                              builder: (_, __) => Container(
                                height: (b.earned / 1800) * 80 * _barCtrl.value,
                                decoration: const BoxDecoration(
                                  color: _p200,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          SizedBox(
                            width: 5,
                            child: AnimatedBuilder(
                              animation: CurvedAnimation(
                                parent: _barCtrl,
                                curve: Curves.easeOutCubic,
                              ),
                              builder: (_, __) => Container(
                                height: (b.tip / 200) * 28 * _barCtrl.value,
                                decoration: const BoxDecoration(
                                  color: _c200,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: _weekBars
              .map(
                (b) => Expanded(
                  child: Text(
                    b.day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );

  Widget _dot(Color c, String lbl) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(lbl, style: const TextStyle(fontSize: 11, color: Colors.black45)),
    ],
  );

  // ── Payout card ───────────────────────────────────────
  Widget _payoutCard(double pending) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pending payout',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black45,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _p50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '75% ready',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _p600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _counter(
              target: pending,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: _p800,
              ),
            ),
            const Spacer(),
            const Text(
              'Est. 2 days',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AnimatedBuilder(
            animation: CurvedAnimation(
              parent: _progressCtrl,
              curve: Curves.easeOutCubic,
            ),
            builder: (_, __) => LinearProgressIndicator(
              value: 0.75 * _progressCtrl.value,
              minHeight: 6,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation(_p200),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '₹0',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              '₹${pending.toInt()}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, child) => Transform.scale(
            scale: 1.0 + (_pulseCtrl.value * 0.01),
            child: child,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.wallet, color: Colors.white, size: 18),
              label: const Text(
                'Cash out now',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _p600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Trips ─────────────────────────────────────────────
  Widget _tripsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Today's trips",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'View all',
              style: TextStyle(
                fontSize: 12,
                color: _p600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ..._trips.map(_tripRow),
    ],
  );

  Widget _tripRow(_Trip t) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: t.iconBg,
          child: Icon(Icons.location_on_outlined, color: t.accent, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t.from} → ${t.to}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${t.km} km · ${t.minutes} min'
                '${t.tip > 0 ? " · +₹${t.tip.toInt()} tip" : ""}',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${t.amount.toInt()}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.accent,
              ),
            ),
            Text(
              t.time,
              style: const TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ],
        ),
      ],
    ),
  );

  // ── Goals ─────────────────────────────────────────────
  Widget _goalsCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade100),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Weekly goals',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _c50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '2 of 3 done',
                style: TextStyle(
                  fontSize: 11,
                  color: _c600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ..._goals.map((g) {
          final pct = (g.current / g.target).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: g.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(g.icon, color: g.accent, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedBuilder(
                          animation: CurvedAnimation(
                            parent: _progressCtrl,
                            curve: Curves.easeOutCubic,
                          ),
                          builder: (_, __) => LinearProgressIndicator(
                            value: pct * _progressCtrl.value,
                            minHeight: 4,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation(g.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  g.display,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: g.accent,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );

  // ── Badges ────────────────────────────────────────────
  Widget _badgesSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Badges',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.6,
        ),
        itemCount: _badges.length,
        itemBuilder: (_, i) {
          final b = _badges[i];
          return Opacity(
            opacity: b.locked ? 0.4 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: b.bg,
                    child: Icon(b.icon, color: b.fg, size: 15),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          b.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          b.sub,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );

  // ── Tip banner ────────────────────────────────────────
  Widget _tip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _p50,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.lightbulb_outline, color: _p600, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 12, color: _p800, height: 1.5),
              children: [
                TextSpan(
                  text: 'Peak hours today: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text:
                      '12–2 PM and 7–9 PM. '
                      'Go online then for 1.4× surge pay.',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Earnings',
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: context.read<AppState>().deliveryEarnings(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _shimmer(130),
                    const SizedBox(height: 12),
                    _shimmer(80),
                    const SizedBox(height: 12),
                    _shimmer(110),
                    const SizedBox(height: 12),
                    _shimmer(160),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            final pending =
                (data['pendingPayout'] as num?)?.toDouble() ?? 12600;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _staggered(begin: 0.0, end: 0.30, child: _tabs()),
                const SizedBox(height: 12),
                _staggered(begin: 0.05, end: 0.40, child: _hero()),
                const SizedBox(height: 12),
                _staggered(begin: 0.15, end: 0.50, child: _stats()),
                const SizedBox(height: 12),
                _staggered(begin: 0.22, end: 0.58, child: _chart()),
                const SizedBox(height: 12),
                _staggered(begin: 0.30, end: 0.65, child: _payoutCard(pending)),
                const SizedBox(height: 20),
                _staggered(begin: 0.38, end: 0.72, child: _tripsSection()),
                const SizedBox(height: 20),
                _staggered(begin: 0.45, end: 0.78, child: _goalsCard()),
                const SizedBox(height: 20),
                _staggered(begin: 0.52, end: 0.85, child: _badgesSection()),
                const SizedBox(height: 16),
                _staggered(begin: 0.60, end: 1.00, child: _tip()),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ],
    );
  }
}

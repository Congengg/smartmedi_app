import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartmedi_app/screens/profile_page.dart';
import '../../widgets/common/blob_painter.dart';

// ─── Blob preset for home page ────────────────────────────────────────────────
class _HomeBlobs {
  static const blobs = [
    BlobConfig(
      color: Color(0x1A00D4AA),
      x: 0.80,
      y: 0.05,
      radius: 0.45,
      dx: 0.06,
      dy: 0.05,
      speedX: 0.8,
      speedY: 0.7,
    ),
    BlobConfig(
      color: Color(0x145B6EF5),
      x: 0.10,
      y: 0.30,
      radius: 0.38,
      dx: 0.05,
      dy: 0.06,
      speedX: 0.9,
      speedY: 1.0,
    ),
    BlobConfig(
      color: Color(0x0DE040A0),
      x: 0.50,
      y: 0.75,
      radius: 0.32,
      dx: 0.04,
      dy: 0.04,
      speedX: 1.1,
      speedY: 0.8,
    ),
  ];
}

// ─── Quick action model ───────────────────────────────────────────────────────
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ─── Health tip model ─────────────────────────────────────────────────────────
class _HealthTip {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  const _HealthTip({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });
}

// ─── Patient Home Page ────────────────────────────────────────────────────────
class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobCtrl;

  // User data from Firestore
  String _name = '';
  String _greeting = '';
  bool _loadingUser = true;

  // Static health tips
  final List<_HealthTip> _tips = const [
    _HealthTip(
      title: 'Stay hydrated',
      body:
          'Drink at least 8 glasses of water a day to keep your body functioning well.',
      icon: Icons.water_drop_outlined,
      color: Color(0xFF378ADD),
    ),
    _HealthTip(
      title: 'Move every hour',
      body:
          'Short walks between sitting sessions improve circulation and reduce fatigue.',
      icon: Icons.directions_walk_rounded,
      color: Color(0xFF00D4AA),
    ),
    _HealthTip(
      title: 'Sleep 7–9 hours',
      body:
          'Quality sleep boosts immunity and helps your body recover from daily stress.',
      icon: Icons.bedtime_outlined,
      color: Color(0xFF7F77DD),
    ),
  ];

  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _greeting = _buildGreeting();
    _loadUser();
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    super.dispose();
  }

  String _buildGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (mounted) {
        setState(() {
          _name = doc.data()?['name'] ?? '';
          _loadingUser = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  // ─── Quick actions ──────────────────────────────────────────────────────────
  List<_QuickAction> get _quickActions => [
    _QuickAction(
      icon: Icons.search_rounded,
      label: 'Find Doctor',
      color: const Color(0xFF00D4AA),
      onTap: () {}, // TODO: navigate to FindDoctorPage
    ),
    _QuickAction(
      icon: Icons.psychology_outlined,
      label: 'AI Checker',
      color: const Color(0xFF7F77DD),
      onTap: () {}, // TODO: navigate to SymptomCheckerPage
    ),
    _QuickAction(
      icon: Icons.calendar_month_rounded,
      label: 'Book Appt',
      color: const Color(0xFF378ADD),
      onTap: () {}, // TODO: navigate to BookAppointmentPage
    ),
    _QuickAction(
      icon: Icons.folder_open_rounded,
      label: 'Records',
      color: const Color(0xFFD85A30),
      onTap: () {}, // TODO: navigate to MedicalRecordsPage
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: AnimatedBuilder(
        animation: _blobCtrl,
        builder: (context, _) {
          return Stack(
            children: [
              // ── Animated background ────────────────────────────────────
              CustomPaint(
                painter: BlobPainter(
                  _blobCtrl.value * 2 * math.pi,
                  blobs: _HomeBlobs.blobs,
                ),
                size: MediaQuery.of(context).size,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0A0E1A).withValues(alpha: 0.50),
                      const Color(0xFF0A0E1A).withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────────
              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopBar()),
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildQuickActions()),
                    SliverToBoxAdapter(child: _buildUpcomingAppointment()),
                    SliverToBoxAdapter(child: _buildHealthTip()),
                    SliverToBoxAdapter(child: _buildRecentActivity()),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // ── Bottom navigation bar ──────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          // SmartMedi logo mark
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'SmartMedi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          // Notification bell
          _iconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () {}, // TODO: navigate to NotificationsPage
            badge: true,
          ),
          const SizedBox(width: 10),
          // Profile avatar
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ), // TODO: navigate to ProfilePage
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF00D4AA).withValues(alpha: 0.20),
              child: Text(
                _name.isNotEmpty ? _name[0].toUpperCase() : 'P',
                style: const TextStyle(
                  color: Color(0xFF00D4AA),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (badge)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B8A),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Header / greeting ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_greeting,',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          _loadingUser
              ? Container(
                  width: 160,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              : Text(
                  _name.isNotEmpty ? _name.split(' ').first : 'Patient',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
          const SizedBox(height: 12),
          // Health status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4AA).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00D4AA),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'Health status: Good',
                  style: TextStyle(
                    color: Color(0xFF00D4AA),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick actions grid ────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: _quickActions
                .map(
                  (a) => Expanded(
                    child: GestureDetector(
                      onTap: a.onTap,
                      child: _QuickActionTile(action: a),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── Upcoming appointment card ─────────────────────────────────────────────
  Widget _buildUpcomingAppointment() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Upcoming appointment',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {}, // TODO: navigate to AppointmentsPage
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: Color(0xFF00D4AA),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // TODO: Replace with StreamBuilder from Firestore
          _buildAppointmentCard(
            doctorName: 'Dr. Sarah Lim',
            specialty: 'General Practitioner',
            date: 'Today',
            time: '3:00 PM',
            type: 'In-person',
            avatarLetter: 'S',
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard({
    required String doctorName,
    required String specialty,
    required String date,
    required String time,
    required String type,
    required String avatarLetter,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00D4AA).withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Doctor avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(
                  0xFF378ADD,
                ).withValues(alpha: 0.20),
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                    color: Color(0xFF378ADD),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00D4AA).withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    color: Color(0xFF00D4AA),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _apptDetail(icon: Icons.calendar_today_rounded, label: date),
              const SizedBox(width: 20),
              _apptDetail(icon: Icons.access_time_rounded, label: time),
              const Spacer(),
              // Reschedule button
              GestureDetector(
                onTap: () {}, // TODO: reschedule
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Reschedule',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _apptDetail({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00D4AA), size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── Health tip card ───────────────────────────────────────────────────────
  Widget _buildHealthTip() {
    final tip = _tips[_tipIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health tip',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () =>
                setState(() => _tipIndex = (_tipIndex + 1) % _tips.length),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Container(
                key: ValueKey(_tipIndex),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: tip.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: tip.color.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tip.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tip.icon, color: tip.color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.title,
                            style: TextStyle(
                              color: tip.color,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            tip.body,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Dot indicators
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _tips.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _tipIndex ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _tipIndex
                      ? const Color(0xFF00D4AA)
                      : Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Recent activity ───────────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    // TODO: Replace with StreamBuilder from Firestore
    final items = [
      _ActivityItem(
        icon: Icons.psychology_outlined,
        color: const Color(0xFF7F77DD),
        title: 'Symptom check completed',
        subtitle: 'Urgency: Low — Suggested: GP',
        time: '2h ago',
      ),
      _ActivityItem(
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF00D4AA),
        title: 'Appointment confirmed',
        subtitle: 'Dr. Sarah Lim — Today 3:00 PM',
        time: 'Yesterday',
      ),
      _ActivityItem(
        icon: Icons.folder_open_rounded,
        color: const Color(0xFFD85A30),
        title: 'Medical record uploaded',
        subtitle: 'Blood test results — Jan 2025',
        time: '3 days ago',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent activity',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: Color(0xFF00D4AA),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Column(
              children: items
                  .asMap()
                  .entries
                  .map(
                    (e) => Column(
                      children: [
                        _buildActivityRow(e.value),
                        if (e.key < items.length - 1)
                          Divider(
                            color: Colors.white.withValues(alpha: 0.06),
                            height: 1,
                            indent: 60,
                          ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(_ActivityItem item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.time,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom navigation bar ─────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: true,
                onTap: () {},
              ),
              _navItem(
                icon: Icons.search_rounded,
                label: 'Doctors',
                onTap: () {}, // TODO: navigate to FindDoctorPage
              ),
              _navItem(
                icon: Icons.psychology_outlined,
                label: 'Symptom',
                onTap: () {}, // TODO: navigate to SymptomCheckerPage
              ),
              _navItem(
                icon: Icons.folder_open_rounded,
                label: 'Records',
                onTap: () {}, // TODO: navigate to MedicalRecordsPage
              ),
              _navItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                onTap: () {}, // TODO: navigate to ProfilePage
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    bool active = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00D4AA).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active
                  ? const Color(0xFF00D4AA)
                  : Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? const Color(0xFF00D4AA)
                    : Colors.white.withValues(alpha: 0.35),
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick action tile widget ─────────────────────────────────────────────────
class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: action.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: action.color.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, color: action.color, size: 24),
          const SizedBox(height: 7),
          Text(
            action.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: action.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Activity item model ──────────────────────────────────────────────────────
class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}

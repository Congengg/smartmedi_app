import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartmedi_app/screens/book_appointment.dart';
import 'package:smartmedi_app/screens/reschedule_appointment.dart';
import 'package:smartmedi_app/widgets/common/blob_painter.dart';

// ─── Blob preset ──────────────────────────────────────────────────────────────
class _ApptBlobs {
  static const blobs = [
    BlobConfig(
      color: Color(0x1600D4AA),
      x: 0.85,
      y: 0.06,
      radius: 0.40,
      dx: 0.05,
      dy: 0.04,
      speedX: 0.8,
      speedY: 0.7,
    ),
    BlobConfig(
      color: Color(0x125B6EF5),
      x: 0.08,
      y: 0.45,
      radius: 0.36,
      dx: 0.05,
      dy: 0.05,
      speedX: 0.9,
      speedY: 1.0,
    ),
    BlobConfig(
      color: Color(0x0DE040A0),
      x: 0.50,
      y: 0.82,
      radius: 0.30,
      dx: 0.04,
      dy: 0.04,
      speedX: 1.1,
      speedY: 0.8,
    ),
  ];
}

// ─── Status config map ────────────────────────────────────────────────────────
class _StatusConfig {
  final Color color;
  final Color bgColor;
  final IconData icon;
  final String label;
  const _StatusConfig({
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.label,
  });
}

const Map<String, _StatusConfig> _statusConfigs = {
  'confirmed': _StatusConfig(
    color: Color(0xFF00D4AA),
    bgColor: Color(0x1A00D4AA),
    icon: Icons.check_circle_outline_rounded,
    label: 'Confirmed',
  ),
  'pending': _StatusConfig(
    color: Color(0xFFEF9F27),
    bgColor: Color(0x1AEF9F27),
    icon: Icons.schedule_rounded,
    label: 'Pending',
  ),
  'completed': _StatusConfig(
    color: Color(0xFF5B6EF5),
    bgColor: Color(0x1A5B6EF5),
    icon: Icons.task_alt_rounded,
    label: 'Completed',
  ),
  'cancelled': _StatusConfig(
    color: Color(0xFFFF6B8A),
    bgColor: Color(0x1AFF6B8A),
    icon: Icons.cancel_outlined,
    label: 'Cancelled',
  ),
};

enum _ApptTab { upcoming, completed, cancelled }

// ─── Appointments Page ────────────────────────────────────────────────────────
class AppointmentsPage extends StatefulWidget {
  // ✅ Optional params — used when navigating from FindDoctorPage
  final String preselectedDoctor;
  final String preselectedSpecialty;
  final DateTime? preselectedDateTime;

  const AppointmentsPage({
    super.key,
    this.preselectedDoctor = '',
    this.preselectedSpecialty = '', 
    this.preselectedDateTime, 
  });

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobCtrl;
  _ApptTab _activeTab = _ApptTab.upcoming;

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    super.dispose();
  }

  // ─── Status filter per tab ────────────────────────────────────────────────
  List<String> get _statusFilter {
    switch (_activeTab) {
      case _ApptTab.upcoming:
        return ['confirmed', 'pending'];
      case _ApptTab.completed:
        return ['completed'];
      case _ApptTab.cancelled:
        return ['cancelled'];
    }
    
  }

  

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF0A0E1A),
    body: Stack(
      children: [
        // ✅ AnimatedBuilder ONLY wraps the blob painter
        AnimatedBuilder(
          animation: _blobCtrl,
          builder: (context, _) {
            return CustomPaint(
              painter: BlobPainter(
                _blobCtrl.value * 2 * math.pi,
                blobs: _ApptBlobs.blobs,
              ),
              size: MediaQuery.of(context).size,
            );
          },
        ),

        // Gradient overlay (static, no animation needed)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0A0E1A).withValues(alpha: 0.50),
                const Color(0xFF0A0E1A).withValues(alpha: 0.96),
              ],
            ),
          ),
        ),

        // ✅ SafeArea is OUTSIDE AnimatedBuilder — never recreated
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildTabBar(),
              Expanded(child: _buildAppointmentList()),
            ],
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookAppointmentPage(
          preselectedDoctor: widget.preselectedDoctor,
          preselectedSpecialty: widget.preselectedSpecialty,
        ),
      ),
    );
  },
  backgroundColor: const Color(0xFF00D4AA),
  elevation: 0,
  icon: const Icon(Icons.add_rounded, color: Colors.white),
  label: const Text(
    'Book Appointment',
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  ),
),
  );
}

  // ─── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'My Appointments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab bar ──────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      (_ApptTab.upcoming, 'Upcoming'),
      (_ApptTab.completed, 'Completed'),
      (_ApptTab.cancelled, 'Cancelled'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: tabs.map((t) {
            final isActive = _activeTab == t.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF00D4AA)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      t.$2,
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.40),
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Appointment list with StreamBuilder ─────────────────────────────────
  Widget _buildAppointmentList() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Center(
      child: Text(
        'Please log in',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.50)),
      ),
    );
  }

  // ✅ Declared here so it re-evaluates _statusFilter on every setState
  final stream = FirebaseFirestore.instance
      .collection('appointments')
      .where('patientId', isEqualTo: uid)
      .where('status', whereIn: _statusFilter)
      .snapshots();

  return StreamBuilder<QuerySnapshot>(
    key: ValueKey(_activeTab),   // ✅ forces new StreamBuilder per tab
    stream: stream,              // ✅ uses freshly computed stream
    builder: (context, snapshot) {
        // debugPrint('STATE: ${snapshot.connectionState}');
        // debugPrint('ERROR: ${snapshot.error}');
        // debugPrint('DOCS: ${snapshot.data?.docs.length}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00D4AA),
              strokeWidth: 2.5,
            ),
          );
        }

        if (snapshot.hasError) {
          // debugPrint('🔴 Firestore error: ${snapshot.error}');
          return _buildEmptyState(
            icon: Icons.error_outline_rounded,
            color: const Color(0xFFFF6B8A),
            title: 'Something went wrong',
            subtitle: snapshot.error.toString(),
          );
        }

        // ✅ Fix #2 — client-side sort, no composite index needed
        final docs = List.from(snapshot.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs =
              (a.data() as Map<String, dynamic>)['dateTime'] as Timestamp?;
          final bTs =
              (b.data() as Map<String, dynamic>)['dateTime'] as Timestamp?;
          if (aTs == null || bTs == null) return 0;
          return _activeTab == _ApptTab.upcoming
              ? aTs.compareTo(bTs)
              : bTs.compareTo(aTs);
        });

        if (docs.isEmpty) {
          final Map<_ApptTab, Map<String, dynamic>> emptyConfig = {
            _ApptTab.upcoming: {
              'icon': Icons.calendar_today_rounded,
              'color': const Color(0xFF00D4AA),
              'title': 'No upcoming appointments',
              'subtitle': 'Tap "Book Appointment" below\nto schedule a visit.',
            },
            _ApptTab.completed: {
              'icon': Icons.task_alt_rounded,
              'color': const Color(0xFF5B6EF5),
              'title': 'No completed appointments',
              'subtitle': 'Your completed appointments\nwill appear here.',
            },
            _ApptTab.cancelled: {
              'icon': Icons.cancel_outlined,
              'color': const Color(0xFFFF6B8A),
              'title': 'No cancelled appointments',
              'subtitle': 'Your cancelled appointments\nwill appear here.',
            },
          };
          final cfg = emptyConfig[_activeTab]!;
          return _buildEmptyState(
            icon: cfg['icon'] as IconData,
            color: cfg['color'] as Color,
            title: cfg['title'] as String,
            subtitle: cfg['subtitle'] as String,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            return _AppointmentCard(
              appointmentId: docs[i].id,
              data: docs[i].data() as Map<String, dynamic>,
            );
          },
        );
      },
    );
  }

  // ─── Empty state widget ───────────────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.28),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 13.5,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Appointment Card ─────────────────────────────────────────────────────────
class _AppointmentCard extends StatelessWidget {
  final String appointmentId;
  final Map<String, dynamic> data;

  const _AppointmentCard({required this.appointmentId, required this.data});

  // ─── Format date ──────────────────────────────────────────────────────────
  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    final dt = (ts as Timestamp).toDate();
    final now = DateTime.now();
    final diff = DateTime(
      dt.year,
      dt.month,
      dt.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // ─── Format time ──────────────────────────────────────────────────────────
  String _formatTime(dynamic ts) {
    if (ts == null) return '—';
    final dt = (ts as Timestamp).toDate();
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = h >= 12 ? 'PM' : 'AM';
    final hr = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hr:$m $p';
  }

  // ─── Cancel with confirmation dialog ─────────────────────────────────────
  Future<void> _showCancelDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF141828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B8A).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: Color(0xFFFF6B8A),
                  size: 26,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Cancel appointment?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Keep it',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B8A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel it',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({'status': 'cancelled'});
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to cancel. Please try again.'),
            backgroundColor: const Color(0xFFFF6B8A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final doctorName = data['doctorName'] as String? ?? 'Doctor';
    final specialty = data['specialty'] as String? ?? '';
    final type = data['type'] as String? ?? 'In-person';
    final notes = data['notes'] as String? ?? '';
    final dateTs = data['dateTime'];
    final config = _statusConfigs[status] ?? _statusConfigs['pending']!;
    final isUpcoming = status == 'confirmed' || status == 'pending';
    final initial = doctorName.replaceFirst('Dr. ', '').trim();
    final avatarLetter = initial.isNotEmpty ? initial[0].toUpperCase() : 'D';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: config.color.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          // ── Card header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    // Doctor avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(
                        0xFF378ADD,
                      ).withValues(alpha: 0.18),
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
                          if (specialty.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              specialty,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: config.bgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: config.color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(config.icon, color: config.color, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            config.label,
                            style: TextStyle(
                              color: config.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Date / time / type ───────────────────────────────────
                const SizedBox(height: 14),
                Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _detail(Icons.calendar_today_rounded, _formatDate(dateTs)),
                    const SizedBox(width: 16),
                    _detail(Icons.access_time_rounded, _formatTime(dateTs)),
                    const SizedBox(width: 16),
                    _detail(Icons.location_on_outlined, type),
                  ],
                ),

                // ── Notes ────────────────────────────────────────────────
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          color: Colors.white.withValues(alpha: 0.35),
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notes,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Action buttons (upcoming only) ───────────────────────────────
          if (isUpcoming) ...[
            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RescheduleAppointmentPage(
                              appointmentId: appointmentId,
                              data: data,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_calendar_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Reschedule',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showCancelDialog(context),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF6B8A,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(
                              0xFFFF6B8A,
                            ).withValues(alpha: 0.30),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              color: Color(0xFFFF6B8A),
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Cancel',
                              style: TextStyle(
                                color: Color(0xFFFF6B8A),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label) {
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
}

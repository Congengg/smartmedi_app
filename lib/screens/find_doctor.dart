import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartmedi_app/screens/book_appointment.dart';
import '../../widgets/common/blob_painter.dart';

// ─── Blob preset ──────────────────────────────────────────────────────────────
class _FindDoctorBlobs {
  static const blobs = [
    BlobConfig(
      color: Color(0x1400D4AA),
      x: 0.85,
      y: 0.08,
      radius: 0.40,
      dx: 0.06,
      dy: 0.05,
      speedX: 0.8,
      speedY: 0.9,
    ),
    BlobConfig(
      color: Color(0x115B6EF5),
      x: 0.10,
      y: 0.45,
      radius: 0.36,
      dx: 0.06,
      dy: 0.06,
      speedX: 1.0,
      speedY: 0.8,
    ),
    BlobConfig(
      color: Color(0x0BE040A0),
      x: 0.55,
      y: 0.85,
      radius: 0.30,
      dx: 0.04,
      dy: 0.04,
      speedX: 1.2,
      speedY: 0.7,
    ),
  ];
}

// ─── Specialty list ───────────────────────────────────────────────────────────
const _specialties = [
  'All',
  'General',
  'Cardiology',
  'Dermatology',
  'Neurology',
  'Pediatrics',
  'Orthopedics',
  'Psychiatry',
  'Gynecology',
  'ENT',
  'Dentistry',
];

// ─── Time slot model ──────────────────────────────────────────────────────────
class _TimeSlot {
  final int hour; // 9 = 9:00 AM, 14 = 2:00 PM etc.
  final bool booked;

  const _TimeSlot({required this.hour, required this.booked});

  String get label {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$h:00 $period';
  }

  String get endLabel {
    final nextHour = hour + 1;
    final h = nextHour > 12 ? nextHour - 12 : (nextHour == 0 ? 12 : nextHour);
    final period = nextHour >= 12 ? 'PM' : 'AM';
    return '$h:00 $period';
  }

  DateTime toDateTime(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour);
}

// Working hours: 9 AM to 5 PM (8 slots)
const _workingHours = [9, 10, 11, 12, 13, 14, 15, 16];

// ─── Doctor model ─────────────────────────────────────────────────────────────
class _Doctor {
  final String uid;
  final String name;
  final String specialty;
  final String photoUrl;
  final String email;
  final String phone;
  final String location;
  final String qualification;
  final double rating;
  final int reviewCount;
  final bool available;

  const _Doctor({
    required this.uid,
    required this.name,
    required this.specialty,
    required this.photoUrl,
    required this.email,
    required this.phone,
    required this.location,
    required this.qualification,
    required this.rating,
    required this.reviewCount,
    required this.available,
  });
}

// ─── Find Doctor Page ─────────────────────────────────────────────────────────
class FindDoctorPage extends StatefulWidget {
  const FindDoctorPage({super.key});

  @override
  State<FindDoctorPage> createState() => _FindDoctorPageState();
}

class _FindDoctorPageState extends State<FindDoctorPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobCtrl;
  final _searchCtrl = TextEditingController();

  Future<List<_Doctor>>? _doctorsFuture;

  String _selectedSpecialty = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _doctorsFuture = _fetchDoctors();
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<_Doctor>> _fetchDoctors() async {
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .get();

    if (usersSnap.docs.isEmpty) return [];

    final doctorsSnap = await FirebaseFirestore.instance
        .collection('doctors')
        .get();

    final Map<String, Map<String, dynamic>> profileByUserId = {};
    for (final doc in doctorsSnap.docs) {
      final data = doc.data();
      final userId = data['userId'] as String?;
      if (userId != null) {
        profileByUserId[userId] = {'_docId': doc.id, ...data};
      }
    }

    final List<_Doctor> result = [];
    for (final userDoc in usersSnap.docs) {
      final u = userDoc.data();
      final p = profileByUserId[userDoc.id] ?? {};

      result.add(
        _Doctor(
          uid: userDoc.id,
          name: (u['name'] ?? 'Doctor').toString(),
          email: (u['email'] ?? '').toString(),
          phone: (u['phone'] ?? '').toString(),
          photoUrl: (u['photoUrl'] ?? p['photoUrl'] ?? '').toString(),
          specialty: (p['specialty'] ?? u['specialty'] ?? 'General').toString(),
          location: (p['location'] ?? '').toString(),
          qualification: (p['qualification'] ?? '').toString(),
          rating: (p['rating'] as num?)?.toDouble() ?? 0.0,
          reviewCount: (p['reviewCount'] as num?)?.toInt() ?? 0,
          available: (p['available'] as bool?) ?? true,
        ),
      );
    }

    result.sort((a, b) {
      if (a.available != b.available) return a.available ? -1 : 1;
      return b.rating.compareTo(a.rating);
    });

    return result;
  }

  List<_Doctor> _applyFilters(List<_Doctor> doctors) {
    return doctors.where((doc) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          doc.name.toLowerCase().contains(q) ||
          doc.specialty.toLowerCase().contains(q) ||
          doc.location.toLowerCase().contains(q);
      final matchesSpecialty =
          _selectedSpecialty == 'All' ||
          doc.specialty.toLowerCase() == _selectedSpecialty.toLowerCase();
      return matchesSearch && matchesSpecialty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: AnimatedBuilder(
        animation: _blobCtrl,
        builder: (context, _) {
          return Stack(
            children: [
              CustomPaint(
                painter: BlobPainter(
                  _blobCtrl.value * 2 * math.pi,
                  blobs: _FindDoctorBlobs.blobs,
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
                      const Color(0xFF0A0E1A).withValues(alpha: 0.96),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    _buildSearchBar(),
                    _buildSpecialtyChips(),
                    const SizedBox(height: 8),
                    Expanded(child: _buildDoctorList()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

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
            'Find a Doctor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1.2,
          ),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14.5),
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search by name, specialty or location…',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF00D4AA),
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.40),
                      size: 18,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialtyChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: _specialties.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = _specialties[i];
            final active = _selectedSpecialty == s;
            return GestureDetector(
              onTap: () => setState(() => _selectedSpecialty = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF00D4AA)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF00D4AA)
                        : Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDoctorList() {
    return FutureBuilder<List<_Doctor>>(
      future: _doctorsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingList();
        }
        if (snapshot.hasError) {
          return _buildMessage('Could not load doctors.\n${snapshot.error}');
        }

        final filtered = _applyFilters(snapshot.data ?? []);

        if (filtered.isEmpty) {
          return _buildMessage(
            _searchQuery.isNotEmpty || _selectedSpecialty != 'All'
                ? 'No doctors found matching your search.'
                : 'No doctors available right now.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _DoctorCard(
            doctor: filtered[i],
            onTap: () => _showDoctorDetail(filtered[i]),
          ),
        );
      },
    );
  }

  void _showDoctorDetail(_Doctor doctor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _DoctorDetailSheet(
        doctor: doctor,
        onBookTap: (DateTime selectedDate, _TimeSlot selectedSlot) {
          final selectedDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedSlot.hour,
          );
          Navigator.pop(sheetCtx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookAppointmentPage(
                preselectedDoctor: doctor.name,
                preselectedSpecialty: doctor.specialty,
                preselectedDateTime: selectedDateTime,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 13,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ─── Doctor Card ─────────────────────────────────────────────────────────────
class _DoctorCard extends StatelessWidget {
  final _Doctor doctor;
  final VoidCallback onTap;

  const _DoctorCard({required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF378ADD).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: doctor.photoUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        doctor.photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _initial(doctor.name),
                      ),
                    )
                  : _initial(doctor.name),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor.specialty,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12.5,
                    ),
                  ),
                  if (doctor.location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          doctor.location,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.30),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFD166),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        doctor.rating > 0
                            ? doctor.rating.toStringAsFixed(1)
                            : 'New',
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (doctor.reviewCount > 0)
                        Text(
                          ' (${doctor.reviewCount})',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.30),
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: doctor.available
                        ? const Color(0xFF00D4AA).withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: doctor.available
                          ? const Color(0xFF00D4AA).withValues(alpha: 0.30)
                          : Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Text(
                    doctor.available ? 'Available' : 'Busy',
                    style: TextStyle(
                      color: doctor.available
                          ? const Color(0xFF00D4AA)
                          : Colors.white.withValues(alpha: 0.35),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.25),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _initial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'D',
        style: const TextStyle(
          color: Color(0xFF378ADD),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Doctor Detail Sheet with Time Slots ─────────────────────────────────────
class _DoctorDetailSheet extends StatefulWidget {
  final _Doctor doctor;
  final void Function(DateTime date, _TimeSlot slot) onBookTap;

  const _DoctorDetailSheet({required this.doctor, required this.onBookTap});

  @override
  State<_DoctorDetailSheet> createState() => _DoctorDetailSheetState();
}

class _DoctorDetailSheetState extends State<_DoctorDetailSheet> {
  DateTime _selectedDate = DateTime.now();
  _TimeSlot? _selectedSlot;
  List<_TimeSlot> _slots = [];
  bool _loadingSlots = false;

  @override
  void initState() {
    super.initState();
    _loadSlots(_selectedDate);
  }

  /// Fetch appointments for this doctor on the selected date,
  /// then mark each working-hour slot as booked or free.
  Future<void> _loadSlots(DateTime date) async {
    if (!mounted) return;
    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
    });

    final dayStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    try {
      // ✅ Query only by doctorId + dateTime range (2-field composite index)
      // Then filter status client-side to avoid a 3-field index requirement
      final snap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctor.uid)
          .where(
            'dateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
          )
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .get();

      // Collect booked hours — filter cancelled/completed client-side
      final bookedHours = <int>{};
      for (final doc in snap.docs) {
        final status = (doc.data()['status'] ?? '').toString();
        if (status == 'pending' || status == 'confirmed') {
          final ts = doc['dateTime'] as Timestamp?;
          if (ts != null) bookedHours.add(ts.toDate().hour);
        }
      }

      final now = DateTime.now();
      final isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      if (!mounted) return;
      setState(() {
        _slots = _workingHours.map((h) {
          // Past slots on today are also greyed out
          final isPast = isToday && h <= now.hour;
          return _TimeSlot(hour: h, booked: bookedHours.contains(h) || isPast);
        }).toList();
        _loadingSlots = false;
      });
    } catch (e) {
      debugPrint('_loadSlots error: $e');
      if (!mounted) return;
      // On error, show all slots as available so user is not blocked
      final now = DateTime.now();
      final isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      setState(() {
        _slots = _workingHours.map((h) {
          final isPast = isToday && h <= now.hour;
          return _TimeSlot(hour: h, booked: isPast);
        }).toList();
        _loadingSlots = false;
      });
    }
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadSlots(date);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141828),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            // drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Doctor info ─────────────────────────────────────────────────
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF378ADD).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: widget.doctor.photoUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          widget.doctor.photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _sheetInitial(),
                        ),
                      )
                    : _sheetInitial(),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                widget.doctor.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                widget.doctor.specialty,
                style: TextStyle(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.85),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (widget.doctor.qualification.isNotEmpty) ...[
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Text(
                    widget.doctor.qualification,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFD166),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.doctor.rating > 0
                        ? widget.doctor.rating.toStringAsFixed(1)
                        : 'New',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.doctor.reviewCount > 0)
                    Text(
                      '  ·  ${widget.doctor.reviewCount} reviews',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.doctor.location.isNotEmpty)
              _infoRow(Icons.location_on_outlined, widget.doctor.location),
            if (widget.doctor.email.isNotEmpty)
              _infoRow(Icons.email_outlined, widget.doctor.email),
            if (widget.doctor.phone.isNotEmpty)
              _infoRow(Icons.phone_outlined, widget.doctor.phone),

            const SizedBox(height: 24),
            Divider(color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 20),

            // ── Date picker ─────────────────────────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF00D4AA),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Select Date',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildDateStrip(),

            const SizedBox(height: 24),

            // ── Time slots ──────────────────────────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFF00D4AA),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Available Time Slots',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Legend
                Row(
                  children: [
                    _legend(const Color(0xFF00D4AA), 'Free'),
                    const SizedBox(width: 10),
                    _legend(Colors.white.withValues(alpha: 0.15), 'Booked'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _loadingSlots ? _buildSlotsLoading() : _buildSlotsGrid(),

            const SizedBox(height: 28),

            // ── Book button ─────────────────────────────────────────────────
            _buildBookButton(),
          ],
        ),
      ),
    );
  }

  // ── Book button ───────────────────────────────────────────────────────────
  Widget _buildBookButton() {
    final canBook = _selectedSlot != null && widget.doctor.available;
    final label = !widget.doctor.available
        ? 'Doctor Not Available'
        : _selectedSlot == null
        ? 'Select a time slot above'
        : 'Book ${_selectedSlot!.label} – ${_selectedSlot!.endLabel}';

    return GestureDetector(
      onTap: canBook
          ? () => widget.onBookTap(_selectedDate, _selectedSlot!)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: canBook
              ? const LinearGradient(
                  colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: canBook
              ? [
                  BoxShadow(
                    color: const Color(0xFF00D4AA).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              canBook ? Icons.calendar_month_rounded : Icons.touch_app_outlined,
              color: canBook
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: canBook
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date strip: today + next 6 days ───────────────────────────────────────
  Widget _buildDateStrip() {
    final now = DateTime.now();
    final dates = List.generate(7, (i) {
      final d = now.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });
    final selectedNorm = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final d = dates[i];
          final active = d == selectedNorm;
          final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final dayName = dayNames[d.weekday - 1];
          return GestureDetector(
            onTap: () => _selectDate(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF00D4AA)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active
                      ? const Color(0xFF00D4AA)
                      : Colors.white.withValues(alpha: 0.10),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      color: active
                          ? Colors.white.withValues(alpha: 0.80)
                          : Colors.white.withValues(alpha: 0.40),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.75),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Time slot grid ────────────────────────────────────────────────────────
  Widget _buildSlotsGrid() {
    if (_slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No slots available',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _slots.length,
      itemBuilder: (_, i) {
        final slot = _slots[i];
        final isSelected = _selectedSlot?.hour == slot.hour;

        Color bgColor;
        Color borderColor;
        Color textColor;

        if (slot.booked) {
          bgColor = Colors.white.withValues(alpha: 0.04);
          borderColor = Colors.white.withValues(alpha: 0.08);
          textColor = Colors.white.withValues(alpha: 0.20);
        } else if (isSelected) {
          bgColor = const Color(0xFF00D4AA);
          borderColor = const Color(0xFF00D4AA);
          textColor = Colors.white;
        } else {
          bgColor = const Color(0xFF00D4AA).withValues(alpha: 0.08);
          borderColor = const Color(0xFF00D4AA).withValues(alpha: 0.25);
          textColor = const Color(0xFF00D4AA);
        }

        return GestureDetector(
          onTap: slot.booked
              ? null
              : () => setState(() => _selectedSlot = isSelected ? null : slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot.label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (slot.booked)
                  Text(
                    'Booked',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.20),
                      fontSize: 9.5,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlotsLoading() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _sheetInitial() {
    return Center(
      child: Text(
        widget.doctor.name.isNotEmpty
            ? widget.doctor.name[0].toUpperCase()
            : 'D',
        style: const TextStyle(
          color: Color(0xFF378ADD),
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    final c = color ?? Colors.white.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: c, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: c, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

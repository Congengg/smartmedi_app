import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartmedi_app/screens/appointsment.dart';
import '../../widgets/common/blob_painter.dart';

// ─── Blob preset ──────────────────────────────────────────────────────────────
class _FindDoctorBlobs {
  static const blobs = [
    BlobConfig(
      color: Color(0x1400D4AA),
      x: 0.85, y: 0.08, radius: 0.40,
      dx: 0.06, dy: 0.05, speedX: 0.8, speedY: 0.9,
    ),
    BlobConfig(
      color: Color(0x115B6EF5),
      x: 0.10, y: 0.45, radius: 0.36,
      dx: 0.06, dy: 0.06, speedX: 1.0, speedY: 0.8,
    ),
    BlobConfig(
      color: Color(0x0BE040A0),
      x: 0.55, y: 0.85, radius: 0.30,
      dx: 0.04, dy: 0.04, speedX: 1.2, speedY: 0.7,
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

// ─── Doctor model (from Firestore) ───────────────────────────────────────────
class _Doctor {
  final String uid;
  final String name;
  final String specialty;
  final String photoUrl;
  final String email;
  final String phone;
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
    required this.rating,
    required this.reviewCount,
    required this.available,
  });

  factory _Doctor.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Doctor(
      uid: doc.id,
      name: (d['name'] ?? 'Doctor').toString(),
      specialty: (d['specialty'] ?? 'General').toString(),
      photoUrl: (d['photoUrl'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      phone: (d['phone'] ?? '').toString(),
      rating: (d['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (d['reviewCount'] as num?)?.toInt() ?? 0,
      available: (d['available'] as bool?) ?? true,
    );
  }
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

  String _selectedSpecialty = 'All';
  String _searchQuery = '';

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
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Doctor> _applyFilters(List<_Doctor> doctors) {
    return doctors.where((doc) {
      final matchesSearch = _searchQuery.isEmpty ||
          doc.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          doc.specialty.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesSpecialty = _selectedSpecialty == 'All' ||
          doc.specialty.toLowerCase().contains(_selectedSpecialty.toLowerCase());
      return matchesSearch && matchesSpecialty;
    }).toList();
  }

  Future<List<_Doctor>> _fetchDoctors() async {
  // Step 1: Get all users with role = doctor
  final usersSnap = await FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'doctor')
      .get();

  if (usersSnap.docs.isEmpty) return [];

  // Step 2: Get all doctor profile docs
  final doctorsSnap = await FirebaseFirestore.instance
      .collection('doctors')
      .get();

  // Build a map of userId → doctor profile data
  final Map<String, Map<String, dynamic>> doctorProfiles = {};
  for (final doc in doctorsSnap.docs) {
    final data = doc.data();
    final userId = data['userId'] as String?;
    if (userId != null) {
      doctorProfiles[userId] = data;
    }
  }

  // Step 3: Merge user + doctor profile into _Doctor model
  return usersSnap.docs.map((userDoc) {
    final userData    = userDoc.data();
    final profile     = doctorProfiles[userDoc.id] ?? {};

    return _Doctor(
      uid:         userDoc.id,
      name:        (userData['name']         ?? 'Doctor').toString(),
      email:       (userData['email']        ?? '').toString(),
      phone:       (userData['phone']        ?? '').toString(),
      photoUrl:    (userData['photoUrl']     ?? '').toString(),
      // These come from doctors collection
      specialty:   (profile['specialty']    ?? userData['specialty'] ?? 'General').toString(),
      rating:      (profile['rating']       as num?)?.toDouble() ?? 0.0,
      reviewCount: (profile['reviewCount']  as num?)?.toInt()    ?? 0,
      available:   (profile['available']    as bool?)            ?? true,
    );
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
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const Spacer(),
          const Text('Find a Doctor',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.w600, letterSpacing: -0.2)),
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
              color: Colors.white.withValues(alpha: 0.10), width: 1.2),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14.5),
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search by name or specialty…',
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.30), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Color(0xFF00D4AA), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.40), size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
                child: Text(s,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                    )),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDoctorList() {
  return FutureBuilder<List<_Doctor>>(
    future: _fetchDoctors(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingList();
      }
      if (snapshot.hasError) {
        return _buildMessage('Could not load doctors. Please try again.');
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
    builder: (sheetCtx) => _DoctorDetailSheet(       // ← sheetCtx not context
      doctor: doctor,
      onBookTap: () {
        Navigator.pop(sheetCtx);                      // ← close sheet with sheetCtx
        Navigator.push(
          context,                                    // ← navigate with page context
          MaterialPageRoute(
            builder: (_) => AppointmentsPage(
              preselectedDoctor: doctor.name,
              preselectedSpecialty: doctor.specialty,
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
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(height: 13, width: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Container(height: 11, width: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6))),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildMessage(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 14)),
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
              color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF378ADD).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: doctor.photoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(doctor.photoUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _initial(doctor.name)))
                : _initial(doctor.name),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doctor.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(doctor.specialty,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12.5)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFD166), size: 14),
                const SizedBox(width: 4),
                Text(
                  doctor.rating > 0 ? doctor.rating.toStringAsFixed(1) : 'New',
                  style: const TextStyle(color: Color(0xFFFFD166),
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (doctor.reviewCount > 0)
                  Text(' (${doctor.reviewCount})',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.30),
                          fontSize: 11.5)),
              ]),
            ],
          )),
          // Badge + chevron
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  fontSize: 10.5, fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.25), size: 20),
          ]),
        ]),
      ),
    );
  }

  Widget _initial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'D',
        style: const TextStyle(color: Color(0xFF378ADD),
            fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── Doctor Detail Bottom Sheet ───────────────────────────────────────────────
class _DoctorDetailSheet extends StatelessWidget {
  final _Doctor doctor;
  final VoidCallback onBookTap;

  const _DoctorDetailSheet({required this.doctor, required this.onBookTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141828),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF378ADD).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: doctor.photoUrl.isNotEmpty
                ? ClipOval(child: Image.network(doctor.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _sheetInitial()))
                : _sheetInitial(),
          ),
          const SizedBox(height: 14),
          Text(doctor.name,
              style: const TextStyle(color: Colors.white, fontSize: 19,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(doctor.specialty,
              style: TextStyle(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.85),
                  fontSize: 13.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFD166), size: 16),
            const SizedBox(width: 4),
            Text(
              doctor.rating > 0 ? doctor.rating.toStringAsFixed(1) : 'New',
              style: const TextStyle(color: Color(0xFFFFD166),
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (doctor.reviewCount > 0)
              Text('  ·  ${doctor.reviewCount} reviews',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12.5)),
          ]),
          const SizedBox(height: 24),
          if (doctor.email.isNotEmpty)
            _infoRow(Icons.email_outlined, doctor.email),
          if (doctor.phone.isNotEmpty)
            _infoRow(Icons.phone_outlined, doctor.phone),
          _infoRow(
            doctor.available
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            doctor.available
                ? 'Available for appointments'
                : 'Currently unavailable',
            color: doctor.available
                ? const Color(0xFF00D4AA)
                : const Color(0xFFFF6B8A),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.30),
                  blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: ElevatedButton.icon(
                onPressed: doctor.available ? onBookTap : null,
                icon: const Icon(Icons.calendar_month_rounded,
                    color: Colors.white, size: 18),
                label: Text(
                  doctor.available ? 'Book Appointment' : 'Not Available',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetInitial() {
    return Center(
      child: Text(
        doctor.name.isNotEmpty ? doctor.name[0].toUpperCase() : 'D',
        style: const TextStyle(color: Color(0xFF378ADD),
            fontSize: 28, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    final c = color ?? Colors.white.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: c, size: 17),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: c, fontSize: 13.5))),
      ]),
    );
  }
}
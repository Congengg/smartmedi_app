import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookAppointmentPage extends StatefulWidget {
  final String preselectedDoctor;
  final String preselectedSpecialty;
  final DateTime? preselectedDateTime;

  const BookAppointmentPage({
    super.key,
    this.preselectedDoctor = '',
    this.preselectedSpecialty = '',
    this.preselectedDateTime,
  });

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  final _notesController = TextEditingController();
  bool _isLoading = false;
  bool _isInitialLoading = true;

  // Data from Firestore
  String _patientName = '';
  List<Map<String, dynamic>> _doctors = [];

  // Form selections
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  String? _selectedSpecialty;
  String _type = 'In-person';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();

    // ✅ Auto-fill date and time if passed from FindDoctorPage
    if (widget.preselectedDateTime != null) {
      _selectedDate = widget.preselectedDateTime;
      _selectedTime = TimeOfDay(
        hour: widget.preselectedDateTime!.hour,
        minute: widget.preselectedDateTime!.minute,
      );
    }

    _loadRequiredData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ─── Load Patient and Doctor Data ────────────────────────────────────────
  Future<void> _loadRequiredData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Fetch current patient name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _patientName = userDoc.data()?['name'] ?? 'Anonymous Patient';

      // 2. Fetch all doctors
      final doctorSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .get();

      final List<Map<String, dynamic>> loadedDoctors = doctorSnap.docs
          .map(
            (doc) => {
              'id': doc.id, // This is the UID the React portal needs
              'name': (doc.data()['name'] ?? 'Unknown Doctor').toString(),
              'specialty': (doc.data()['specialty'] ?? 'General').toString(),
            },
          )
          .toList();

      setState(() {
        _doctors = loadedDoctors;

        // 3. Handle Navigation Logic (Preselection)
        if (widget.preselectedDoctor.isNotEmpty) {
          _selectedDoctorName = widget.preselectedDoctor;
          _selectedSpecialty = widget.preselectedSpecialty;

          // Find the ID for the preselected doctor
          try {
            final found = _doctors.firstWhere(
              (d) => d['name'] == widget.preselectedDoctor,
            );
            _selectedDoctorId = found['id'];
          } catch (_) {
            // If preselected doctor isn't in 'users' yet, add a temporary entry to prevent crash
            _selectedDoctorId = 'temp_id';
            _doctors.add({
              'id': 'temp_id',
              'name': _selectedDoctorName,
              'specialty': _selectedSpecialty,
            });
          }
        } else if (_doctors.isNotEmpty) {
          _selectedDoctorId = _doctors[0]['id'];
          _selectedDoctorName = _doctors[0]['name'];
          _selectedSpecialty = _doctors[0]['specialty'];
        }
        _isInitialLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
      setState(() => _isInitialLoading = false);
    }
  }

  // ─── Date & Time Pickers ──────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF00D4AA)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF00D4AA)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ─── Submit to Firestore ──────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedDoctorId == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      _showSnackBar('Please complete all fields.', const Color(0xFFEF9F27));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final dt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // SAVE DATA: This structure matches your React Portal requirements
      await FirebaseFirestore.instance.collection('appointments').add({
        'patientId': uid,
        'patientName': _patientName, // Required for React Portal list
        'doctorId': _selectedDoctorId, // Required for React Portal query
        'doctorName': _selectedDoctorName,
        'specialty': _selectedSpecialty,
        'type': _type,
        'notes': _notesController.text.trim(),
        'status': 'pending', // Starts as pending for Doctor to approve
        'dateTime': Timestamp.fromDate(dt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar('Appointment sent to Doctor! ✓', const Color(0xFF00D4AA));
      }
    } catch (e) {
      _showSnackBar('Failed: $e', const Color(0xFFFF6B8A));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Book Appointment',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isInitialLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4AA)),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: [
                _sectionLabel('Select Doctor'),
                _card(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDoctorId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF141828),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF00D4AA),
                      ),
                      items: _doctors.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['id'],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                d['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                d['specialty'],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        final doc = _doctors.firstWhere((d) => d['id'] == val);
                        setState(() {
                          _selectedDoctorId = val;
                          _selectedDoctorName = doc['name'];
                          _selectedSpecialty = doc['specialty'];
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionLabel('Date & Time'),
                Row(
                  children: [
                    Expanded(
                      child: _tappableCard(
                        icon: Icons.calendar_today,
                        label: _selectedDate == null
                            ? 'Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}',
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _tappableCard(
                        icon: Icons.access_time,
                        label: _selectedTime == null
                            ? 'Time'
                            : _selectedTime!.format(context),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionLabel('Visit Type'),
                Row(
                  children: ['In-person', 'Online'].map((t) {
                    final active = _type == t;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = t),
                        child: Container(
                          margin: EdgeInsets.only(
                            right: t == 'In-person' ? 10 : 0,
                          ),
                          height: 46,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFF00D4AA).withOpacity(0.1)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active
                                  ? const Color(0xFF00D4AA)
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              t,
                              style: TextStyle(
                                color: active
                                    ? const Color(0xFF00D4AA)
                                    : Colors.white.withOpacity(0.5),
                                fontWeight: active
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _sectionLabel('Notes (optional)'),
                _card(
                  child: TextField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Describe your symptoms...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4AA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Confirm Booking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: child,
  );
  Widget _tappableCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D4AA), size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    ),
  );
}

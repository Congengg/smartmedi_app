import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookAppointmentPage extends StatefulWidget {
  final String preselectedDoctor;
  final String preselectedSpecialty;

  const BookAppointmentPage({
    super.key,
    this.preselectedDoctor = '',
    this.preselectedSpecialty = '',
  });

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  final _notesController = TextEditingController();
  bool _isLoading = false;

  // Form values
  late String _doctorName;
  late String _specialty;
  String _type = 'In-person';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Hardcoded doctor list — replace with Firestore fetch if needed
  final List<Map<String, String>> _doctors = [
    {'name': 'Dr Ahmad',    'specialty': 'Cardiology'},
    {'name': 'Dr Sarah',    'specialty': 'Dermatology'},
    {'name': 'Dr Hassan',   'specialty': 'General'},
    {'name': 'Dr Lim',      'specialty': 'Orthopedics'},
  ];

  @override
  void initState() {
    super.initState();
    _doctorName = widget.preselectedDoctor.isNotEmpty
        ? widget.preselectedDoctor
        : _doctors[0]['name']!;
    _specialty = widget.preselectedSpecialty.isNotEmpty
        ? widget.preselectedSpecialty
        : _doctors[0]['specialty']!;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ─── Pick date ────────────────────────────────────────────────────────────
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

  // ─── Pick time ────────────────────────────────────────────────────────────
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
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar('Please select a date and time.', const Color(0xFFEF9F27)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Combine date + time into one DateTime
      final dt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Find doctorId — if using Firestore doctors collection, fetch it there
      // For now we use doctorName as a simple lookup key
      await FirebaseFirestore.instance.collection('appointments').add({
        'patientId':   uid,
        'doctorName':  _doctorName,
        'doctorId':    _doctorName.replaceAll(' ', '_').toLowerCase(), // placeholder
        'specialty':   _specialty,
        'type':        _type,
        'notes':       _notesController.text.trim(),
        'status':      'pending',          // always starts as pending
        'dateTime':    Timestamp.fromDate(dt),
        'createdAt':   FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context); // go back to AppointmentsPage
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Appointment booked! ✓', const Color(0xFF00D4AA)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Failed to book: $e', const Color(0xFFFF6B8A)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  SnackBar _snackBar(String msg, Color color) => SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 15),
          ),
        ),
        title: const Text(
          'Book Appointment',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          // ── Doctor selector ──────────────────────────────────────────────
          _sectionLabel('Select Doctor'),
          _card(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _doctorName,
                isExpanded: true,
                dropdownColor: const Color(0xFF141828),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF00D4AA)),
                items: _doctors.map((d) {
                  return DropdownMenuItem(
                    value: d['name'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(d['name']!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500)),
                        Text(d['specialty']!,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  final doc = _doctors.firstWhere((d) => d['name'] == val);
                  setState(() {
                    _doctorName = val;
                    _specialty = doc['specialty']!;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ── Date & Time ──────────────────────────────────────────────────
          _sectionLabel('Date & Time'),
          Row(
            children: [
              Expanded(
                child: _tappableCard(
                  icon: Icons.calendar_today_rounded,
                  label: _selectedDate == null
                      ? 'Pick date'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tappableCard(
                  icon: Icons.access_time_rounded,
                  label: _selectedTime == null
                      ? 'Pick time'
                      : _selectedTime!.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Visit type ───────────────────────────────────────────────────
          _sectionLabel('Visit Type'),
          Row(
            children: ['In-person', 'Online'].map((t) {
              final isSelected = _type == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: t == 'In-person' ? 8 : 0),
                    height: 46,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00D4AA).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00D4AA)
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF00D4AA)
                              : Colors.white.withValues(alpha: 0.45),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // ── Notes ────────────────────────────────────────────────────────
          _sectionLabel('Notes (optional)'),
          _card(
            child: TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'e.g. Bring previous reports...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30), fontSize: 13.5),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Submit button ─────────────────────────────────────────────────
          GestureDetector(
            onTap: _isLoading ? null : _submit,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF00D4AA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5)
                    : const Text(
                        'Confirm Booking',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4)),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: child,
      );

  Widget _tappableCard(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF00D4AA), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 13)),
              ),
            ],
          ),
        ),
      );
}
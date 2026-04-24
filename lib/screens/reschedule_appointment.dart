import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RescheduleAppointmentPage extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> data;

  const RescheduleAppointmentPage({
    super.key,
    required this.appointmentId,
    required this.data,
  });

  @override
  State<RescheduleAppointmentPage> createState() =>
      _RescheduleAppointmentPageState();
}

class _RescheduleAppointmentPageState
    extends State<RescheduleAppointmentPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing dateTime
    final ts = widget.data['dateTime'] as Timestamp?;
    if (ts != null) {
      final dt = ts.toDate();
      _selectedDate = DateTime(dt.year, dt.month, dt.day);
      _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
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
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF00D4AA)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(_snackBar(
        'Please select a new date and time.',
        const Color(0xFFEF9F27),
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
        'dateTime': Timestamp.fromDate(dt),
        'status': 'pending', // reset to pending after reschedule
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(_snackBar(
          'Appointment rescheduled! ✓',
          const Color(0xFF00D4AA),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_snackBar(
          'Failed to reschedule: $e',
          const Color(0xFFFF6B8A),
        ));
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

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final p = h >= 12 ? 'PM' : 'AM';
    final hr = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hr:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    final doctorName = widget.data['doctorName'] as String? ?? 'Doctor';
    final specialty = widget.data['specialty'] as String? ?? '';
    final initial = doctorName.replaceFirst('Dr. ', '').trim();
    final avatarLetter = initial.isNotEmpty ? initial[0].toUpperCase() : 'D';

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
          'Reschedule',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Doctor info card ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        const Color(0xFF378ADD).withValues(alpha: 0.18),
                    child: Text(
                      avatarLetter,
                      style: const TextStyle(
                          color: Color(0xFF378ADD),
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctorName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      if (specialty.isNotEmpty)
                        Text(specialty,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12.5)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Pick new date ─────────────────────────────────────────────
            _label('New Date'),
            _tappableCard(
              icon: Icons.calendar_today_rounded,
              label: _selectedDate != null
                  ? _formatDate(_selectedDate!)
                  : 'Select date',
              onTap: _pickDate,
            ),

            const SizedBox(height: 16),

            // ── Pick new time ─────────────────────────────────────────────
            _label('New Time'),
            _tappableCard(
              icon: Icons.access_time_rounded,
              label: _selectedTime != null
                  ? _formatTime(_selectedTime!)
                  : 'Select time',
              onTap: _pickTime,
            ),

            const SizedBox(height: 12),

            // ── Info note ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF9F27).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFEF9F27).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFEF9F27), size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rescheduling will reset status to Pending until confirmed.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12.5,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Confirm button ────────────────────────────────────────────
            GestureDetector(
              onTap: _isLoading ? null : _submit,
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4AA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5)
                      : const Text(
                          'Confirm Reschedule',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4)),
      );

  Widget _tappableCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF00D4AA), size: 18),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.25), size: 20),
            ],
          ),
        ),
      );
}
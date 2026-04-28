import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:smartmedi_app/screens/find_doctor.dart';
import '../../widgets/common/blob_painter.dart';

// ─── Blobs ────────────────────────────────────────────────────────────────────
class _AIBlobs {
  static const blobs = [
    BlobConfig(
      color: Color(0x147F77DD),
      x: 0.85,
      y: 0.06,
      radius: 0.42,
      dx: 0.05,
      dy: 0.04,
      speedX: 0.8,
      speedY: 0.7,
    ),
    BlobConfig(
      color: Color(0x1100D4AA),
      x: 0.08,
      y: 0.45,
      radius: 0.36,
      dx: 0.05,
      dy: 0.05,
      speedX: 0.9,
      speedY: 1.0,
    ),
    BlobConfig(
      color: Color(0x0D5B6EF5),
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

// ─── Data models ─────────────────────────────────────────────────────────────
class _SymptomResult {
  final List<String> possibleConditions;
  final String urgencyLevel; // 'low' | 'medium' | 'high' | 'emergency'
  final String suggestedSpecialist;
  final List<String> homeCareAdvice;
  final List<String> emergencyIndicators;
  final String summary;

  const _SymptomResult({
    required this.possibleConditions,
    required this.urgencyLevel,
    required this.suggestedSpecialist,
    required this.homeCareAdvice,
    required this.emergencyIndicators,
    required this.summary,
  });
}

// ─── All available symptoms ───────────────────────────────────────────────────
const _allSymptoms = [
  'Headache',
  'Fever',
  'Cough',
  'Sore throat',
  'Runny nose',
  'Chest pain',
  'Shortness of breath',
  'Fatigue',
  'Nausea',
  'Vomiting',
  'Diarrhea',
  'Abdominal pain',
  'Back pain',
  'Joint pain',
  'Muscle aches',
  'Dizziness',
  'Rash',
  'Itching',
  'Swelling',
  'Loss of appetite',
  'Difficulty sleeping',
  'Anxiety',
  'Heart palpitations',
  'Blurred vision',
  'Ear pain',
  'Toothache',
  'Neck pain',
  'Chills',
  'Night sweats',
];

const _durations = [
  '< 1 day',
  '1–3 days',
  '3–7 days',
  '1–2 weeks',
  '> 2 weeks',
];
const _severities = ['Mild', 'Moderate', 'Severe'];

// ─── Urgency config ───────────────────────────────────────────────────────────
const _urgencyConfig = {
  'low': {
    'color': Color(0xFF00D4AA),
    'bg': Color(0x1A00D4AA),
    'label': 'Low — Monitor at home',
    'icon': Icons.check_circle_outline_rounded,
  },
  'medium': {
    'color': Color(0xFFEF9F27),
    'bg': Color(0x1AEF9F27),
    'label': 'Moderate — See a doctor soon',
    'icon': Icons.schedule_rounded,
  },
  'high': {
    'color': Color(0xFFFF6B8A),
    'bg': Color(0x1AFF6B8A),
    'label': 'High — Visit doctor today',
    'icon': Icons.warning_amber_rounded,
  },
  'emergency': {
    'color': Color(0xFFE24B4A),
    'bg': Color(0x1AE24B4A),
    'label': '⚠️ Emergency — Go to ER now!',
    'icon': Icons.emergency_rounded,
  },
};

// ─── Symptom Checker Page ─────────────────────────────────────────────────────
class SymptomCheckerPage extends StatefulWidget {
  const SymptomCheckerPage({super.key});

  @override
  State<SymptomCheckerPage> createState() => _SymptomCheckerPageState();
}

class _SymptomCheckerPageState extends State<SymptomCheckerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobCtrl;

  // Step: 0=select, 1=details, 2=result
  int _step = 0;

  // Form state
  final Set<String> _selectedSymptoms = {};
  String _duration = '1–3 days';
  String _severity = 'Mild';
  String _notes = '';
  final _notesCtrl = TextEditingController();

  // Result state
  bool _analyzing = false;
  _SymptomResult? _result;
  String? _error;

  // Symptom search
  String _symptomSearch = '';
  final _searchCtrl = TextEditingController();

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
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Analyze symptoms via Claude API ─────────────────────────────────────
  Future<void> _analyze() async {
    if (_selectedSymptoms.isEmpty) {
      _showSnackbar('Please select at least one symptom.');
      return;
    }
    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      const apiKey = 'API KEY HERE'; 
      const model = 'llama-3.3-70b-versatile';
      final url = 'https://api.groq.com/openai/v1/chat/completions';

      final prompt =
          '''
You are a medical triage assistant. A patient reports the following:
- Symptoms: ${_selectedSymptoms.join(', ')}
- Duration: $_duration
- Severity: $_severity
- Additional notes: ${_notes.isEmpty ? 'None' : _notes}

Respond ONLY with a valid JSON object in this exact format:
{
  "possibleConditions": ["condition1", "condition2", "condition3"],
  "urgencyLevel": "low|medium|high|emergency",
  "suggestedSpecialist": "e.g. General Practitioner",
  "homeCareAdvice": ["advice1", "advice2", "advice3"],
  "emergencyIndicators": ["indicator1", "indicator2"],
  "summary": "Brief 1-2 sentence summary of the assessment"
}

Rules:
- urgencyLevel must be exactly one of: low, medium, high, emergency
- If symptoms suggest immediate danger, set urgencyLevel to "emergency"
- Keep text concise and professional.
''';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          // ✅ DeepSeek uses OpenAI-style 'messages', not 'contents'
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'response_format': {'type': 'json_object'}, // ✅ forces JSON output
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // ✅ DeepSeek response path, not Google's 'candidates'
        final String text = body['choices'][0]['message']['content'];
        final data = jsonDecode(text) as Map<String, dynamic>;

        final result = _SymptomResult(
          possibleConditions: List<String>.from(
            data['possibleConditions'] ?? [],
          ),
          urgencyLevel: (data['urgencyLevel'] ?? 'medium')
              .toString()
              .toLowerCase(),
          suggestedSpecialist:
              (data['suggestedSpecialist'] ?? 'General Practitioner')
                  .toString(),
          homeCareAdvice: List<String>.from(data['homeCareAdvice'] ?? []),
          emergencyIndicators: List<String>.from(
            data['emergencyIndicators'] ?? [],
          ),
          summary: (data['summary'] ?? '').toString(),
        );

        await _saveReport(result);

        if (mounted) {
          setState(() {
            _result = result;
            _step = 2;
            _analyzing = false;
          });
        }
      } else {
        throw Exception('API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Analysis error: $e');
      if (mounted) {
        setState(() {
          _error =
              'Analysis failed. Please check your internet or try again later.';
          _analyzing = false;
        });
      }
    }
  }

  // ─── Save symptom report to Firestore ───────────────────────────────────
  Future<void> _saveReport(_SymptomResult result) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('symptom_checks').add({
        'patientId': uid,
        'symptoms': _selectedSymptoms.toList(),
        'duration': _duration,
        'severity': _severity,
        'notes': _notes,
        'possibleConditions': result.possibleConditions,
        'urgencyLevel': result.urgencyLevel,
        'suggestedSpecialist': result.suggestedSpecialist,
        'homeCareAdvice': result.homeCareAdvice,
        'emergencyIndicators': result.emergencyIndicators,
        'summary': result.summary,
        'aiSuggestion': result.suggestedSpecialist,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Save report error: $e');
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFEF9F27),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _reset() => setState(() {
    _step = 0;
    _result = null;
    _error = null;
    _selectedSymptoms.clear();
    _duration = '1–3 days';
    _severity = 'Mild';
    _notes = '';
    _notesCtrl.clear();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: AnimatedBuilder(
        animation: _blobCtrl,
        builder: (context, _) => Stack(
          children: [
            CustomPaint(
              painter: BlobPainter(
                _blobCtrl.value * 2 * math.pi,
                blobs: _AIBlobs.blobs,
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
              child: _step == 0
                  ? _buildSelectStep()
                  : _step == 1
                  ? _buildDetailsStep()
                  : _buildResultStep(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 0: Select symptoms
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSelectStep() {
    final filtered = _allSymptoms
        .where((s) => s.toLowerCase().contains(_symptomSearch.toLowerCase()))
        .toList();

    return Column(
      children: [
        _buildTopBar('AI Symptom Checker', showBack: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F77DD).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.psychology_outlined,
                      color: Color(0xFF7F77DD),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select your symptoms',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Choose all that apply',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.40),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedSymptoms.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F77DD).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_selectedSymptoms.length} selected',
                        style: const TextStyle(
                          color: Color(0xFF7F77DD),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Search
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (v) => setState(() => _symptomSearch = v),
                  decoration: InputDecoration(
                    hintText: 'Search symptoms…',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.30),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF7F77DD),
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Symptom grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filtered.map((s) {
                final selected = _selectedSymptoms.contains(s);
                return GestureDetector(
                  onTap: () => setState(
                    () => selected
                        ? _selectedSymptoms.remove(s)
                        : _selectedSymptoms.add(s),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF7F77DD)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF7F77DD)
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          s,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Next button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedSymptoms.isEmpty
                  ? null
                  : () => setState(() => _step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F77DD),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _selectedSymptoms.isEmpty
                        ? 'Select symptoms above'
                        : 'Next — Add details',
                    style: TextStyle(
                      color: _selectedSymptoms.isEmpty
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_selectedSymptoms.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1: Duration, severity, notes
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDetailsStep() {
    return Column(
      children: [
        _buildTopBar(
          'Symptom Details',
          showBack: true,
          onBack: () => setState(() => _step = 0),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              // Selected symptoms summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F77DD).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF7F77DD).withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected symptoms (${_selectedSymptoms.length})',
                      style: const TextStyle(
                        color: Color(0xFF7F77DD),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedSymptoms
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF7F77DD,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  color: Color(0xFF7F77DD),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Duration
              _sectionLabel('How long have you had these symptoms?'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durations.map((d) {
                  final active = _duration == d;
                  return GestureDetector(
                    onTap: () => setState(() => _duration = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF378ADD)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF378ADD)
                              : Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        d,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Severity
              _sectionLabel('How severe are your symptoms?'),
              const SizedBox(height: 10),
              Row(
                children: _severities.asMap().entries.map((e) {
                  final active = _severity == e.value;
                  final colors = [
                    const Color(0xFF00D4AA),
                    const Color(0xFFEF9F27),
                    const Color(0xFFFF6B8A),
                  ];
                  final col = colors[e.key];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _severity = e.value),
                      child: Padding(
                        padding: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 56,
                          decoration: BoxDecoration(
                            color: active
                                ? col.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active
                                  ? col
                                  : Colors.white.withValues(alpha: 0.10),
                              width: active ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                e.key == 0
                                    ? Icons.sentiment_satisfied_alt_rounded
                                    : e.key == 1
                                    ? Icons.sentiment_neutral_rounded
                                    : Icons.sentiment_very_dissatisfied_rounded,
                                color: active
                                    ? col
                                    : Colors.white.withValues(alpha: 0.35),
                                size: 20,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                e.value,
                                style: TextStyle(
                                  color: active
                                      ? col
                                      : Colors.white.withValues(alpha: 0.45),
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Notes
              _sectionLabel('Additional notes (optional)'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (v) => _notes = v,
                  decoration: InputDecoration(
                    hintText:
                        'Any other details, medications taken, allergies…',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Analyze button
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B8A).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF6B8A).withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B8A),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _analyzing
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7F77DD), Color(0xFF5B53CC)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Analyzing symptoms…',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.80),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7F77DD), Color(0xFF5B53CC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF7F77DD,
                              ).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _analyze,
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Analyze with AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '⚠️ This is for informational purposes only.\nAlways consult a real doctor for medical advice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2: AI Result
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResultStep() {
    final r = _result!;
    final urgency = _urgencyConfig[r.urgencyLevel] ?? _urgencyConfig['medium']!;
    final urgencyColor = urgency['color'] as Color;
    final urgencyBg = urgency['bg'] as Color;
    final urgencyLabel = urgency['label'] as String;
    final urgencyIcon = urgency['icon'] as IconData;
    final isEmergency = r.urgencyLevel == 'emergency';

    return Column(
      children: [
        _buildTopBar('AI Assessment', showBack: false),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              // ── Urgency banner ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isEmergency ? const Color(0xFFE24B4A) : urgencyBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: urgencyColor.withValues(
                      alpha: isEmergency ? 0.80 : 0.35,
                    ),
                    width: isEmergency ? 2 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isEmergency
                            ? Colors.white.withValues(alpha: 0.15)
                            : urgencyColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        urgencyIcon,
                        color: isEmergency ? Colors.white : urgencyColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Urgency Level',
                            style: TextStyle(
                              color: isEmergency
                                  ? Colors.white.withValues(alpha: 0.70)
                                  : urgencyColor.withValues(alpha: 0.70),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            urgencyLabel,
                            style: TextStyle(
                              color: isEmergency ? Colors.white : urgencyColor,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Summary ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.summarize_outlined,
                          color: Color(0xFF7F77DD),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Summary',
                          style: TextStyle(
                            color: Color(0xFF7F77DD),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      r.summary,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13.5,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Possible conditions ───────────────────────────────────────
              _resultCard(
                icon: Icons.medical_information_outlined,
                color: const Color(0xFF378ADD),
                title: 'Possible Conditions',
                child: Column(
                  children: r.possibleConditions
                      .asMap()
                      .entries
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF378ADD,
                                  ).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: const TextStyle(
                                      color: Color(0xFF378ADD),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.80),
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),

              // ── Suggested specialist ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00D4AA).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_search_rounded,
                        color: Color(0xFF00D4AA),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'See a Specialist',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.suggestedSpecialist,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF00D4AA),
                      size: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Home care advice ──────────────────────────────────────────
              _resultCard(
                icon: Icons.home_outlined,
                color: const Color(0xFF00D4AA),
                title: 'Home Care Advice',
                child: Column(
                  children: r.homeCareAdvice
                      .map(
                        (advice) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                color: Color(0xFF00D4AA),
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  advice,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13.5,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),

              // ── Emergency indicators ──────────────────────────────────────
              _resultCard(
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFFF6B8A),
                title: 'Seek Emergency Care If…',
                child: Column(
                  children: r.emergencyIndicators
                      .map(
                        (ind) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.emergency_rounded,
                                color: Color(0xFFFF6B8A),
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ind,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13.5,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),

              // ── Actions ───────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _reset,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Check again',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FindDoctorPage(),
                          ),
                        );
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4AA), Color(0xFF00A896)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF00D4AA,
                              ).withValues(alpha: 0.30),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Book Doctor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '⚠️ This AI assessment is not a medical diagnosis.\nAlways consult a qualified healthcare professional.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Shared widgets ───────────────────────────────────────────────────────
  Widget _buildTopBar(
    String title, {
    bool showBack = true,
    VoidCallback? onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              onTap: onBack ?? () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            )
          else
            const SizedBox(width: 38),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
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

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.65),
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _resultCard({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

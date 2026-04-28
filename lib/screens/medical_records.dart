import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../../widgets/common/blob_painter.dart';

// ─── Blob preset ──────────────────────────────────────────────────────────────
class _RecordsBlobs {
  static const blobs = [
    BlobConfig(
      color: Color(0x14D85A30),
      x: 0.85,
      y: 0.06,
      radius: 0.42,
      dx: 0.05,
      dy: 0.04,
      speedX: 0.7,
      speedY: 0.9,
    ),
    BlobConfig(
      color: Color(0x0F378ADD),
      x: 0.10,
      y: 0.45,
      radius: 0.36,
      dx: 0.06,
      dy: 0.05,
      speedX: 1.0,
      speedY: 0.8,
    ),
    BlobConfig(
      color: Color(0x0A00D4AA),
      x: 0.55,
      y: 0.82,
      radius: 0.30,
      dx: 0.04,
      dy: 0.04,
      speedX: 1.2,
      speedY: 0.7,
    ),
  ];
}

// ─── Tab enum ─────────────────────────────────────────────────────────────────
enum _RecordsTab { documents, history, conditions, notes }

// ─── Models ───────────────────────────────────────────────────────────────────
class _Document {
  final String id;
  final String name;
  final String fileUrl;
  final String fileType; // pdf, image, etc.
  final String category; // Lab Results, Prescription, Imaging, Other
  final DateTime uploadedAt;
  final int sizeBytes;

  const _Document({
    required this.id,
    required this.name,
    required this.fileUrl,
    required this.fileType,
    required this.category,
    required this.uploadedAt,
    required this.sizeBytes,
  });

  factory _Document.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Document(
      id: doc.id,
      name: (d['name'] ?? 'Untitled').toString(),
      fileUrl: (d['fileUrl'] ?? '').toString(),
      fileType: (d['fileType'] ?? 'file').toString(),
      category: (d['category'] ?? 'Other').toString(),
      uploadedAt: (d['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sizeBytes: (d['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class _HealthCondition {
  final String id;
  final String name;
  final String status; // active, managed, resolved
  final String notes;
  final DateTime diagnosedAt;

  const _HealthCondition({
    required this.id,
    required this.name,
    required this.status,
    required this.notes,
    required this.diagnosedAt,
  });

  factory _HealthCondition.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _HealthCondition(
      id: doc.id,
      name: (d['name'] ?? 'Unknown').toString(),
      status: (d['status'] ?? 'active').toString(),
      notes: (d['notes'] ?? '').toString(),
      diagnosedAt: (d['diagnosedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class _AppointmentNote {
  final String id;
  final String doctorName;
  final String specialty;
  final String diagnosis;
  final String prescription;
  final String notes;
  final DateTime date;

  const _AppointmentNote({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.diagnosis,
    required this.prescription,
    required this.notes,
    required this.date,
  });

  factory _AppointmentNote.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _AppointmentNote(
      id: doc.id,
      doctorName: (d['doctorName'] ?? 'Doctor').toString(),
      specialty: (d['specialty'] ?? '').toString(),
      diagnosis: (d['diagnosis'] ?? '').toString(),
      prescription: (d['prescription'] ?? '').toString(),
      notes: (d['notes'] ?? '').toString(),
      date: (d['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─── Medical Records Page ─────────────────────────────────────────────────────
class MedicalRecordsPage extends StatefulWidget {
  const MedicalRecordsPage({super.key});

  @override
  State<MedicalRecordsPage> createState() => _MedicalRecordsPageState();
}

class _MedicalRecordsPageState extends State<MedicalRecordsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobCtrl;
  _RecordsTab _activeTab = _RecordsTab.documents;
  bool _uploading = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    super.dispose();
  }

  // ── Upload document ────────────────────────────────────────────────────────
  Future<void> _uploadDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final fileName = result.files.single.name;
    final fileSize = result.files.single.size;
    final ext = fileName.split('.').last.toLowerCase();

    // Ask for category
    final category = await _showCategoryPicker();
    if (category == null) return;

    setState(() => _uploading = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('medical_documents')
          .child(_uid)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('medical_records').add({
        'patientId': _uid,
        'name': fileName,
        'fileUrl': downloadUrl,
        'fileType': ext,
        'category': category,
        'sizeBytes': fileSize,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) _showSnack('Document uploaded successfully!', success: true);
    } catch (e) {
      if (mounted) _showSnack('Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String?> _showCategoryPicker() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141828),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 20),
            const Text(
              'Document category',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...[
              'Lab Results',
              'Prescription',
              'Imaging',
              'Vaccination',
              'Other',
            ].map((cat) {
              final icons = {
                'Lab Results': Icons.science_outlined,
                'Prescription': Icons.medication_outlined,
                'Imaging': Icons.image_outlined,
                'Vaccination': Icons.vaccines_outlined,
                'Other': Icons.folder_outlined,
              };
              final colors = {
                'Lab Results': const Color(0xFF00D4AA),
                'Prescription': const Color(0xFF378ADD),
                'Imaging': const Color(0xFF7F77DD),
                'Vaccination': const Color(0xFFD85A30),
                'Other': Colors.white,
              };
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, cat),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: (colors[cat] ?? Colors.white).withValues(
                      alpha: 0.08,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (colors[cat] ?? Colors.white).withValues(
                        alpha: 0.15,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icons[cat], color: colors[cat], size: 20),
                      const SizedBox(width: 12),
                      Text(
                        cat,
                        style: TextStyle(
                          color: colors[cat],
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Add health condition ───────────────────────────────────────────────────
  void _showAddCondition() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddConditionSheet(
        uid: _uid,
        onSaved: () => _showSnack('Condition added!', success: true),
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontSize: 13.5),
        ),
        backgroundColor: success
            ? const Color(0xFF00D4AA)
            : const Color(0xFFFF6B8A),
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
      body: AnimatedBuilder(
        animation: _blobCtrl,
        builder: (context, _) => Stack(
          children: [
            CustomPaint(
              painter: BlobPainter(
                _blobCtrl.value * 2 * math.pi,
                blobs: _RecordsBlobs.blobs,
              ),
              size: MediaQuery.of(context).size,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0E1A).withValues(alpha: 0.55),
                    const Color(0xFF0A0E1A).withValues(alpha: 0.97),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildTabBar(),
                  Expanded(child: _buildTabContent()),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
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
            'Medical Records',
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

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      (_RecordsTab.documents, Icons.folder_outlined, 'Documents'),
      (_RecordsTab.history, Icons.history_rounded, 'History'),
      (_RecordsTab.conditions, Icons.favorite_outline_rounded, 'Conditions'),
      (_RecordsTab.notes, Icons.notes_rounded, 'Notes'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: tabs.map((tab) {
            final active = _activeTab == tab.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = tab.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFD85A30)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.$2,
                        size: 18,
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.$3,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Tab content ────────────────────────────────────────────────────────────
  Widget _buildTabContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(_activeTab),
        child: switch (_activeTab) {
          _RecordsTab.documents => _buildDocumentsTab(),
          _RecordsTab.history => _buildHistoryTab(),
          _RecordsTab.conditions => _buildConditionsTab(),
          _RecordsTab.notes => _buildNotesTab(),
        },
      ),
    );
  }

  // ── Documents tab ──────────────────────────────────────────────────────────
  Widget _buildDocumentsTab() {
    if (_uid.isEmpty) return _buildEmpty('Login to view documents');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medical_records')
          .where('patientId', isEqualTo: _uid)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError) {
          debugPrint('Docs error: ${snapshot.error}');
          return _buildEmpty('Could not load documents');
        }
        final docs =
            snapshot.data?.docs.map(_Document.fromFirestore).toList() ?? [];
        if (docs.isEmpty) {
          return _buildEmpty(
            'No documents uploaded yet.\nTap + to upload your first document.',
          );
        }

        // Group by category
        final grouped = <String, List<_Document>>{};
        for (final doc in docs) {
          grouped.putIfAbsent(doc.category, () => []).add(doc);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: grouped.entries
              .map(
                (entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 4),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    ...entry.value.map(
                      (doc) => _DocumentTile(
                        doc: doc,
                        onDelete: () => _deleteDocument(doc),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _deleteDocument(_Document doc) async {
    final confirm = await _showDeleteConfirm('Delete "${doc.name}"?');
    if (!confirm) return;
    try {
      await FirebaseFirestore.instance
          .collection('medical_records')
          .doc(doc.id)
          .delete();
      if (doc.fileUrl.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(doc.fileUrl).delete();
      }
      if (mounted) _showSnack('Document deleted', success: true);
    } catch (_) {
      if (mounted) _showSnack('Failed to delete document');
    }
  }

  // ── Medical history tab ────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_uid.isEmpty) return _buildEmpty('Login to view history');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medical_records')
          .where('patientId', isEqualTo: _uid)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError) return _buildEmpty('Could not load history');

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmpty('No medical history yet.');

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            // Summary stats
            _buildHistorySummary(docs.length),
            const SizedBox(height: 20),
            Text(
              'Timeline',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            ...docs.asMap().entries.map((e) {
              final data = e.value.data() as Map<String, dynamic>;
              final ts = data['uploadedAt'] as Timestamp?;
              final date = ts?.toDate() ?? DateTime.now();
              final isLast = e.key == docs.length - 1;
              return _TimelineTile(
                title: (data['name'] ?? 'Document').toString(),
                subtitle: (data['category'] ?? 'Other').toString(),
                date: date,
                isLast: isLast,
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildHistorySummary(int count) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFD85A30).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD85A30).withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFD85A30).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: Color(0xFFD85A30),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count medical documents',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap a document to view details',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Conditions tab ─────────────────────────────────────────────────────────
  Widget _buildConditionsTab() {
    if (_uid.isEmpty) return _buildEmpty('Login to view conditions');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_conditions')
          .where('patientId', isEqualTo: _uid)
          .orderBy('diagnosedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError) {
          debugPrint('Conditions error: ${snapshot.error}');
          return _buildEmpty('Could not load conditions');
        }

        final conditions =
            snapshot.data?.docs.map(_HealthCondition.fromFirestore).toList() ??
            [];

        if (conditions.isEmpty) {
          return _buildEmpty(
            'No health conditions recorded.\nTap + to add one.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: conditions
              .map(
                (c) => _ConditionCard(
                  condition: c,
                  onDelete: () => _deleteCondition(c),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _deleteCondition(_HealthCondition c) async {
    final confirm = await _showDeleteConfirm('Remove "${c.name}"?');
    if (!confirm) return;
    try {
      await FirebaseFirestore.instance
          .collection('health_conditions')
          .doc(c.id)
          .delete();
      if (mounted) _showSnack('Condition removed', success: true);
    } catch (_) {
      if (mounted) _showSnack('Failed to remove condition');
    }
  }

  // ── Appointment notes tab ──────────────────────────────────────────────────
  Widget _buildNotesTab() {
    if (_uid.isEmpty) return _buildEmpty('Login to view notes');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medical_records')
          .where('patientId', isEqualTo: _uid)
          .where('diagnosis', isNull: false)
          .orderBy('recordedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError) {
          debugPrint('Notes error: ${snapshot.error}');
          return _buildEmpty('Could not load appointment notes');
        }

        final notes =
            snapshot.data?.docs
                .map(_AppointmentNote.fromFirestore)
                .where((n) => n.diagnosis.isNotEmpty || n.notes.isNotEmpty)
                .toList() ??
            [];

        if (notes.isEmpty) {
          return _buildEmpty(
            'No appointment notes yet.\nNotes are added by your doctor after a visit.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: notes.map((n) => _NoteCard(note: n)).toList(),
        );
      },
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget? _buildFab() {
    // Only show FAB for tabs that support adding
    if (_activeTab == _RecordsTab.notes || _activeTab == _RecordsTab.history) {
      return null;
    }

    return FloatingActionButton.extended(
      onPressed: _uploading
          ? null
          : _activeTab == _RecordsTab.documents
          ? _uploadDocument
          : _showAddCondition,
      backgroundColor: const Color(0xFFD85A30),
      foregroundColor: Colors.white,
      elevation: 6,
      icon: _uploading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.add_rounded, size: 20),
      label: Text(
        _uploading
            ? 'Uploading…'
            : _activeTab == _RecordsTab.documents
            ? 'Upload'
            : 'Add condition',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Future<bool> _showDeleteConfirm(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: const Color(0xFF141828),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B8A).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF6B8A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This action cannot be undone.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.40),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, true),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B8A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Delete',
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
        ) ??
        false;
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                color: Colors.white.withValues(alpha: 0.20),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: List.generate(
        4,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ─── Document Tile ────────────────────────────────────────────────────────────
class _DocumentTile extends StatelessWidget {
  final _Document doc;
  final VoidCallback onDelete;

  const _DocumentTile({required this.doc, required this.onDelete});

  Color get _catColor {
    switch (doc.category) {
      case 'Lab Results':
        return const Color(0xFF00D4AA);
      case 'Prescription':
        return const Color(0xFF378ADD);
      case 'Imaging':
        return const Color(0xFF7F77DD);
      case 'Vaccination':
        return const Color(0xFFD85A30);
      default:
        return Colors.white;
    }
  }

  IconData get _fileIcon {
    switch (doc.fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String get _sizeLabel {
    if (doc.sizeBytes < 1024) return '${doc.sizeBytes} B';
    if (doc.sizeBytes < 1024 * 1024) {
      return '${(doc.sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(doc.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_fileIcon, color: _catColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _catColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        doc.category,
                        style: TextStyle(
                          color: _catColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_sizeLabel  ·  ${_formatDate(doc.uploadedAt)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B8A).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF6B8A),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline Tile ────────────────────────────────────────────────────────────
class _TimelineTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime date;
  final bool isLast;

  const _TimelineTile({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD85A30),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
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
          ),
        ],
      ),
    );
  }
}

// ─── Condition Card ────────────────────────────────────────────────────────────
class _ConditionCard extends StatelessWidget {
  final _HealthCondition condition;
  final VoidCallback onDelete;

  const _ConditionCard({required this.condition, required this.onDelete});

  Color get _statusColor {
    switch (condition.status) {
      case 'active':
        return const Color(0xFFFF6B8A);
      case 'managed':
        return const Color(0xFFEF9F27);
      case 'resolved':
        return const Color(0xFF00D4AA);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _statusColor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: _statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condition.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Since ${condition.diagnosedAt.day}/${condition.diagnosedAt.month}/${condition.diagnosedAt.year}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _statusColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  condition.status[0].toUpperCase() +
                      condition.status.substring(1),
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B8A).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFFF6B8A),
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
          if (condition.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 10),
            Text(
              condition.notes,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Note Card ────────────────────────────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  final _AppointmentNote note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF378ADD).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(
                  0xFF378ADD,
                ).withValues(alpha: 0.18),
                child: Text(
                  note.doctorName.isNotEmpty
                      ? note.doctorName[0].toUpperCase()
                      : 'D',
                  style: const TextStyle(
                    color: Color(0xFF378ADD),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.doctorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (note.specialty.isNotEmpty)
                      Text(
                        note.specialty,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${note.date.day}/${note.date.month}/${note.date.year}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),

          if (note.diagnosis.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 12),
            _noteRow(
              Icons.medical_information_outlined,
              'Diagnosis',
              note.diagnosis,
              const Color(0xFF00D4AA),
            ),
          ],
          if (note.prescription.isNotEmpty) ...[
            const SizedBox(height: 10),
            _noteRow(
              Icons.medication_outlined,
              'Prescription',
              note.prescription,
              const Color(0xFF7F77DD),
            ),
          ],
          if (note.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _noteRow(
              Icons.notes_rounded,
              'Doctor notes',
              note.notes,
              const Color(0xFF378ADD),
            ),
          ],
        ],
      ),
    );
  }

  Widget _noteRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Add Condition Sheet ──────────────────────────────────────────────────────
class _AddConditionSheet extends StatefulWidget {
  final String uid;
  final VoidCallback onSaved;

  const _AddConditionSheet({required this.uid, required this.onSaved});

  @override
  State<_AddConditionSheet> createState() => _AddConditionSheetState();
}

class _AddConditionSheetState extends State<_AddConditionSheet> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _status = 'active';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('health_conditions').add({
        'patientId': widget.uid,
        'name': _nameCtrl.text.trim(),
        'status': _status,
        'notes': _notesCtrl.text.trim(),
        'diagnosedAt': FieldValue.serverTimestamp(),
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141828),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 20),
          const Text(
            'Add health condition',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          _field(_nameCtrl, 'Condition name', Icons.favorite_outline_rounded),
          const SizedBox(height: 14),

          // Status selector
          Text(
            'Status',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: ['active', 'managed', 'resolved'].map((s) {
              final colors = {
                'active': const Color(0xFFFF6B8A),
                'managed': const Color(0xFFEF9F27),
                'resolved': const Color(0xFF00D4AA),
              };
              final c = colors[s]!;
              final active = _status == s;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _status = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(right: s != 'resolved' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? c : c.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active ? c : c.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        s[0].toUpperCase() + s.substring(1),
                        style: TextStyle(
                          color: active ? Colors.white : c,
                          fontSize: 13,
                          fontWeight: active
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
          const SizedBox(height: 14),

          _field(
            _notesCtrl,
            'Notes (optional)',
            Icons.notes_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: _saving ? null : _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFD85A30),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD85A30).withValues(alpha: 0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Text(
                        'Save condition',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.40),
          fontSize: 13.5,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFD85A30), size: 19),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.09),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFD85A30), width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
